// 模块依赖护栏。
//
// 这不是业务测试，而是把 README 中的模块边界变成可执行规则：
// app       -> 可以组装所有层，但访问 feature 时必须经过公开入口；
// feature   -> 可以依赖 core/shared，跨业务只能经过 auth.dart；
// shared    -> 只能依赖 core；
// core      -> 不能反向依赖 app/shared/feature。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

enum _Layer { app, core, shared, feature }

class _Module {
  const _Module(this.layer, [this.feature]);

  final _Layer layer;
  final String? feature;
}

void main() {
  test('lib 中的本地依赖遵守模块边界', () {
    final projectRoot = Directory.current.absolute.path;
    final libRoot = p.join(projectRoot, 'lib');
    final violations = <String>[];
    final directivePattern = RegExp(
      r"^(?:import|export)\s+'([^']+)'",
      multiLine: true,
    );

    for (final entity in Directory(libRoot).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;

      final sourcePath = p.normalize(entity.absolute.path);
      final sourceModule = _moduleOf(sourcePath, libRoot);
      final sourceText = entity.readAsStringSync();

      for (final match in directivePattern.allMatches(sourceText)) {
        final uri = match.group(1)!;
        final targetPath = _resolveLocalUri(uri, sourcePath, libRoot);
        if (targetPath == null) continue;

        final targetModule = _moduleOf(targetPath, libRoot);
        final reason = _violationReason(
          source: sourceModule,
          target: targetModule,
          targetPath: targetPath,
          libRoot: libRoot,
        );
        if (reason == null) continue;

        violations.add(
          '${p.relative(sourcePath, from: projectRoot)} -> '
          '${p.relative(targetPath, from: projectRoot)}：$reason',
        );
      }
    }

    expect(violations, isEmpty, reason: '发现模块依赖越界：\n${violations.join('\n')}');
  });
}

String? _resolveLocalUri(String uri, String sourcePath, String libRoot) {
  const packagePrefix = 'package:riverpod_mvvm/';
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
      if (target.layer == _Layer.feature && source.feature != target.feature) {
        final authEntry = p.normalize(
          p.join(libRoot, 'features/auth/auth.dart'),
        );
        if (target.feature != 'auth' || targetPath != authEntry) {
          return '跨业务依赖只能通过 features/auth/auth.dart';
        }
      }
      return null;
    case _Layer.app:
      if (target.layer == _Layer.feature) {
        final publicEntry = p.normalize(
          p.join(libRoot, 'features', target.feature, '${target.feature}.dart'),
        );
        if (targetPath != publicEntry) return 'app 必须通过 feature 公共入口组装页面';
      }
      return null;
  }
}
