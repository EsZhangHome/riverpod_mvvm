// 这个文件只在开发机或 CI 中执行，不会被 lib/ 引用，也不会进入正式安装包。
//
// 使用方式：
//   dart run tool/privacy/privacy_audit.dart --mode development
//   dart run tool/privacy/privacy_audit.dart --mode release --apk build/app.apk
//
// 审计规则集中保存在 compliance/privacy_audit.json。这样新增权限、原生插件
// 或域名时，代码评审既能看到实现改动，也能看到对应的合规登记是否同步更新。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 审计严格程度。
///
/// [development] 用于日常开发和 Pull Request：明确违规项会阻断，但模板尚未填写
/// 的隐私政策等内容只提示人工确认。
/// [release] 用于提审前：隐私政策、同意入口、正式域名等缺失都会升级为阻断项。
enum AuditMode { development, release }

/// 单条问题的严重程度。
enum AuditSeverity {
  /// 已登记的信息，或者不会阻断开发的环境提示。
  info,

  /// 工具无法仅靠静态代码下结论，需要开发、测试或法务人工确认。
  review,

  /// 明确不允许，或正式提审所需信息缺失。
  blocker;

  int get rank => index;

  String get label => switch (this) {
    AuditSeverity.info => '信息',
    AuditSeverity.review => '待确认',
    AuditSeverity.blocker => '阻断',
  };

  static AuditSeverity parse(String value) {
    return AuditSeverity.values.firstWhere(
      (severity) => severity.name == value,
      orElse: () => throw FormatException('未知严重等级：$value'),
    );
  }
}

/// 命令行参数。测试也可以直接构造它，从而在临时项目上运行审计。
final class PrivacyAuditOptions {
  const PrivacyAuditOptions({
    required this.rootDirectory,
    required this.mode,
    required this.configPath,
    required this.markdownReportPath,
    required this.jsonReportPath,
    required this.failOn,
    this.apkPath,
    this.environmentFilePath,
  });

  /// 被扫描项目的根目录。
  final Directory rootDirectory;

  /// 日常开发或提审前严格模式。
  final AuditMode mode;

  /// 规则、权限、域名和 SDK 白名单文件。
  final String configPath;

  /// 给人阅读的报告路径，相对于 [rootDirectory]。
  final String markdownReportPath;

  /// 给 CI 或其他工具读取的结构化报告路径。
  final String jsonReportPath;

  /// 达到该等级时进程返回非零；null 表示只生成报告、不阻断。
  final AuditSeverity? failOn;

  /// 可选的已构建 APK。传入后会检查最终合并权限和 DEX/so 字符串。
  final String? apkPath;

  /// 本次构建实际传给 --dart-define-from-file 的环境文件。
  ///
  /// release 审计必须显式提供，避免把 development/testing 配置误当成发布配置，
  /// 也避免只扫描源码默认值却漏掉 CI 临时注入的真实生产域名。
  final String? environmentFilePath;
}

/// 一条可定位、可解释、可整改的审计结果。
final class AuditFinding {
  const AuditFinding({
    required this.ruleId,
    required this.severity,
    required this.title,
    required this.detail,
    required this.location,
    required this.remediation,
    this.evidence,
    this.approvedReason,
  });

  final String ruleId;
  final AuditSeverity severity;
  final String title;
  final String detail;
  final String location;
  final String remediation;

  /// 只保留命中的代码片段，不读取或输出真实运行期个人信息。
  final String? evidence;

  /// 命中项已经过人工登记时的理由。登记并不等于永久放行，版本变化仍会提示。
  final String? approvedReason;

  Map<String, Object?> toJson() => <String, Object?>{
    'ruleId': ruleId,
    'severity': severity.name,
    'title': title,
    'detail': detail,
    'location': location,
    'evidence': evidence,
    'remediation': remediation,
    'approvedReason': approvedReason,
  };
}

/// 本次扫描的完整结果。
final class PrivacyAuditResult {
  PrivacyAuditResult({required this.mode, required this.startedAt});

  final AuditMode mode;
  final DateTime startedAt;
  final List<AuditFinding> findings = <AuditFinding>[];
  final Map<String, Set<String>> permissions = <String, Set<String>>{};
  final List<ResolvedPlugin> plugins = <ResolvedPlugin>[];
  final Map<String, Set<String>> domains = <String, Set<String>>{};
  int filesScanned = 0;

  final Set<String> _findingKeys = <String>{};

  /// 多个扫描器可能发现同一个问题，统一在这里去重，避免报告重复刷屏。
  void addFinding(AuditFinding finding) {
    final key = <String>[
      finding.ruleId,
      finding.location,
      finding.evidence ?? '',
    ].join('|');
    if (_findingKeys.add(key)) {
      findings.add(finding);
    }
  }

  int count(AuditSeverity severity) =>
      findings.where((finding) => finding.severity == severity).length;

  bool shouldFail(AuditSeverity? threshold) {
    if (threshold == null) return false;
    return findings.any((finding) => finding.severity.rank >= threshold.rank);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'mode': mode.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'summary': <String, Object>{
      'filesScanned': filesScanned,
      'blocker': count(AuditSeverity.blocker),
      'review': count(AuditSeverity.review),
      'info': count(AuditSeverity.info),
    },
    'permissions': permissions.map(
      (name, origins) =>
          MapEntry<String, Object>(name, origins.toList()..sort()),
    ),
    'plugins': plugins.map((plugin) => plugin.toJson()).toList(),
    'domains': domains.map(
      (host, origins) =>
          MapEntry<String, Object>(host, origins.toList()..sort()),
    ),
    'findings': findings.map((finding) => finding.toJson()).toList(),
  };
}

/// Flutter 最终解析到 Android 端的原生插件。
final class ResolvedPlugin {
  const ResolvedPlugin({
    required this.name,
    required this.version,
    required this.path,
  });

  final String name;
  final String version;
  final String path;

  // 报告只需要名称和版本。插件绝对路径可能包含开发者用户名，不应写入 CI 产物。
  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'version': version,
  };
}

final class _SensitiveApiRule {
  const _SensitiveApiRule({
    required this.id,
    required this.name,
    required this.severity,
    required this.patterns,
    required this.binaryPatterns,
    required this.dexPatterns,
    required this.remediation,
  });

  final String id;
  final String name;
  final AuditSeverity severity;
  final List<String> patterns;
  final List<String> binaryPatterns;
  final List<String> dexPatterns;
  final String remediation;
}

final class _ExportedComponentDeclaration {
  const _ExportedComponentDeclaration({
    required this.name,
    required this.purpose,
    required this.requiredPermission,
  });

  final String name;
  final String purpose;
  final String requiredPermission;

  bool matchesName(String candidate) {
    return candidate == name ||
        (name.startsWith('.') && candidate.endsWith(name));
  }
}

final class _ApprovedFinding {
  const _ApprovedFinding({
    required this.ruleId,
    required this.reason,
    this.pathContains,
    this.evidenceContains,
  });

  final String ruleId;
  final String reason;
  final String? pathContains;
  final String? evidenceContains;

  bool matches({
    required String candidateRuleId,
    required String path,
    required String evidence,
  }) {
    if (ruleId != candidateRuleId) return false;
    if (pathContains != null && !path.contains(pathContains!)) return false;
    if (evidenceContains != null && !evidence.contains(evidenceContains!)) {
      return false;
    }
    return true;
  }
}

final class _AllowedDomain {
  const _AllowedDomain({
    required this.host,
    required this.purpose,
    required this.placeholder,
  });

  final String host;
  final String purpose;
  final bool placeholder;
}

final class _PluginDeclaration {
  const _PluginDeclaration({
    required this.name,
    required this.version,
    required this.purpose,
    required this.data,
  });

  final String name;
  final String version;
  final String purpose;
  final String data;
}

final class _ReleaseRequirements {
  const _ReleaseRequirements({
    required this.privacyPolicyUrlEnvironmentKey,
    required this.privacyPolicyVersionEnvironmentKey,
    required this.privacyPolicyDocumentVersionEnvironmentKey,
    required this.userAgreementUrlEnvironmentKey,
    required this.userAgreementDocumentVersionEnvironmentKey,
    required this.privacyGateMarkers,
    required this.accountDeletionMarkers,
  });

  final String privacyPolicyUrlEnvironmentKey;
  final String privacyPolicyVersionEnvironmentKey;
  final String privacyPolicyDocumentVersionEnvironmentKey;
  final String userAgreementUrlEnvironmentKey;
  final String userAgreementDocumentVersionEnvironmentKey;
  final List<String> privacyGateMarkers;
  final List<String> accountDeletionMarkers;
}

final class _DynamicAuditConsent {
  const _DynamicAuditConsent({
    required this.preferencesFile,
    required this.acceptedVersionKey,
    required this.legacyAcceptedVersionKey,
    required this.currentPolicyVersion,
  });

  final String preferencesFile;
  final String acceptedVersionKey;
  final String legacyAcceptedVersionKey;
  final String currentPolicyVersion;
}

/// compliance/privacy_audit.json 的强类型表示。
///
/// 解析时主动校验字段，避免配置写错后审计器“假装成功”。
final class _PrivacyAuditConfig {
  const _PrivacyAuditConfig({
    required this.sourceRoots,
    required this.allowedPermissions,
    required this.forbiddenPermissions,
    required this.allowedExportedComponents,
    required this.allowedDomains,
    required this.sensitiveApis,
    required this.approvedFindings,
    required this.nativePlugins,
    required this.releaseRequirements,
    required this.dynamicAuditConsent,
  });

  final List<String> sourceRoots;
  final Map<String, String> allowedPermissions;
  final Set<String> forbiddenPermissions;
  final List<_ExportedComponentDeclaration> allowedExportedComponents;
  final Map<String, _AllowedDomain> allowedDomains;
  final List<_SensitiveApiRule> sensitiveApis;
  final List<_ApprovedFinding> approvedFindings;
  final Map<String, _PluginDeclaration> nativePlugins;
  final _ReleaseRequirements releaseRequirements;
  final _DynamicAuditConsent dynamicAuditConsent;

  static _PrivacyAuditConfig load(File file) {
    if (!file.existsSync()) {
      throw StateError('找不到隐私审计配置：${file.path}');
    }
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('隐私审计配置根节点必须是 JSON 对象');
    }
    if (decoded['schemaVersion'] != 1) {
      throw FormatException(
        '不支持的 schemaVersion：${decoded['schemaVersion']}（当前仅支持 1）',
      );
    }

    final allowedPermissions = <String, String>{};
    for (final item in _objectList(decoded, 'allowedPermissions')) {
      allowedPermissions[_requiredString(item, 'name')] = _requiredString(
        item,
        'purpose',
      );
    }

    final allowedDomains = <String, _AllowedDomain>{};
    for (final item in _objectList(decoded, 'allowedDomains')) {
      final domain = _AllowedDomain(
        host: _requiredString(item, 'host').toLowerCase(),
        purpose: _requiredString(item, 'purpose'),
        placeholder: item['placeholder'] == true,
      );
      allowedDomains[domain.host] = domain;
    }

    final sensitiveApis = <_SensitiveApiRule>[];
    for (final item in _objectList(decoded, 'sensitiveApis')) {
      sensitiveApis.add(
        _SensitiveApiRule(
          id: _requiredString(item, 'id'),
          name: _requiredString(item, 'name'),
          severity: AuditSeverity.parse(_requiredString(item, 'severity')),
          patterns: _stringList(item, 'patterns'),
          binaryPatterns: _optionalStringList(item, 'binaryPatterns'),
          dexPatterns: _optionalStringList(item, 'dexPatterns'),
          remediation: _requiredString(item, 'remediation'),
        ),
      );
    }

    final approvedFindings = <_ApprovedFinding>[];
    for (final item in _objectList(decoded, 'approvedFindings')) {
      approvedFindings.add(
        _ApprovedFinding(
          ruleId: _requiredString(item, 'ruleId'),
          reason: _requiredString(item, 'reason'),
          pathContains: item['pathContains'] as String?,
          evidenceContains: item['evidenceContains'] as String?,
        ),
      );
    }

    final nativePlugins = <String, _PluginDeclaration>{};
    for (final item in _objectList(decoded, 'nativePlugins')) {
      final plugin = _PluginDeclaration(
        name: _requiredString(item, 'name'),
        version: _requiredString(item, 'version'),
        purpose: _requiredString(item, 'purpose'),
        data: _requiredString(item, 'data'),
      );
      nativePlugins[plugin.name] = plugin;
    }

    final release = decoded['releaseRequirements'];
    if (release is! Map<String, dynamic>) {
      throw const FormatException('releaseRequirements 必须是 JSON 对象');
    }
    final dynamicAudit = decoded['dynamicAuditConsent'];
    if (dynamicAudit is! Map<String, dynamic>) {
      throw const FormatException('dynamicAuditConsent 必须是 JSON 对象');
    }

    return _PrivacyAuditConfig(
      sourceRoots: _stringList(decoded, 'sourceRoots'),
      allowedPermissions: allowedPermissions,
      forbiddenPermissions: _stringList(
        decoded,
        'forbiddenPermissions',
      ).toSet(),
      allowedExportedComponents:
          _objectList(decoded, 'allowedExportedComponents')
              .map(
                (item) => _ExportedComponentDeclaration(
                  name: _requiredString(item, 'name'),
                  purpose: _requiredString(item, 'purpose'),
                  requiredPermission:
                      (item['requiredPermission'] as String?) ?? '',
                ),
              )
              .toList(),
      allowedDomains: allowedDomains,
      sensitiveApis: sensitiveApis,
      approvedFindings: approvedFindings,
      nativePlugins: nativePlugins,
      releaseRequirements: _ReleaseRequirements(
        privacyPolicyUrlEnvironmentKey: _requiredString(
          release,
          'privacyPolicyUrlEnvironmentKey',
        ),
        privacyPolicyVersionEnvironmentKey: _requiredString(
          release,
          'privacyPolicyVersionEnvironmentKey',
        ),
        privacyPolicyDocumentVersionEnvironmentKey: _requiredString(
          release,
          'privacyPolicyDocumentVersionEnvironmentKey',
        ),
        userAgreementUrlEnvironmentKey: _requiredString(
          release,
          'userAgreementUrlEnvironmentKey',
        ),
        userAgreementDocumentVersionEnvironmentKey: _requiredString(
          release,
          'userAgreementDocumentVersionEnvironmentKey',
        ),
        privacyGateMarkers: _stringList(release, 'privacyGateMarkers'),
        accountDeletionMarkers: _stringList(release, 'accountDeletionMarkers'),
      ),
      dynamicAuditConsent: _DynamicAuditConsent(
        preferencesFile: _requiredString(dynamicAudit, 'preferencesFile'),
        acceptedVersionKey: _requiredString(dynamicAudit, 'acceptedVersionKey'),
        legacyAcceptedVersionKey: _requiredString(
          dynamicAudit,
          'legacyAcceptedVersionKey',
        ),
        currentPolicyVersion: _requiredString(
          dynamicAudit,
          'currentPolicyVersion',
        ),
      ),
    );
  }

  static List<Map<String, dynamic>> _objectList(
    Map<String, dynamic> map,
    String key,
  ) {
    final value = map[key];
    if (value is! List) throw FormatException('$key 必须是 JSON 数组');
    return value.map((item) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('$key 的每一项都必须是 JSON 对象');
      }
      return item;
    }).toList();
  }

  static List<String> _stringList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('$key 必须是字符串数组');
    }
    return value.cast<String>();
  }

  static List<String> _optionalStringList(
    Map<String, dynamic> map,
    String key,
  ) {
    if (!map.containsKey(key)) return const <String>[];
    return _stringList(map, key);
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key 必须是非空字符串');
    }
    return value;
  }
}

final class _SourceDocument {
  const _SourceDocument({
    required this.file,
    required this.displayPath,
    this.pluginName,
  });

  final File file;
  final String displayPath;
  final String? pluginName;
}

/// 隐私合规静态审计器。
///
/// 它的职责是发现“需要阻断或人工确认”的信号，不替代应用市场的动态检测、
/// 法务审核或真实设备测试。把这个边界写清楚可以避免把脚本报告误当成合规证明。
final class PrivacyAuditor {
  PrivacyAuditor(this.options)
    : _config = _PrivacyAuditConfig.load(
        File(p.join(options.rootDirectory.path, options.configPath)),
      );

  final PrivacyAuditOptions options;
  final _PrivacyAuditConfig _config;

  Future<PrivacyAuditResult> run() async {
    final result = PrivacyAuditResult(
      mode: options.mode,
      startedAt: DateTime.now(),
    );

    final plugins = _readResolvedPlugins(result);
    result.plugins.addAll(plugins);
    _auditPluginInventory(result, plugins);

    final projectDocuments = _collectProjectDocuments();
    final pluginDocuments = _collectPluginDocuments(plugins);
    result.filesScanned = projectDocuments.length + pluginDocuments.length;

    _scanSensitiveApis(result, <_SourceDocument>[
      ...projectDocuments,
      ...pluginDocuments,
    ]);
    _scanPermissions(result, plugins);
    _validateReleaseEnvironmentFile(result);
    _validateDynamicAuditConsent(result);
    _scanDomains(result, projectDocuments);
    _scanAndroidApplicationConfig(result);
    _scanIosApplicationConfig(result);
    _scanReleaseRequirements(result, projectDocuments);

    final apkPath = options.apkPath;
    if (apkPath != null) {
      await _scanApk(result, File(_absoluteFromRoot(apkPath)));
    }

    result.findings.sort((left, right) {
      final bySeverity = right.severity.rank.compareTo(left.severity.rank);
      if (bySeverity != 0) return bySeverity;
      final byLocation = left.location.compareTo(right.location);
      if (byLocation != 0) return byLocation;
      return left.ruleId.compareTo(right.ruleId);
    });
    return result;
  }

  List<ResolvedPlugin> _readResolvedPlugins(PrivacyAuditResult result) {
    final dependencies = File(
      p.join(options.rootDirectory.path, '.flutter-plugins-dependencies'),
    );
    if (!dependencies.existsSync()) {
      result.addFinding(
        const AuditFinding(
          ruleId: 'plugin_metadata_missing',
          severity: AuditSeverity.review,
          title: '缺少 Flutter 原生插件解析文件',
          detail: '无法核对 APK 最终会注册哪些 Android 原生插件。',
          location: '.flutter-plugins-dependencies',
          remediation: '先执行 flutter pub get，再重新运行隐私审计。',
        ),
      );
      return const <ResolvedPlugin>[];
    }

    try {
      final json = jsonDecode(dependencies.readAsStringSync());
      if (json is! Map<String, dynamic>) throw const FormatException();
      final plugins = json['plugins'];
      if (plugins is! Map<String, dynamic>) throw const FormatException();
      final android = plugins['android'];
      if (android is! List) throw const FormatException();

      final resolved = <ResolvedPlugin>[];
      for (final raw in android) {
        if (raw is! Map<String, dynamic> || raw['dev_dependency'] == true) {
          continue;
        }
        final name = raw['name'];
        final path = raw['path'];
        if (name is! String || path is! String) continue;
        final directoryName = p.basename(p.normalize(path));
        final prefix = '$name-';
        final version = directoryName.startsWith(prefix)
            ? directoryName.substring(prefix.length)
            : 'unknown';
        resolved.add(ResolvedPlugin(name: name, version: version, path: path));
      }
      resolved.sort((left, right) => left.name.compareTo(right.name));
      return resolved;
    } on Object catch (error) {
      result.addFinding(
        AuditFinding(
          ruleId: 'plugin_metadata_invalid',
          severity: AuditSeverity.blocker,
          title: 'Flutter 原生插件解析文件无法读取',
          detail: '插件清单不是预期的 JSON 结构：${error.runtimeType}。',
          location: '.flutter-plugins-dependencies',
          remediation: '删除该生成文件并重新执行 flutter pub get。',
        ),
      );
      return const <ResolvedPlugin>[];
    }
  }

  void _auditPluginInventory(
    PrivacyAuditResult result,
    List<ResolvedPlugin> plugins,
  ) {
    final resolvedNames = plugins.map((plugin) => plugin.name).toSet();
    for (final plugin in plugins) {
      final declaration = _config.nativePlugins[plugin.name];
      if (declaration == null) {
        result.addFinding(
          AuditFinding(
            ruleId: 'undeclared_native_plugin',
            severity: AuditSeverity.blocker,
            title: '发现未登记的 Android 原生插件',
            detail: '${plugin.name} 会进入 Android 安装包，但 SDK 清单没有用途和数据说明。',
            location: '.flutter-plugins-dependencies',
            evidence: '${plugin.name} ${plugin.version}',
            remediation:
                '先审查插件源码、权限、初始化时机和隐私条款，再把结论登记到 compliance/privacy_audit.json。',
          ),
        );
        continue;
      }
      if (declaration.version != plugin.version) {
        result.addFinding(
          AuditFinding(
            ruleId: 'native_plugin_version_changed',
            severity: AuditSeverity.review,
            title: '原生插件版本已经变化',
            detail:
                '${plugin.name} 登记版本为 ${declaration.version}，实际解析版本为 ${plugin.version}。插件升级可能新增权限或采集行为。',
            location: '.flutter-plugins-dependencies',
            evidence: '${plugin.name} ${plugin.version}',
            remediation: '复核新版本原生代码和隐私说明，通过后更新配置中的版本；不要只机械修改版本号。',
          ),
        );
      }
    }

    for (final declaration in _config.nativePlugins.values) {
      if (!resolvedNames.contains(declaration.name)) {
        result.addFinding(
          AuditFinding(
            ruleId: 'stale_native_plugin_declaration',
            severity: AuditSeverity.review,
            title: 'SDK 清单存在未解析到的插件',
            detail: '${declaration.name} 已不在当前 Android 插件解析结果中，登记信息可能已经过期。',
            location: 'compliance/privacy_audit.json',
            evidence: declaration.name,
            remediation: '确认依赖确已删除后，同步删除清单项和隐私政策中的相关说明。',
          ),
        );
      }
    }
  }

  List<_SourceDocument> _collectProjectDocuments() {
    final documents = <_SourceDocument>[];
    for (final relativeRoot in _config.sourceRoots) {
      final root = Directory(p.join(options.rootDirectory.path, relativeRoot));
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true, followLinks: false)) {
        if (entity is! File || !_isScannableTextFile(entity.path)) continue;
        final relative = p.relative(
          entity.path,
          from: options.rootDirectory.path,
        );
        if (_isIgnoredPath(relative)) continue;
        documents.add(
          _SourceDocument(file: entity, displayPath: p.normalize(relative)),
        );
      }
    }
    final environmentPath = options.environmentFilePath;
    if (environmentPath != null) {
      final file = File(_absoluteFromRoot(environmentPath));
      final alreadyIncluded = documents.any(
        (document) => p.equals(document.file.path, file.path),
      );
      if (file.existsSync() &&
          _isScannableTextFile(file.path) &&
          !alreadyIncluded) {
        documents.add(
          _SourceDocument(
            file: file,
            displayPath: p.normalize(
              p.relative(file.path, from: options.rootDirectory.path),
            ),
          ),
        );
      }
    }
    return documents;
  }

  List<_SourceDocument> _collectPluginDocuments(List<ResolvedPlugin> plugins) {
    final documents = <_SourceDocument>[];
    for (final plugin in plugins) {
      final androidSource = Directory(
        p.join(plugin.path, 'android', 'src', 'main'),
      );
      if (!androidSource.existsSync()) continue;
      for (final entity in androidSource.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !_isScannableTextFile(entity.path)) continue;
        final relative = p.relative(entity.path, from: plugin.path);
        documents.add(
          _SourceDocument(
            file: entity,
            displayPath: 'plugin:${plugin.name}/${p.normalize(relative)}',
            pluginName: plugin.name,
          ),
        );
      }
    }
    return documents;
  }

  bool _isScannableTextFile(String path) {
    const extensions = <String>{
      '.dart',
      '.java',
      '.kt',
      '.kts',
      '.swift',
      '.m',
      '.mm',
      '.xml',
      '.plist',
      '.gradle',
      '.json',
      '.yaml',
      '.yml',
      '.pbxproj',
    };
    return extensions.contains(p.extension(path).toLowerCase());
  }

  bool _isIgnoredPath(String path) {
    final normalized = p.normalize(path);
    const ignoredSegments = <String>{
      '.dart_tool',
      '.git',
      '.symlinks',
      'build',
      'Pods',
    };
    if (p.split(normalized).any(ignoredSegments.contains)) return true;
    return normalized.endsWith('.g.dart') ||
        normalized.endsWith('.freezed.dart');
  }

  void _scanSensitiveApis(
    PrivacyAuditResult result,
    List<_SourceDocument> documents,
  ) {
    for (final document in documents) {
      final lines = _stripBlockComments(document.file.readAsLinesSync());
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_isCommentOnlyLine(line)) continue;
        for (final rule in _config.sensitiveApis) {
          for (final pattern in rule.patterns) {
            if (!line.contains(pattern)) continue;
            final location = '${document.displayPath}:${index + 1}';
            final evidence = _shorten(line.trim());
            final approval = _config.approvedFindings
                .cast<_ApprovedFinding?>()
                .firstWhere(
                  (candidate) => candidate!.matches(
                    candidateRuleId: rule.id,
                    path: document.displayPath,
                    evidence: evidence,
                  ),
                  orElse: () => null,
                );
            result.addFinding(
              AuditFinding(
                ruleId: rule.id,
                severity: approval == null ? rule.severity : AuditSeverity.info,
                title: approval == null
                    ? '发现敏感 API：${rule.name}'
                    : '已登记的敏感 API：${rule.name}',
                detail: approval == null
                    ? '静态代码包含敏感调用信号，需要确认真实执行条件、同意时机和数据用途。'
                    : '该调用已登记。本次仍保留在报告中，便于升级依赖时重新检查。',
                location: location,
                evidence: evidence,
                remediation: rule.remediation,
                approvedReason: approval?.reason,
              ),
            );
          }
        }
      }
    }
  }

  void _scanPermissions(
    PrivacyAuditResult result,
    List<ResolvedPlugin> plugins,
  ) {
    final manifests = <MapEntry<String, File>>[
      MapEntry<String, File>(
        'android/app/src/main/AndroidManifest.xml',
        File(
          p.join(
            options.rootDirectory.path,
            'android',
            'app',
            'src',
            'main',
            'AndroidManifest.xml',
          ),
        ),
      ),
      ...plugins.map(
        (plugin) => MapEntry<String, File>(
          'plugin:${plugin.name}/android/src/main/AndroidManifest.xml',
          File(
            p.join(
              plugin.path,
              'android',
              'src',
              'main',
              'AndroidManifest.xml',
            ),
          ),
        ),
      ),
    ];

    final permissionPattern = RegExp(
      r'''<uses-permission(?:-sdk-\d+)?\b[^>]*android:name\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    for (final manifest in manifests) {
      if (!manifest.value.existsSync()) continue;
      final content = manifest.value.readAsStringSync();
      for (final match in permissionPattern.allMatches(content)) {
        final permission = match.group(1)!;
        result.permissions
            .putIfAbsent(permission, () => <String>{})
            .add(manifest.key);
      }
    }
    _evaluatePermissionInventory(result);
  }

  void _evaluatePermissionInventory(PrivacyAuditResult result) {
    for (final entry in result.permissions.entries) {
      final permission = entry.key;
      final origins = entry.value.toList()..sort();
      if (_config.forbiddenPermissions.contains(permission)) {
        result.addFinding(
          AuditFinding(
            ruleId: 'forbidden_android_permission',
            severity: AuditSeverity.blocker,
            title: '发现底座禁止使用的 Android 权限',
            detail: '$permission 属于高敏或过度权限，当前底座没有允许它。',
            location: origins.join(', '),
            evidence: permission,
            remediation: '优先删除权限和对应能力；确有核心业务必要时，先完成专项合规评估再调整规则。',
          ),
        );
      } else if (!_config.allowedPermissions.containsKey(permission)) {
        result.addFinding(
          AuditFinding(
            ruleId: 'undeclared_android_permission',
            severity: AuditSeverity.blocker,
            title: '发现未登记的 Android 权限',
            detail: '$permission 会进入应用，但权限白名单没有记录使用目的。',
            location: origins.join(', '),
            evidence: permission,
            remediation: '查清权限由业务还是三方插件引入；不需要就移除，需要则登记用途并同步隐私政策和权限申请时机。',
          ),
        );
      }
    }
  }

  void _scanDomains(
    PrivacyAuditResult result,
    List<_SourceDocument> projectDocuments,
  ) {
    final urlPattern = RegExp(r'''https?://[^\s'"<>`)\]}]+''');
    const domainExtensions = <String>{'.dart', '.json', '.yaml', '.yml'};
    final selectedEnvironmentPath = options.environmentFilePath == null
        ? null
        : p.normalize(
            p.relative(
              _absoluteFromRoot(options.environmentFilePath!),
              from: options.rootDirectory.path,
            ),
          );
    for (final document in projectDocuments) {
      if (!domainExtensions.contains(p.extension(document.file.path))) continue;
      final isConfigFile = p.isWithin('config', document.displayPath);
      if (options.mode == AuditMode.release &&
          isConfigFile &&
          document.displayPath != selectedEnvironmentPath) {
        // development/testing/示例配置不会进入本次 Release 构建，不能用它们制造
        // 永远无法消除的发布阻断；实际构建文件由 --environment-file 明确指定。
        continue;
      }
      final lines = _stripBlockComments(document.file.readAsLinesSync());
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_isCommentOnlyLine(line)) continue;
        for (final match in urlPattern.allMatches(line)) {
          final raw = match.group(0)!.replaceAll(RegExp(r'[,.;]+$'), '');
          final uri = Uri.tryParse(raw);
          if (uri == null || uri.host.isEmpty) continue;
          final host = uri.host.toLowerCase();
          final location = '${document.displayPath}:${index + 1}';
          result.domains.putIfAbsent(host, () => <String>{}).add(location);

          final allowed = _config.allowedDomains[host];
          if (uri.scheme == 'http' &&
              host != 'localhost' &&
              host != '127.0.0.1') {
            result.addFinding(
              AuditFinding(
                ruleId: 'cleartext_runtime_url',
                severity: options.mode == AuditMode.release
                    ? AuditSeverity.blocker
                    : AuditSeverity.review,
                title: '发现明文 HTTP 地址',
                detail: '$raw 可能让业务数据通过明文链路传输。',
                location: location,
                evidence: raw,
                remediation: '改用 HTTPS，并在服务端和客户端关闭不必要的明文降级。',
              ),
            );
          }
          if (allowed == null) {
            result.addFinding(
              AuditFinding(
                ruleId: 'undeclared_runtime_domain',
                severity: options.mode == AuditMode.release
                    ? AuditSeverity.blocker
                    : AuditSeverity.review,
                title: '发现未登记的运行期域名',
                detail: '$host 不在域名清单中，无法判断数据会发送给谁。',
                location: location,
                evidence: raw,
                remediation: '确认域名所有者、用途和传输数据后加入清单；无业务需要则删除对应请求。',
              ),
            );
          } else if (allowed.placeholder) {
            final isSelectedReleaseConfig =
                options.mode == AuditMode.release &&
                document.displayPath == selectedEnvironmentPath;
            result.addFinding(
              AuditFinding(
                ruleId: 'placeholder_runtime_domain',
                severity: isSelectedReleaseConfig
                    ? AuditSeverity.blocker
                    : AuditSeverity.info,
                title: '仍在使用模板域名',
                detail: '${allowed.host} 只用于底座示例，不能作为正式环境地址。',
                location: location,
                evidence: raw,
                remediation: '接入真实项目时替换域名，并同步更新域名清单和隐私政策。',
              ),
            );
          }
        }
      }
    }
  }

  void _validateReleaseEnvironmentFile(PrivacyAuditResult result) {
    if (options.mode != AuditMode.release) return;
    final path = options.environmentFilePath;
    if (path == null || path.trim().isEmpty) {
      result.addFinding(
        const AuditFinding(
          ruleId: 'release_environment_file_missing',
          severity: AuditSeverity.blocker,
          title: 'Release 审计没有指定实际环境文件',
          detail: '无法确认本次 APK 构建到底使用了哪个 API 域名和安全开关。',
          location: '命令行参数 --environment-file',
          remediation:
              '把 flutter build 使用的同一个 --dart-define-from-file 文件传给审计器。',
        ),
      );
      return;
    }
    final file = File(_absoluteFromRoot(path));
    if (!file.existsSync()) {
      result.addFinding(
        AuditFinding(
          ruleId: 'release_environment_file_not_found',
          severity: AuditSeverity.blocker,
          title: 'Release 环境文件不存在',
          detail: '无法读取本次构建声称使用的环境配置。',
          location: path,
          remediation: '确认路径与 flutter build 的 --dart-define-from-file 参数完全一致。',
        ),
      );
    }
  }

  void _validateDynamicAuditConsent(PrivacyAuditResult result) {
    final declaration = _config.dynamicAuditConsent;
    final hookPath = p.join('tool', 'privacy', 'android_privacy_hooks.js');
    final hook = File(p.join(options.rootDirectory.path, hookPath));
    if (!hook.existsSync()) {
      result.addFinding(
        AuditFinding(
          ruleId: 'dynamic_privacy_hook_missing',
          severity: AuditSeverity.blocker,
          title: '找不到 Android 动态隐私观察脚本',
          detail: '无法在真机上区分同意前和同意后的敏感 API 调用。',
          location: hookPath,
          remediation: '恢复动态 Hook，或从合规配置中明确移除这项研发能力。',
        ),
      );
      return;
    }

    final content = hook.readAsStringSync();
    final expectedValues = <String, String>{
      'preferencesFile': declaration.preferencesFile,
      'acceptedVersionKey': declaration.acceptedVersionKey,
      'legacyAcceptedVersionKey': declaration.legacyAcceptedVersionKey,
      'currentPolicyVersion': declaration.currentPolicyVersion,
    };
    for (final entry in expectedValues.entries) {
      if (content.contains("${entry.key}: '${entry.value}'")) continue;
      result.addFinding(
        AuditFinding(
          ruleId: 'dynamic_privacy_hook_config_mismatch',
          severity: AuditSeverity.blocker,
          title: '动态隐私脚本与审计配置不一致',
          detail: '${entry.key} 不一致会把同意前调用错误归类为同意后。',
          location: hookPath,
          evidence: entry.key,
          remediation:
              '同步更新 compliance/privacy_audit.json 和 Hook 顶部 PRIVACY_CONSENT_CONFIG。',
        ),
      );
    }

    final environmentPath = options.mode == AuditMode.release
        ? options.environmentFilePath
        : p.join('config', 'development.json');
    if (environmentPath == null) return;
    final environmentFile = File(_absoluteFromRoot(environmentPath));
    if (!environmentFile.existsSync()) return;
    try {
      final json = jsonDecode(environmentFile.readAsStringSync());
      final runtimeVersion = json is Map<String, dynamic>
          ? json['ENV_PRIVACY_POLICY_VERSION']
          : null;
      if (runtimeVersion == declaration.currentPolicyVersion) return;
      result.addFinding(
        AuditFinding(
          ruleId: 'dynamic_privacy_policy_version_mismatch',
          severity: AuditSeverity.blocker,
          title: '动态检测使用了错误的隐私政策版本',
          detail: '构建环境的 ENV_PRIVACY_POLICY_VERSION 与动态审计版本不同，日志阶段不可信。',
          location: environmentPath,
          evidence: 'ENV_PRIVACY_POLICY_VERSION',
          remediation:
              '把环境配置、dynamicAuditConsent.currentPolicyVersion 和 Hook 常量更新为同一版本。',
        ),
      );
    } on FormatException {
      // 环境 JSON 的通用格式问题会在其他扫描/构建环节暴露；这里不重复制造同类报告。
    }
  }

  void _scanAndroidApplicationConfig(PrivacyAuditResult result) {
    final relative = p.join(
      'android',
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );
    final manifest = File(p.join(options.rootDirectory.path, relative));
    if (!manifest.existsSync()) {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_manifest_missing',
          severity: AuditSeverity.blocker,
          title: '找不到 Android 主清单',
          detail: '无法判断正式包的权限和组件暴露情况。',
          location: relative,
          remediation: '恢复 Android 主清单，或修正规则中的项目结构。',
        ),
      );
      return;
    }
    _evaluateAndroidManifestText(
      result,
      content: manifest.readAsStringSync(),
      location: relative,
    );
  }

  void _evaluateAndroidManifestText(
    PrivacyAuditResult result, {
    required String content,
    required String location,
  }) {
    if (RegExp(
      r'''android:debuggable\s*=\s*["']true["']''',
    ).hasMatch(content)) {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_debuggable_enabled',
          severity: AuditSeverity.blocker,
          title: 'Android 主清单开启了 debuggable',
          detail: '正式包可被调试会扩大数据泄露和逆向风险。',
          location: location,
          remediation: '从 main/Manifest 删除 debuggable=true；调试配置只放在 debug 构建变体。',
        ),
      );
    }

    final cleartext = RegExp(
      r'''android:usesCleartextTraffic\s*=\s*["']([^"']+)["']''',
    ).firstMatch(content)?.group(1);
    if (cleartext == 'true') {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_cleartext_enabled',
          severity: AuditSeverity.blocker,
          title: 'Android 允许所有明文网络流量',
          detail: 'usesCleartextTraffic=true 会允许 HTTP 明文请求。',
          location: location,
          remediation: '关闭全局明文流量；如开发代理确需 HTTP，只在 debug 变体单独配置。',
        ),
      );
    } else if (cleartext == null) {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_cleartext_implicit',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.review
              : AuditSeverity.info,
          title: 'Android 未显式声明明文流量策略',
          detail: '当前行为依赖 Android 版本默认值，不便于评审确认。',
          location: location,
          remediation: '企业项目接入后建议显式设置 android:usesCleartextTraffic="false"。',
        ),
      );
    }

    final allowBackup = RegExp(
      r'''android:allowBackup\s*=\s*["']([^"']+)["']''',
    ).firstMatch(content)?.group(1);
    if (allowBackup == 'true') {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_backup_enabled',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.blocker
              : AuditSeverity.review,
          title: 'Android 允许备份应用数据',
          detail: '业务缓存或普通存储可能被系统备份迁移。',
          location: location,
          remediation:
              '根据数据分级设置 allowBackup/dataExtractionRules；含敏感业务数据时默认关闭或明确排除。',
        ),
      );
    } else if (allowBackup == null) {
      result.addFinding(
        AuditFinding(
          ruleId: 'android_backup_implicit',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.review
              : AuditSeverity.info,
          title: 'Android 未显式声明备份策略',
          detail: '无法从主清单直接确认哪些数据允许进入系统备份。',
          location: location,
          remediation: '真实项目应根据数据分级显式配置 allowBackup 和 Android 12+ 数据提取规则。',
        ),
      );
    }

    final componentPattern = RegExp(
      r'<(activity|activity-alias|service|receiver|provider)\b([\s\S]*?)(?:/>|>)',
      caseSensitive: false,
    );
    for (final component in componentPattern.allMatches(content)) {
      final attributes = component.group(2)!;
      if (!RegExp(
        r'''android:exported\s*=\s*["']true["']''',
      ).hasMatch(attributes)) {
        continue;
      }
      final name = RegExp(
        r'''android:name\s*=\s*["']([^"']+)["']''',
      ).firstMatch(attributes)?.group(1);
      final declaration = name == null
          ? null
          : _findAllowedExportedComponent(name);
      if (declaration != null) {
        final actualPermission = RegExp(
          r'''android:permission\s*=\s*["']([^"']+)["']''',
        ).firstMatch(attributes)?.group(1);
        if (declaration.requiredPermission.isNotEmpty &&
            actualPermission != declaration.requiredPermission) {
          result.addFinding(
            AuditFinding(
              ruleId: 'exported_component_permission_changed',
              severity: AuditSeverity.blocker,
              title: '已登记导出组件缺少预期权限保护',
              detail:
                  '$name 的导出用途是“${declaration.purpose}”，预期由 ${declaration.requiredPermission} 保护，实际为 ${actualPermission ?? '未设置'}。',
              location: location,
              evidence: name,
              remediation: '检查依赖升级或 Manifest 合并结果，不要在缺少调用方限制时继续放行该组件。',
            ),
          );
        }
        continue;
      }
      result.addFinding(
        AuditFinding(
          ruleId: 'undeclared_exported_component',
          severity: AuditSeverity.blocker,
          title: '发现未登记的 Android 导出组件',
          detail: '${name ?? '未命名组件'} 可以被其他应用调用，可能绕过 Flutter 页面和鉴权入口。',
          location: location,
          evidence: name ?? component.group(1),
          remediation: '不需要外部调用时设置 exported=false；需要时增加调用方校验并登记到白名单。',
        ),
      );
    }
  }

  _ExportedComponentDeclaration? _findAllowedExportedComponent(String name) {
    for (final declaration in _config.allowedExportedComponents) {
      if (declaration.matchesName(name)) return declaration;
    }
    return null;
  }

  void _scanIosApplicationConfig(PrivacyAuditResult result) {
    final privacyManifest = File(
      p.join(
        options.rootDirectory.path,
        'ios',
        'Runner',
        'PrivacyInfo.xcprivacy',
      ),
    );
    if (!privacyManifest.existsSync()) {
      result.addFinding(
        AuditFinding(
          ruleId: 'ios_privacy_manifest_missing',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.review
              : AuditSeverity.info,
          title: 'App Target 没有 Privacy Manifest',
          detail: '三方插件可以自带 PrivacyInfo.xcprivacy，但项目自身调用受要求原因 API 时仍需声明。',
          location: 'ios/Runner/PrivacyInfo.xcprivacy',
          remediation:
              '提审前根据 App 自身使用的 Required Reason API 决定是否添加，不要复制与实际行为无关的模板。',
        ),
      );
    }
  }

  void _scanReleaseRequirements(
    PrivacyAuditResult result,
    List<_SourceDocument> projectDocuments,
  ) {
    final requirements = _config.releaseRequirements;
    final missingSeverity = options.mode == AuditMode.release
        ? AuditSeverity.blocker
        : AuditSeverity.review;
    final environmentPath = options.mode == AuditMode.release
        ? options.environmentFilePath
        : p.join('config', 'development.json');
    Map<String, dynamic>? environment;
    if (environmentPath != null) {
      final file = File(_absoluteFromRoot(environmentPath));
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) environment = decoded;
      }
    }
    final policyUrl = environment?[requirements.privacyPolicyUrlEnvironmentKey];
    final policyVersion =
        environment?[requirements.privacyPolicyVersionEnvironmentKey];
    final policyDocumentVersion =
        environment?[requirements.privacyPolicyDocumentVersionEnvironmentKey];
    final userAgreementUrl =
        environment?[requirements.userAgreementUrlEnvironmentKey];
    final userAgreementDocumentVersion =
        environment?[requirements.userAgreementDocumentVersionEnvironmentKey];
    if (policyUrl is! String || policyUrl.trim().isEmpty) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_policy_url_missing',
          severity: missingSeverity,
          title: '尚未登记隐私政策地址',
          detail:
              '本次环境文件没有 ${requirements.privacyPolicyUrlEnvironmentKey}，底座不知道向用户展示哪一份政策。',
          location: environmentPath ?? '命令行参数 --environment-file',
          remediation: '在实际 dart-define 环境文件填写可公开访问的正式隐私政策 URL。',
        ),
      );
    }
    if (policyDocumentVersion is! String ||
        policyDocumentVersion.trim().isEmpty) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_policy_document_version_missing',
          severity: missingSeverity,
          title: '尚未登记隐私政策文档版本',
          detail:
              '本次环境文件没有 ${requirements.privacyPolicyDocumentVersionEnvironmentKey}，无法追溯用户当时阅读的具体正文。',
          location: environmentPath ?? '命令行参数 --environment-file',
          remediation: '填写经过审核的政策文档版本；普通文案修订只更新该值。',
        ),
      );
    } else if (options.mode == AuditMode.release &&
        (policyDocumentVersion == 'starter-document-1' ||
            policyDocumentVersion.startsWith('replace-with-'))) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_policy_document_version_placeholder',
          severity: AuditSeverity.blocker,
          title: 'Release 仍在使用模板隐私政策文档版本',
          detail: '$policyDocumentVersion 不是可发布的真实文档版本。',
          location: environmentPath ?? '命令行参数 --environment-file',
          evidence: policyDocumentVersion,
          remediation: '替换为法务审核通过的政策正文版本。',
        ),
      );
    }
    if (userAgreementUrl is! String || userAgreementUrl.trim().isEmpty) {
      result.addFinding(
        AuditFinding(
          ruleId: 'user_agreement_url_missing',
          severity: missingSeverity,
          title: '尚未登记用户协议地址',
          detail:
              '本次环境文件没有 ${requirements.userAgreementUrlEnvironmentKey}，登录页无法打开完整用户协议。',
          location: environmentPath ?? '命令行参数 --environment-file',
          remediation: '填写可公开访问的正式用户协议 URL。',
        ),
      );
    }
    if (userAgreementDocumentVersion is! String ||
        userAgreementDocumentVersion.trim().isEmpty) {
      result.addFinding(
        AuditFinding(
          ruleId: 'user_agreement_document_version_missing',
          severity: missingSeverity,
          title: '尚未登记用户协议文档版本',
          detail:
              '本次环境文件没有 ${requirements.userAgreementDocumentVersionEnvironmentKey}，无法追溯用户当时同意的具体正文。',
          location: environmentPath ?? '命令行参数 --environment-file',
          remediation: '填写经过审核的用户协议文档版本。',
        ),
      );
    } else if (options.mode == AuditMode.release &&
        (userAgreementDocumentVersion == 'starter-user-agreement-1' ||
            userAgreementDocumentVersion.startsWith('replace-with-'))) {
      result.addFinding(
        AuditFinding(
          ruleId: 'user_agreement_document_version_placeholder',
          severity: AuditSeverity.blocker,
          title: 'Release 仍在使用模板用户协议文档版本',
          detail: '$userAgreementDocumentVersion 不是可发布的真实文档版本。',
          location: environmentPath ?? '命令行参数 --environment-file',
          evidence: userAgreementDocumentVersion,
          remediation: '替换为法务审核通过的用户协议正文版本。',
        ),
      );
    }
    if (policyVersion is! String || policyVersion.trim().isEmpty) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_policy_version_missing',
          severity: missingSeverity,
          title: '尚未登记隐私政策版本',
          detail: '没有版本就无法证明用户同意的是哪一版条款，也无法处理条款升级后的重新确认。',
          location: environmentPath ?? '命令行参数 --environment-file',
          remediation: '在实际 dart-define 环境文件设置稳定业务版本号。',
        ),
      );
    } else if (options.mode == AuditMode.release &&
        (policyVersion == 'starter-1' ||
            policyVersion.startsWith('replace-with-'))) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_policy_version_placeholder',
          severity: AuditSeverity.blocker,
          title: 'Release 仍在使用模板隐私政策版本',
          detail: '$policyVersion 不是可发布的真实政策版本。',
          location: environmentPath ?? '命令行参数 --environment-file',
          evidence: policyVersion,
          remediation: '替换为经过审核的稳定业务版本，并同步动态审计配置。',
        ),
      );
    }

    final dartContents = projectDocuments
        .where((document) => p.extension(document.file.path) == '.dart')
        .map((document) => document.file.readAsStringSync())
        .join('\n');
    if (!_containsAny(dartContents, requirements.privacyGateMarkers)) {
      result.addFinding(
        AuditFinding(
          ruleId: 'privacy_gate_not_detected',
          severity: missingSeverity,
          title: '未识别到隐私同意门禁',
          detail: '工具没有找到配置的入口标记，无法确认敏感 SDK 是否在用户同意前被初始化。',
          location: 'lib/',
          evidence: requirements.privacyGateMarkers.join(', '),
          remediation: '真实项目应在启动编排中加入可测试的隐私同意状态，并把实际类名登记为 privacyGateMarkers。',
        ),
      );
    }
    if (!_containsAny(dartContents, requirements.accountDeletionMarkers)) {
      result.addFinding(
        AuditFinding(
          ruleId: 'account_deletion_not_detected',
          severity: missingSeverity,
          title: '未识别到账号注销能力',
          detail: '有账号体系的正式项目通常需要提供可到达的账号注销入口。',
          location: 'lib/',
          evidence: requirements.accountDeletionMarkers.join(', '),
          remediation: '由真实业务实现服务端注销流程；无账号体系时在项目合规记录中说明不适用，并调整该规则。',
        ),
      );
    }
  }

  Future<void> _scanApk(PrivacyAuditResult result, File apk) async {
    if (!apk.existsSync()) {
      result.addFinding(
        AuditFinding(
          ruleId: 'apk_missing',
          severity: AuditSeverity.blocker,
          title: '找不到待审计 APK',
          detail: '命令传入的 APK 不存在。',
          location: apk.path,
          remediation: '先构建 Release APK，再把正确路径传给 --apk。',
        ),
      );
      return;
    }

    final analyzer = await _findApkAnalyzer();
    if (analyzer == null) {
      result.addFinding(
        AuditFinding(
          ruleId: 'apkanalyzer_unavailable',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.blocker
              : AuditSeverity.review,
          title: '无法解析 APK 合并清单',
          detail: '未找到 Android SDK 的 apkanalyzer。源码清单不等于最终安装包清单。',
          location: apk.path,
          remediation:
              '安装 Android SDK Command-line Tools，并配置 ANDROID_SDK_ROOT 后重新执行。',
        ),
      );
    } else {
      final permissions = await Process.run(analyzer, <String>[
        'manifest',
        'permissions',
        apk.path,
      ]);
      if (permissions.exitCode == 0) {
        final pattern = RegExp(r'android\.permission\.[A-Z0-9_\.]+');
        for (final match in pattern.allMatches('${permissions.stdout}')) {
          result.permissions
              .putIfAbsent(match.group(0)!, () => <String>{})
              .add('apk:${p.basename(apk.path)}');
        }
        _evaluatePermissionInventory(result);
      } else {
        result.addFinding(
          AuditFinding(
            ruleId: 'apk_manifest_parse_failed',
            severity: AuditSeverity.blocker,
            title: 'APK 权限解析失败',
            detail: _shorten('${permissions.stderr}'),
            location: apk.path,
            remediation: '确认 APK 完整且 apkanalyzer 可正常读取，然后重新审计。',
          ),
        );
      }

      final manifest = await Process.run(analyzer, <String>[
        'manifest',
        'print',
        apk.path,
      ]);
      if (manifest.exitCode == 0) {
        _evaluateAndroidManifestText(
          result,
          content: '${manifest.stdout}',
          location: 'apk:${p.basename(apk.path)}',
        );
      }
      await _scanApkDexReferences(result, analyzer, apk);
    }

    await _scanApkBinaryStrings(result, apk);
  }

  Future<void> _scanApkDexReferences(
    PrivacyAuditResult result,
    String analyzer,
    File apk,
  ) async {
    final dexPackages = await Process.run(analyzer, <String>[
      'dex',
      'packages',
      apk.path,
    ]);
    if (dexPackages.exitCode != 0) {
      result.addFinding(
        AuditFinding(
          ruleId: 'apk_dex_reference_scan_failed',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.review
              : AuditSeverity.info,
          title: 'APK DEX 引用解析失败',
          detail: _shorten('${dexPackages.stderr}'),
          location: apk.path,
          remediation: '确认 apkanalyzer 与当前 APK/Android Gradle Plugin 版本兼容。',
        ),
      );
      return;
    }

    final lines = '${dexPackages.stdout}'.split('\n');
    for (final rule in _config.sensitiveApis) {
      for (final expression in rule.dexPatterns) {
        final pattern = RegExp(expression);
        for (final line in lines) {
          if (!pattern.hasMatch(line)) continue;
          result.addFinding(
            AuditFinding(
              ruleId: 'apk_dex_${rule.id}',
              severity: rule.severity,
              title: 'APK DEX 引用了敏感 API：${rule.name}',
              detail:
                  'apkanalyzer 在类/方法引用中发现命中项。它比只搜索 getDeviceId 字符串更精确，可避免把 MotionEvent.getDeviceId 误判成 IMEI。',
              location: 'apk:${p.basename(apk.path)}/classes.dex',
              evidence: _shorten(line),
              remediation: rule.remediation,
            ),
          );
        }
      }
    }
  }

  Future<String?> _findApkAnalyzer() async {
    final executable = Platform.isWindows ? 'apkanalyzer.bat' : 'apkanalyzer';
    final candidates = <String>[executable];
    final sdkRoots = <String>{};
    for (final variable in <String>['ANDROID_SDK_ROOT', 'ANDROID_HOME']) {
      final sdk = Platform.environment[variable];
      if (sdk != null && sdk.isNotEmpty) sdkRoots.add(sdk);
    }
    // Android Studio 经常只把 SDK 位置写到 local.properties，而不设置环境变量。
    final localProperties = File(
      p.join(options.rootDirectory.path, 'android', 'local.properties'),
    );
    if (localProperties.existsSync()) {
      for (final line in localProperties.readAsLinesSync()) {
        if (!line.startsWith('sdk.dir=')) continue;
        sdkRoots.add(
          line
              .substring('sdk.dir='.length)
              .replaceAll(r'\:', ':')
              .replaceAll(r'\\', r'\'),
        );
      }
    }

    for (final sdk in sdkRoots) {
      candidates.addAll(<String>[
        p.join(sdk, 'cmdline-tools', 'latest', 'bin', executable),
        p.join(sdk, 'tools', 'bin', executable),
      ]);
      // SDK 目录也可能只有 19.0、18.1 等版本号，没有 latest 软链接。
      final commandLineTools = Directory(p.join(sdk, 'cmdline-tools'));
      if (commandLineTools.existsSync()) {
        for (final entity in commandLineTools.listSync(followLinks: false)) {
          if (entity is Directory) {
            candidates.add(p.join(entity.path, 'bin', executable));
          }
        }
      }
    }
    for (final candidate in candidates.toSet()) {
      try {
        final process = await Process.run(candidate, const <String>[
          '--version',
        ]);
        if (process.exitCode == 0) return candidate;
      } on ProcessException {
        // 尝试下一个标准位置；全部失败后由调用方生成一条明确报告。
      }
    }
    return null;
  }

  Future<void> _scanApkBinaryStrings(
    PrivacyAuditResult result,
    File apk,
  ) async {
    ProcessResult entries;
    try {
      entries = await Process.run('unzip', <String>['-Z1', apk.path]);
    } on ProcessException {
      result.addFinding(
        AuditFinding(
          ruleId: 'apk_binary_scan_unavailable',
          severity: options.mode == AuditMode.release
              ? AuditSeverity.review
              : AuditSeverity.info,
          title: '无法扫描 APK 二进制字符串',
          detail: '开发机没有 unzip，无法读取 classes.dex 和 native so。',
          location: apk.path,
          remediation: '安装 unzip，或在 CI/Linux 环境执行 Release APK 审计。',
        ),
      );
      return;
    }
    if (entries.exitCode != 0) return;

    final targets = '${entries.stdout}'
        .split('\n')
        .where(
          (entry) =>
              RegExp(r'^classes\d*\.dex$').hasMatch(entry) ||
              (entry.startsWith('lib/') && entry.endsWith('.so')),
        )
        .toList();

    final patternsByFirstByte = <int, List<_BinaryApiPattern>>{};
    for (final rule in _config.sensitiveApis) {
      for (final normalized in rule.binaryPatterns) {
        if (normalized.length < 5) continue;
        final patternBytes = utf8.encode(normalized);
        patternsByFirstByte
            .putIfAbsent(patternBytes.first, () => <_BinaryApiPattern>[])
            .add(
              _BinaryApiPattern(
                rule: rule,
                text: normalized,
                bytes: patternBytes,
              ),
            );
      }
    }

    for (final entry in targets) {
      final extracted = await Process.run('unzip', <String>[
        '-p',
        apk.path,
        entry,
      ], stdoutEncoding: null);
      if (extracted.exitCode != 0 || extracted.stdout is! List<int>) continue;
      final bytes = extracted.stdout as List<int>;
      final found = <String>{};
      // 二进制只完整遍历一次，再根据当前字节缩小候选规则；这样即使 Debug APK
      // 带有很大的 Flutter so，也不会为每一个敏感 API 重复扫描整份文件。
      for (var index = 0; index < bytes.length; index++) {
        final candidates = patternsByFirstByte[bytes[index]];
        if (candidates == null) continue;
        for (final candidate in candidates) {
          final key = '${candidate.rule.id}|${candidate.text}';
          if (found.contains(key) ||
              !_matchesBytesAt(bytes, candidate.bytes, index)) {
            continue;
          }
          found.add(key);
          result.addFinding(
            AuditFinding(
              ruleId: 'apk_${candidate.rule.id}',
              severity: candidate.rule.severity,
              title: 'APK 二进制包含敏感 API 信号：${candidate.rule.name}',
              detail:
                  '最终安装包的 $entry 包含 ${candidate.text}。这里只能证明代码被打包，是否执行仍需动态审计。',
              location: 'apk:${p.basename(apk.path)}/$entry',
              evidence: candidate.text,
              remediation: candidate.rule.remediation,
            ),
          );
        }
      }
    }
  }

  String _absoluteFromRoot(String value) =>
      p.isAbsolute(value) ? value : p.join(options.rootDirectory.path, value);
}

bool _containsAny(String content, List<String> markers) {
  return markers.any((marker) => marker.isNotEmpty && content.contains(marker));
}

bool _isCommentOnlyLine(String line) {
  final value = line.trimLeft();
  return value.startsWith('//') ||
      value.startsWith('///') ||
      value.startsWith('/*') ||
      value.startsWith('*') ||
      value.startsWith('<!--') ||
      value.startsWith('#');
}

/// 去掉 C/Dart 风格块注释并保留原行数，保证报告行号仍然指向真实源文件。
///
/// 只判断 `//` 开头会把块注释中用于讲解 Android ID 的文字误认为真实调用；
/// 这里不做完整编译器词法分析，但覆盖项目与常见插件源码的注释写法。
List<String> _stripBlockComments(List<String> lines) {
  var insideBlock = false;
  final output = <String>[];
  for (final line in lines) {
    var cursor = 0;
    final visible = StringBuffer();
    while (cursor < line.length) {
      if (insideBlock) {
        final end = line.indexOf('*/', cursor);
        if (end == -1) {
          cursor = line.length;
          continue;
        }
        insideBlock = false;
        cursor = end + 2;
        continue;
      }
      final start = line.indexOf('/*', cursor);
      if (start == -1) {
        visible.write(line.substring(cursor));
        break;
      }
      visible.write(line.substring(cursor, start));
      insideBlock = true;
      cursor = start + 2;
    }
    output.add(visible.toString());
  }
  return output;
}

String _shorten(String value, [int maximum = 220]) {
  final singleLine = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (singleLine.length <= maximum) return singleLine;
  return '${singleLine.substring(0, maximum - 1)}…';
}

final class _BinaryApiPattern {
  const _BinaryApiPattern({
    required this.rule,
    required this.text,
    required this.bytes,
  });

  final _SensitiveApiRule rule;
  final String text;
  final List<int> bytes;
}

bool _matchesBytesAt(List<int> haystack, List<int> needle, int start) {
  if (needle.isEmpty || start + needle.length > haystack.length) return false;
  for (var offset = 0; offset < needle.length; offset++) {
    if (haystack[start + offset] != needle[offset]) return false;
  }
  return true;
}

Future<void> _writeReports(
  PrivacyAuditOptions options,
  PrivacyAuditResult result,
) async {
  final jsonFile = File(
    p.join(options.rootDirectory.path, options.jsonReportPath),
  );
  final markdownFile = File(
    p.join(options.rootDirectory.path, options.markdownReportPath),
  );
  await jsonFile.parent.create(recursive: true);
  await markdownFile.parent.create(recursive: true);
  await jsonFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(result.toJson())}\n',
  );
  await markdownFile.writeAsString(_buildMarkdownReport(result));
}

String _buildMarkdownReport(PrivacyAuditResult result) {
  final buffer = StringBuffer()
    ..writeln('# 隐私合规自检报告')
    ..writeln()
    ..writeln('- 模式：`${result.mode.name}`')
    ..writeln('- 时间：`${result.startedAt.toLocal().toIso8601String()}`')
    ..writeln('- 扫描文件：`${result.filesScanned}`')
    ..writeln('- 阻断：`${result.count(AuditSeverity.blocker)}`')
    ..writeln('- 待确认：`${result.count(AuditSeverity.review)}`')
    ..writeln('- 信息：`${result.count(AuditSeverity.info)}`')
    ..writeln()
    ..writeln('> 本报告是研发侧风险线索，不是应用市场检测或法律合规结论。')
    ..writeln()
    ..writeln('## 问题清单')
    ..writeln();

  if (result.findings.isEmpty) {
    buffer.writeln('没有发现命中项。');
  } else {
    for (final finding in result.findings) {
      buffer
        ..writeln('### [${finding.severity.label}] ${finding.title}')
        ..writeln()
        ..writeln('- 规则：`${finding.ruleId}`')
        ..writeln('- 位置：`${finding.location}`')
        ..writeln('- 说明：${finding.detail}');
      if (finding.evidence != null && finding.evidence!.isNotEmpty) {
        buffer.writeln('- 证据：`${finding.evidence!.replaceAll('`', '\\`')}`');
      }
      if (finding.approvedReason != null) {
        buffer.writeln('- 登记理由：${finding.approvedReason}');
      }
      buffer
        ..writeln('- 建议：${finding.remediation}')
        ..writeln();
    }
  }

  buffer
    ..writeln('## Android 权限清单')
    ..writeln();
  if (result.permissions.isEmpty) {
    buffer.writeln('未解析到 Android 权限。');
  } else {
    final permissions = result.permissions.keys.toList()..sort();
    for (final permission in permissions) {
      final origins = result.permissions[permission]!.toList()..sort();
      buffer.writeln('- `$permission`：${origins.join('、')}');
    }
  }

  buffer
    ..writeln()
    ..writeln('## Android 原生插件清单')
    ..writeln();
  if (result.plugins.isEmpty) {
    buffer.writeln('未解析到 Android 原生插件。');
  } else {
    for (final plugin in result.plugins) {
      buffer.writeln('- `${plugin.name} ${plugin.version}`');
    }
  }

  buffer
    ..writeln()
    ..writeln('## 运行期域名清单')
    ..writeln();
  if (result.domains.isEmpty) {
    buffer.writeln('未解析到运行期 URL。');
  } else {
    final domains = result.domains.keys.toList()..sort();
    for (final domain in domains) {
      final origins = result.domains[domain]!.toList()..sort();
      buffer.writeln('- `$domain`：${origins.join('、')}');
    }
  }
  return buffer.toString();
}

PrivacyAuditOptions _parseArguments(List<String> arguments) {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write(_usage);
    exit(0);
  }

  const valueArguments = <String>{
    '--mode',
    '--apk',
    '--environment-file',
    '--config',
    '--report',
    '--json-report',
    '--fail-on',
    '--root',
  };
  for (var index = 0; index < arguments.length; index += 2) {
    final argument = arguments[index];
    if (!valueArguments.contains(argument)) {
      throw FormatException('未知参数：$argument。使用 --help 查看支持的参数。');
    }
    if (index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw FormatException('$argument 后必须提供值');
    }
  }

  String valueOf(String name, String fallback) {
    final index = arguments.indexOf(name);
    if (index == -1) return fallback;
    if (index + 1 >= arguments.length ||
        arguments[index + 1].startsWith('--')) {
      throw FormatException('$name 后必须提供值');
    }
    return arguments[index + 1];
  }

  final modeName = valueOf('--mode', AuditMode.development.name);
  final mode = AuditMode.values.firstWhere(
    (candidate) => candidate.name == modeName,
    orElse: () => throw FormatException('--mode 只支持 development 或 release'),
  );
  final failOnName = valueOf('--fail-on', AuditSeverity.blocker.name);
  final failOn = failOnName == 'none' ? null : AuditSeverity.parse(failOnName);
  final root = Directory(p.absolute(valueOf('--root', Directory.current.path)));
  final apkIndex = arguments.indexOf('--apk');
  final apk = apkIndex == -1 ? null : valueOf('--apk', '');
  final environmentIndex = arguments.indexOf('--environment-file');
  final environmentFile = environmentIndex == -1
      ? null
      : valueOf('--environment-file', '');

  return PrivacyAuditOptions(
    rootDirectory: root,
    mode: mode,
    configPath: valueOf('--config', p.join('compliance', 'privacy_audit.json')),
    markdownReportPath: valueOf(
      '--report',
      p.join('build', 'reports', 'privacy-audit.md'),
    ),
    jsonReportPath: valueOf(
      '--json-report',
      p.join('build', 'reports', 'privacy-audit.json'),
    ),
    failOn: failOn,
    apkPath: apk,
    environmentFilePath: environmentFile,
  );
}

const _usage = '''
隐私合规研发自检

用法：
  dart run tool/privacy/privacy_audit.dart [参数]

参数：
  --mode development|release   日常开发或提审前严格模式
  --apk <path>                 可选；扫描已构建 APK 的合并权限和二进制信号
  --environment-file <path>    本次构建使用的 dart-define JSON；release 模式必填
  --config <path>              规则配置，默认 compliance/privacy_audit.json
  --report <path>              Markdown 报告路径
  --json-report <path>         JSON 报告路径
  --fail-on blocker|review|info|none
                               达到该等级时返回非零，默认 blocker
  --root <path>                项目根目录，默认当前目录
  -h, --help                   查看帮助
''';

Future<void> main(List<String> arguments) async {
  try {
    final options = _parseArguments(arguments);
    final result = await PrivacyAuditor(options).run();
    await _writeReports(options, result);

    stdout
      ..writeln('隐私审计完成：${result.mode.name}')
      ..writeln(
        '阻断 ${result.count(AuditSeverity.blocker)} / '
        '待确认 ${result.count(AuditSeverity.review)} / '
        '信息 ${result.count(AuditSeverity.info)}',
      )
      ..writeln('Markdown：${options.markdownReportPath}')
      ..writeln('JSON：${options.jsonReportPath}');

    if (result.shouldFail(options.failOn)) {
      stderr.writeln('隐私审计未通过：存在达到 --fail-on 阈值的问题：');
      final threshold = options.failOn!;
      for (final finding in result.findings.where(
        (finding) => finding.severity.rank >= threshold.rank,
      )) {
        stderr.writeln(
          '- [${finding.severity.label}] ${finding.title} '
          '(${finding.location})',
        );
      }
      exitCode = 1;
    }
  } on Object catch (error, stackTrace) {
    stderr
      ..writeln('隐私审计无法执行：$error')
      ..writeln(stackTrace);
    exitCode = 64;
  }
}
