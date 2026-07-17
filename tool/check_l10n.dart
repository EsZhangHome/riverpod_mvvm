// 国际化遗漏检查工具。
//
// Flutter gen-l10n 会根据 l10n.yaml 把缺少翻译的 key 写入
// l10n_untranslated.json。本工具只读取该报告，不修改 ARB 或生成文件；报告包含任何
// 非空内容时返回失败，让本地检查和 CI 都能在合并前发现遗漏。

import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  final reportPath = arguments.isEmpty
      ? 'l10n_untranslated.json'
      : arguments.single;
  final report = File(reportPath);

  if (!report.existsSync()) {
    stderr.writeln(
      'Localization report not found: $reportPath\n'
      'Run `flutter gen-l10n` before this check.',
    );
    exitCode = 1;
    return;
  }

  late final Object? decoded;
  try {
    decoded = jsonDecode(report.readAsStringSync());
  } on FormatException catch (error) {
    stderr.writeln('Invalid localization report $reportPath: $error');
    exitCode = 1;
    return;
  }

  final missing = <String>[];
  _collectMissing(decoded, path: r'$', output: missing);
  if (missing.isEmpty) {
    stdout.writeln('Localization check passed: no missing translations.');
    return;
  }

  stderr.writeln('Localization check failed: missing translations found.');
  for (final item in missing.take(50)) {
    stderr.writeln('  - $item');
  }
  if (missing.length > 50) {
    stderr.writeln('  ... and ${missing.length - 50} more');
  }
  stderr.writeln(
    'Complete every locale in lib/l10n/*.arb, then run `flutter gen-l10n` again.',
  );
  exitCode = 1;
}

void _collectMissing(
  Object? value, {
  required String path,
  required List<String> output,
}) {
  if (value is Map<String, dynamic>) {
    for (final entry in value.entries) {
      _collectMissing(entry.value, path: '$path.${entry.key}', output: output);
    }
    return;
  }
  if (value is List<dynamic>) {
    for (var index = 0; index < value.length; index++) {
      _collectMissing(value[index], path: '$path[$index]', output: output);
    }
    return;
  }
  if (value != null) {
    output.add('$path = $value');
  }
}
