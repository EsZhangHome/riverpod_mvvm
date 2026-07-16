// 新项目初始化工具。
//
// 示例：
// dart run tool/bootstrap.dart \
//   --name acme_console \
//   --display-name "Acme Console" \
//   --organization com.acme \
//   --mode production

import 'dart:convert';
import 'dart:io';

/// 把当前底座初始化成一个有独立包名、显示名和平台标识的新项目。
///
/// 这是一次性脚本，不会在 App 运行时进入安装包。它使用 `dart:io` 直接修改文件，
/// 所以先用 `--dry-run` 查看影响范围，再在干净 Git 工作区正式执行最容易回退。
void main(List<String> arguments) {
  // 第一步：只负责解析和验证参数。参数无效时立即退出，尚未写任何文件。
  final options = _Options.parse(arguments);
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  final root = Directory.current.absolute;
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('请在 Flutter 项目根目录执行此命令。');
    exitCode = 64;
    return;
  }

  // 第二步：读取“旧身份”。替换必须以仓库当前值为准，不能假设它一直叫
  // riverpod_mvvm，否则模板改名后脚本会悄悄漏改 import。
  final pubspecText = pubspec.readAsStringSync();
  final oldName = RegExp(
    r'^name:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspecText)?.group(1);
  if (oldName == null) {
    stderr.writeln('无法读取 pubspec.yaml 中的项目名。');
    exitCode = 65;
    return;
  }

  final androidGradle = File('${root.path}/android/app/build.gradle.kts');
  final androidText = androidGradle.readAsStringSync();
  final oldApplicationId = RegExp(
    r'applicationId\s*=\s*"([^"]+)"',
  ).firstMatch(androidText)?.group(1);
  final iosProject = File('${root.path}/ios/Runner.xcodeproj/project.pbxproj');
  final oldIosBundleId = iosProject.existsSync()
      ? RegExp(
          r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
        ).firstMatch(iosProject.readAsStringSync())?.group(1)
      : null;
  final newApplicationId = '${options.organization}.${options.name}';

  // 第三步：准备只作用于根应用的替换规则。MapEntry 的 key 是旧文本，value 是
  // 新文本；后面的统一遍历会把 Dart、Android、iOS 中同一身份一起改掉。
  final replacements = <MapEntry<String, String>>[
    MapEntry('package:$oldName/', 'package:${options.name}/'),
    MapEntry('name: $oldName', 'name: ${options.name}'),
    MapEntry('$oldName.db', '${options.name}.db'),
    if (oldApplicationId != null) MapEntry(oldApplicationId, newApplicationId),
    if (oldIosBundleId != null) MapEntry(oldIosBundleId, newApplicationId),
  ];

  final changed = <String>[];
  // 只扫描根应用会拥有的源码和平台目录。生成产物、依赖缓存和 IDE 文件必须跳过，
  // 否则脚本会修改下一次构建本来就会重建的临时文件。
  for (final directory in ['lib', 'test', 'android', 'ios']) {
    final location = Directory('${root.path}/$directory');
    if (!location.existsSync()) continue;
    for (final entity in location.listSync(recursive: true)) {
      if (entity is! File ||
          _isGeneratedPath(entity.path) ||
          !_isTextFile(entity.path)) {
        continue;
      }
      var content = entity.readAsStringSync();
      final original = content;
      for (final replacement in replacements) {
        content = content.replaceAll(replacement.key, replacement.value);
      }
      content = _replaceDisplayName(content, entity.path, options.displayName);
      if (content == original) continue;
      changed.add(_relative(root.path, entity.path));
      if (!options.dryRun) entity.writeAsStringSync(content);
    }
  }

  // examples 下的独立应用可能通过 path dependency 消费当前底座。初始化工具
  // 不修改这些应用自己的包名、显示名或平台 applicationId，只同步两类“指向
  // 根包”的引用：package import 与 pubspec 依赖键。这样保留示例时仍能运行，
  // 删除整个 examples 目录时本逻辑也自然成为空操作。
  final examples = Directory('${root.path}/examples');
  if (examples.existsSync()) {
    final externalReferenceReplacements = <MapEntry<String, String>>[
      MapEntry('package:$oldName/', 'package:${options.name}/'),
      MapEntry('\n  $oldName:\n', '\n  ${options.name}:\n'),
    ];
    for (final entity in examples.listSync(recursive: true)) {
      if (entity is! File ||
          _isGeneratedPath(entity.path) ||
          !_isTextFile(entity.path)) {
        continue;
      }
      var content = entity.readAsStringSync();
      final original = content;
      for (final replacement in externalReferenceReplacements) {
        content = content.replaceAll(replacement.key, replacement.value);
      }
      if (content == original) continue;
      changed.add(_relative(root.path, entity.path));
      if (!options.dryRun) entity.writeAsStringSync(content);
    }
  }

  // pubspec 在上面的目录列表之外，因此单独修改包名和描述。
  var nextPubspec = pubspecText
      .replaceFirst(
        RegExp(r'^name:\s*[^\s#]+', multiLine: true),
        'name: ${options.name}',
      )
      .replaceFirst(
        RegExp(r'^description:.*$', multiLine: true),
        'description: ${options.displayName} enterprise Flutter application.',
      );
  if (nextPubspec != pubspecText) {
    changed.add('pubspec.yaml');
    if (!options.dryRun) pubspec.writeAsStringSync(nextPubspec);
  }

  if (oldApplicationId != null) {
    // Android Java 文件的目录就是 package 的一部分，只改文件内容还不够。
    _moveMainActivity(
      root: root,
      oldApplicationId: oldApplicationId,
      newApplicationId: newApplicationId,
      dryRun: options.dryRun,
      changed: changed,
    );
  }

  final localConfig = File('${root.path}/config/local.json');
  // local.json 被 Git 忽略，每个开发者可以有自己的 API 地址，不会误提交到仓库。
  changed.add('config/local.json');
  if (!options.dryRun) {
    localConfig.parent.createSync(recursive: true);
    localConfig.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(_localConfig(options))}\n',
    );
  }

  changed.sort();
  stdout.writeln(options.dryRun ? '预览完成，不写入文件：' : '项目初始化完成：');
  stdout.writeln('  package: ${options.name}');
  stdout.writeln('  display: ${options.displayName}');
  stdout.writeln('  app id : $newApplicationId');
  stdout.writeln('  mode   : ${options.mode}');
  stdout.writeln('  files  : ${changed.length}');
  stdout.writeln('下一步：检查 config/local.json 的 API 地址，然后执行 flutter pub get。');
}

String _replaceDisplayName(String content, String path, String displayName) {
  // 同一个“应用显示名”在 Android、iOS 和 Dart 默认配置中的写法不同，按文件
  // 类型分别处理。找不到目标节点时 replaceFirst 会保持原文，不会破坏文件。
  if (path.endsWith('AndroidManifest.xml')) {
    return content.replaceFirst(
      RegExp(r'android:label="[^"]*"'),
      'android:label="$displayName"',
    );
  }
  if (path.endsWith('Info.plist')) {
    return content
        .replaceFirstMapped(
          RegExp(
            r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)',
          ),
          (match) => '${match.group(1)}$displayName${match.group(2)}',
        )
        .replaceFirstMapped(
          RegExp(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)'),
          (match) => '${match.group(1)}$displayName${match.group(2)}',
        );
  }
  if (path.endsWith('/lib/core/config/env_config.dart')) {
    return content.replaceFirstMapped(
      RegExp(r"(ENV_APP_NAME'[\s\S]*?defaultValue: ')[^']*(')"),
      (match) => '${match.group(1)}$displayName${match.group(2)}',
    );
  }
  return content;
}

void _moveMainActivity({
  required Directory root,
  required String oldApplicationId,
  required String newApplicationId,
  required bool dryRun,
  required List<String> changed,
}) {
  // Flutter 模板可能生成 Java MainActivity。若项目已迁移 Kotlin 或自定义入口，
  // 旧文件不存在时直接跳过，由开发者按自己的平台结构处理。
  final javaRoot = '${root.path}/android/app/src/main/java';
  final oldDir = '$javaRoot/${oldApplicationId.replaceAll('.', '/')}';
  final newDir = '$javaRoot/${newApplicationId.replaceAll('.', '/')}';
  final oldFile = File('$oldDir/MainActivity.java');
  if (!oldFile.existsSync() || oldFile.path == '$newDir/MainActivity.java') {
    return;
  }
  changed.add('android/app/src/main/java/.../MainActivity.java (move)');
  if (dryRun) {
    return;
  }
  Directory(newDir).createSync(recursive: true);
  oldFile.renameSync('$newDir/MainActivity.java');
  _deleteEmptyParents(Directory(oldDir), Directory(javaRoot));
}

void _deleteEmptyParents(Directory directory, Directory stopAt) {
  // MainActivity 移走后，从最深 package 目录向上删除空目录，但绝不会删过
  // android/app/src/main/java 根目录。
  var current = directory;
  while (current.path != stopAt.path && current.existsSync()) {
    if (current.listSync().isNotEmpty) {
      return;
    }
    final parent = current.parent;
    current.deleteSync();
    current = parent;
  }
}

Map<String, Object> _localConfig(_Options options) {
  // production 故意写入 `.invalid` 地址：配置校验会阻止误发布，使用者必须明确
  // 换成真实 HTTPS 地址。development 默认开 Mock，克隆后无需后端也能启动。
  final production = options.mode == 'production';
  return {
    'ENV_NAME': production ? 'production' : 'development',
    'ENV_APP_NAME': options.displayName,
    'ENV_API_BASE_URL': production
        ? 'https://replace-with-production-api.invalid'
        : 'https://dev-api.example.com',
    'ENV_ENABLE_MOCK': !production,
    'ENV_IS_DEBUG': !production,
    'ENV_ENABLE_CHARLES_PROXY': false,
    'ENV_ALLOW_CHARLES_BAD_CERTIFICATE': false,
  };
}

/// 脚本允许做字符串替换的文本文件类型。
///
/// 图片、签名文件和其他二进制内容绝不能按 UTF-8 读取，否则可能损坏文件。
bool _isTextFile(String path) => const {
  '.dart',
  '.yaml',
  '.yml',
  '.json',
  '.kts',
  '.gradle',
  '.java',
  '.kt',
  '.xml',
  '.plist',
  '.pbxproj',
}.any(path.endsWith);

/// 初始化只修改源码和项目配置，不碰依赖缓存、构建产物或 IDE 索引。
///
/// 使用路径段判断而不是 `contains('build')`，避免误跳过名为 build_report.dart
/// 之类的真实源码。Windows 路径先统一成 `/`，脚本在 CI 上也保持相同行为。
bool _isGeneratedPath(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  const generatedDirectories = {
    '.dart_tool',
    '.git',
    '.gradle',
    '.idea',
    'build',
    'DerivedData',
    'Pods',
  };
  return segments.any(generatedDirectories.contains);
}

/// 把绝对路径转成最终报告里的仓库相对路径，输出更容易阅读。
String _relative(String root, String path) =>
    path.startsWith('$root/') ? path.substring(root.length + 1) : path;

/// 命令行参数的不可变结果。
///
/// 字段以下划线开头，是因为它只服务于本脚本，不属于 App 的公共 API。
class _Options {
  const _Options({
    required this.name,
    required this.displayName,
    required this.organization,
    required this.mode,
    required this.dryRun,
    required this.showHelp,
  });

  factory _Options.parse(List<String> arguments) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      return const _Options(
        name: '',
        displayName: '',
        organization: '',
        mode: '',
        dryRun: false,
        showHelp: true,
      );
    }

    String requireValue(String key) {
      // 所有必填参数统一使用同一条检查逻辑，避免某个参数忘记处理“只有 key 没值”。
      final index = arguments.indexOf(key);
      if (index < 0 || index + 1 >= arguments.length) {
        stderr.writeln('缺少参数 $key。\n$_usage');
        exit(64);
      }
      return arguments[index + 1];
    }

    final name = requireValue('--name');
    final displayName = requireValue('--display-name').trim();
    final organization = requireValue('--organization');
    final mode = arguments.contains('--mode')
        ? requireValue('--mode').toLowerCase()
        : 'development';

    // Dart 包名和移动端 applicationId 规则不同，必须分别验证。越早失败，越不会
    // 出现 Dart 已改名但 Android 改到一半的项目。
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(name)) {
      stderr.writeln('--name 必须是合法 Dart 包名，例如 acme_console。');
      exit(64);
    }
    if (displayName.isEmpty) {
      stderr.writeln('--display-name 不能为空。');
      exit(64);
    }
    if (!RegExp(
      r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$',
    ).hasMatch(organization)) {
      stderr.writeln('--organization 格式示例：com.acme。');
      exit(64);
    }
    if (mode != 'development' && mode != 'production') {
      stderr.writeln('--mode 只能是 development 或 production。');
      exit(64);
    }
    return _Options(
      name: name,
      displayName: displayName,
      organization: organization,
      mode: mode,
      dryRun: arguments.contains('--dry-run'),
      showHelp: false,
    );
  }

  final String name;
  final String displayName;
  final String organization;
  final String mode;
  final bool dryRun;
  final bool showHelp;
}

const _usage = '''
初始化企业 Flutter 项目：
  dart run tool/bootstrap.dart \\
    --name acme_console \\
    --display-name "Acme Console" \\
    --organization com.acme \\
    [--mode development|production] [--dry-run]
''';
