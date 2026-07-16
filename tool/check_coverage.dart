// CI 覆盖率门禁。只统计手写 Dart 文件，生成代码没有业务分支，不应稀释指标。

import 'dart:io';

void main(List<String> arguments) {
  final minimum = _minimumFrom(arguments);
  final report = File('coverage/lcov.info');
  if (!report.existsSync()) {
    stderr.writeln(
      'Missing coverage/lcov.info. Run flutter test --coverage first.',
    );
    exitCode = 64;
    return;
  }

  var found = 0;
  var hit = 0;
  var includeCurrentFile = false;
  for (final line in report.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      includeCurrentFile = !_isGenerated(line.substring(3));
      continue;
    }
    if (!includeCurrentFile || !line.startsWith('DA:')) continue;
    final fields = line.substring(3).split(',');
    if (fields.length < 2) continue;
    found++;
    if ((int.tryParse(fields[1]) ?? 0) > 0) hit++;
  }

  if (found == 0) {
    stderr.writeln('Coverage report contains no hand-written Dart lines.');
    exitCode = 65;
    return;
  }

  final percentage = hit * 100 / found;
  stdout.writeln(
    'Coverage: ${percentage.toStringAsFixed(2)}% ($hit/$found), '
    'minimum: ${minimum.toStringAsFixed(2)}%',
  );
  if (percentage < minimum) exitCode = 1;
}

double _minimumFrom(List<String> arguments) {
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument.startsWith('--minimum=')) {
      return _parseMinimum(argument.substring('--minimum='.length));
    }
    if (argument == '--minimum' && index + 1 < arguments.length) {
      return _parseMinimum(arguments[index + 1]);
    }
  }
  return 55;
}

double _parseMinimum(String value) {
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0 || parsed > 100) {
    stderr.writeln('Invalid --minimum value: $value');
    exit(64);
  }
  return parsed;
}

bool _isGenerated(String source) {
  final normalized = source.replaceAll('\\', '/');
  return normalized.endsWith('.g.dart') ||
      normalized.contains('/lib/l10n/app_localizations');
}
