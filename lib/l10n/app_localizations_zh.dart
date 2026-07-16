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

  @override
  String get networkDisconnected => '当前网络不可用，请检查网络设置';

  @override
  String get networkRestored => '网络连接已恢复';

  @override
  String get networkPoor => '当前网络较慢，正在尝试重新连接';

  @override
  String get networkQualityRestored => '网络状况已恢复';
}
