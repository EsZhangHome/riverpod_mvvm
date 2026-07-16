// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get initializationFailed => '应用初始化失败';

  @override
  String failedStages(String stages) {
    return '失败阶段：$stages';
  }

  @override
  String get retry => '重试';
}
