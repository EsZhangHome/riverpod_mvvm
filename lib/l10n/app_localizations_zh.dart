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
  String get login => '登录';

  @override
  String get account => '手机号/邮箱';

  @override
  String get password => '密码';

  @override
  String get enterAccount => '请输入手机号或邮箱';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get backHome => '返回首页';

  @override
  String get noData => '暂无数据';

  @override
  String get pageNotFound => '页面不存在';

  @override
  String get requestTimeout => '请求超时，请稍后重试';

  @override
  String get requestCanceled => '请求已取消';

  @override
  String get networkError => '网络连接异常';

  @override
  String get unknownError => '未知错误，请稍后重试';

  @override
  String get serverError => '服务器异常，请稍后重试';

  @override
  String get requestFailed => '请求失败，请稍后重试';

  @override
  String get sessionExpired => '登录状态已失效，请重新登录';

  @override
  String get permissionDenied => '暂无权限执行此操作';

  @override
  String get validationFailed => '提交内容校验失败';

  @override
  String get storageError => '本地数据处理失败';

  @override
  String get protocolError => '服务响应格式异常';

  @override
  String get networkDisconnected => '当前网络不可用，请检查网络设置';

  @override
  String get networkRestored => '网络连接已恢复';
}
