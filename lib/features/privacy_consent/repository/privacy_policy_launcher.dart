import 'package:url_launcher/url_launcher.dart';

/// 打开完整隐私政策的端口。
///
/// 返回 false 表示系统无法打开地址，View 会保留原弹窗并显示可理解的错误；异常同样
/// 由 View 捕获并转换，不能因为浏览器插件失败而关闭授权门禁。
abstract interface class PrivacyPolicyLauncher {
  Future<bool> open(Uri uri);
}

/// 使用系统默认浏览器打开 HTTPS 政策页。
///
/// 不先调用 canLaunchUrl：Android 11+ 的应用可见性可能使预检查返回 false，即使真正
/// launch 仍能成功。环境校验已经保证正式配置是合法 HTTPS 地址。
final class ExternalPrivacyPolicyLauncher implements PrivacyPolicyLauncher {
  const ExternalPrivacyPolicyLauncher();

  @override
  Future<bool> open(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
