// 模块依赖护栏：把 README 中的边界约定变成自动化测试。
//
// app     -> 可以组装所有层，但访问 feature 必须经过公开入口；
// feature -> 可以依赖 core/shared，跨业务必须经过目标模块公开入口；
// shared  -> 只能依赖 core/shared；
// core    -> 只能依赖 core；
// feature 之间不能形成循环依赖。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

enum _Layer { app, core, shared, feature }

class _Module {
  const _Module(this.layer, [this.feature]);

  final _Layer layer;
  final String? feature;
}

class _LocalDependency {
  const _LocalDependency({required this.source, required this.target});

  final String source;
  final String target;
}

void main() {
  test('lib 中的本地依赖遵守模块边界且 feature 无环', () {
    final projectRoot = Directory.current.absolute.path;
    final libRoot = p.join(projectRoot, 'lib');
    final packageName = _readPackageName(projectRoot);
    final dependencies = _scanDependencies(libRoot, packageName);
    final violations = <String>[];

    for (final dependency in dependencies) {
      final sourceModule = _moduleOf(dependency.source, libRoot);
      final targetModule = _moduleOf(dependency.target, libRoot);
      final reason = _violationReason(
        source: sourceModule,
        target: targetModule,
        targetPath: dependency.target,
        libRoot: libRoot,
      );
      if (reason == null) continue;

      violations.add(
        '${p.relative(dependency.source, from: projectRoot)} -> '
        '${p.relative(dependency.target, from: projectRoot)}：$reason',
      );
    }

    violations.addAll(_findFeatureCycles(dependencies, libRoot));
    violations.addAll(
      _findMvvmLayerViolations(libRoot, projectRoot, packageName),
    );
    expect(violations, isEmpty, reason: '发现模块依赖越界：\n${violations.join('\n')}');
  });
}

/// 检查 feature 内部的 MVVM 方向，以及 UI/状态层是否绕过 Repository 直接接触
/// Dio、SQLite 或存储插件。模块边界正确并不代表分层一定正确，因此单独做这一层检查。
List<String> _findMvvmLayerViolations(
  String libRoot,
  String projectRoot,
  String packageName,
) {
  const forbiddenInfrastructurePackages = [
    'package:dio/',
    'package:sqflite/',
    'package:shared_preferences/',
    'package:flutter_secure_storage/',
  ];
  final violations = <String>[];
  final directivePattern = RegExp(
    r"^(?:import|export)\s+'([^']+)'",
    multiLine: true,
  );

  for (final entity in Directory(
    p.join(libRoot, 'features'),
  ).listSync(recursive: true)) {
    if (entity is! File ||
        !entity.path.endsWith('.dart') ||
        entity.path.endsWith('.g.dart')) {
      continue;
    }
    final source = p.normalize(entity.absolute.path);
    final sourceRole = _featureRole(source, libRoot);
    if (sourceRole == null) continue;

    for (final match in directivePattern.allMatches(
      entity.readAsStringSync(),
    )) {
      final uri = match.group(1)!;
      final target = _resolveLocalUri(uri, source, libRoot, packageName);
      final targetRole = target == null ? null : _featureRole(target, libRoot);
      String? reason;

      if (sourceRole == 'model' &&
          const {'repository', 'view_model', 'view'}.contains(targetRole)) {
        reason = 'Model 不能反向依赖 Repository、ViewModel 或 View';
      } else if (sourceRole == 'repository' &&
          const {'view_model', 'view'}.contains(targetRole)) {
        reason = 'Repository 不能反向依赖 ViewModel 或 View';
      } else if (sourceRole == 'view_model' && targetRole == 'view') {
        reason = 'ViewModel 不能依赖 View';
      } else if (sourceRole == 'view' && targetRole == 'repository') {
        reason = 'View 应通过 ViewModel 发命令，不能直接调用 Repository';
      } else if ((sourceRole == 'view' || sourceRole == 'view_model') &&
          (forbiddenInfrastructurePackages.any(uri.startsWith) ||
              _isInfrastructureTarget(target, libRoot))) {
        reason = 'View/ViewModel 不能绕过 Repository 直接依赖网络、数据库或存储';
      } else if (sourceRole == 'repository' &&
          (uri == 'package:flutter/material.dart' ||
              uri == 'package:flutter/widgets.dart')) {
        reason = 'Repository 不能依赖 Flutter UI';
      }

      if (reason != null) {
        violations.add(
          '${p.relative(source, from: projectRoot)} -> $uri：$reason',
        );
      }
    }
  }
  return violations..sort();
}

String? _featureRole(String filePath, String libRoot) {
  final segments = p.split(p.relative(filePath, from: libRoot));
  if (segments.length < 4 || segments.first != 'features') return null;
  const roles = {'model', 'repository', 'view_model', 'view'};
  return roles.contains(segments[2]) ? segments[2] : null;
}

bool _isInfrastructureTarget(String? target, String libRoot) {
  if (target == null) return false;
  final relative = p.split(p.relative(target, from: libRoot));
  if (relative.length < 2 || relative.first != 'core') return false;
  return const {'network', 'database', 'storage'}.contains(relative[1]);
}

String _readPackageName(String projectRoot) {
  final pubspec = File(p.join(projectRoot, 'pubspec.yaml')).readAsStringSync();
  final match = RegExp(
    r'^name:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) throw StateError('pubspec.yaml 缺少 name');
  return match.group(1)!;
}

List<_LocalDependency> _scanDependencies(String libRoot, String packageName) {
  final dependencies = <_LocalDependency>[];
  final directivePattern = RegExp(
    r"^(?:import|export)\s+'([^']+)'",
    multiLine: true,
  );

  for (final entity in Directory(libRoot).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart')) continue;

    final sourcePath = p.normalize(entity.absolute.path);
    for (final match in directivePattern.allMatches(
      entity.readAsStringSync(),
    )) {
      final targetPath = _resolveLocalUri(
        match.group(1)!,
        sourcePath,
        libRoot,
        packageName,
      );
      if (targetPath != null) {
        dependencies.add(
          _LocalDependency(source: sourcePath, target: targetPath),
        );
      }
    }
  }
  return dependencies;
}

String? _resolveLocalUri(
  String uri,
  String sourcePath,
  String libRoot,
  String packageName,
) {
  final packagePrefix = 'package:$packageName/';
  if (uri.startsWith(packagePrefix)) {
    return p.normalize(p.join(libRoot, uri.substring(packagePrefix.length)));
  }
  if (uri.startsWith('.')) {
    return p.normalize(p.join(p.dirname(sourcePath), uri));
  }
  return null;
}

_Module _moduleOf(String filePath, String libRoot) {
  final segments = p.split(p.relative(filePath, from: libRoot));
  if (segments.first == 'core') return const _Module(_Layer.core);
  if (segments.first == 'shared') return const _Module(_Layer.shared);
  if (segments.first == 'features' && segments.length > 1) {
    return _Module(_Layer.feature, segments[1]);
  }
  return const _Module(_Layer.app);
}

String? _violationReason({
  required _Module source,
  required _Module target,
  required String targetPath,
  required String libRoot,
}) {
  switch (source.layer) {
    case _Layer.core:
      if (target.layer != _Layer.core) return 'core 只能依赖 core';
      return null;
    case _Layer.shared:
      if (target.layer == _Layer.app || target.layer == _Layer.feature) {
        return 'shared 不能依赖 app 或 feature';
      }
      return null;
    case _Layer.feature:
      if (target.layer == _Layer.app) return 'feature 不能依赖 app';
      if (target.layer == _Layer.feature &&
          _featureKey(source) != _featureKey(target)) {
        final publicEntry = _featureEntry(libRoot, target);
        if (targetPath != publicEntry) return '跨业务依赖必须通过目标 feature 公共入口';
      }
      return null;
    case _Layer.app:
      if (target.layer == _Layer.feature &&
          targetPath != _featureEntry(libRoot, target)) {
        return 'app 必须通过 feature 公共入口组装页面';
      }
      return null;
  }
}

String _featureEntry(String libRoot, _Module module) => p.normalize(
  p.join(libRoot, 'features', module.feature, '${module.feature}.dart'),
);

List<String> _findFeatureCycles(
  List<_LocalDependency> dependencies,
  String libRoot,
) {
  final graph = <String, Set<String>>{};
  for (final dependency in dependencies) {
    final source = _moduleOf(dependency.source, libRoot);
    final target = _moduleOf(dependency.target, libRoot);
    if (source.layer != _Layer.feature || target.layer != _Layer.feature) {
      continue;
    }
    final sourceKey = _featureKey(source);
    final targetKey = _featureKey(target);
    if (sourceKey == targetKey) continue;
    graph.putIfAbsent(sourceKey, () => <String>{}).add(targetKey);
  }

  final visiting = <String>{};
  final visited = <String>{};
  final path = <String>[];
  final cycles = <String>{};

  void visit(String feature) {
    if (visited.contains(feature)) return;
    if (!visiting.add(feature)) {
      final start = path.indexOf(feature);
      final cycle = [...path.sublist(start), feature].join(' -> ');
      cycles.add('feature 存在循环依赖：$cycle');
      return;
    }
    path.add(feature);
    for (final target in graph[feature] ?? const <String>{}) {
      visit(target);
    }
    path.removeLast();
    visiting.remove(feature);
    visited.add(feature);
  }

  for (final feature in graph.keys) {
    visit(feature);
  }
  return cycles.toList()..sort();
}

String _featureKey(_Module module) => module.feature!;
