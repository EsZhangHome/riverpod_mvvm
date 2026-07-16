// CI 覆盖率门禁。只统计手写 Dart 文件，生成代码没有业务分支，不应稀释指标。

import 'dart:io';

/// 读取 lcov 报告并执行覆盖率门禁。
///
/// [arguments] 支持 `--minimum 55` 或 `--minimum=55`；不传时阈值为 55%。脚本只读
/// coverage/lcov.info，不会运行测试。报告不存在返回 64，没有手写行返回 65，低于
/// 阈值返回 1，满足要求保持 0。
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

/// 从 [arguments] 读取最小百分比，同时兼容空格与等号两种 CLI 写法。
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

/// 把 [value] 解析为 0～100 的百分比；无效值打印错误并立即退出。
double _parseMinimum(String value) {
  final parsed = double.tryParse(value);
  if (parsed == null || parsed < 0 || parsed > 100) {
    stderr.writeln('Invalid --minimum value: $value');
    exit(64);
  }
  return parsed;
}

/// 判断 lcov 中的 [source] 是否为不应计入业务覆盖率的生成代码路径。
bool _isGenerated(String source) {
  final normalized = source.replaceAll('\\', '/');
  return normalized.endsWith('.g.dart') ||
      normalized.contains('/lib/l10n/app_localizations');
}
