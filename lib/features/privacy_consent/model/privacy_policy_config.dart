/// 当前构建使用的隐私政策配置。
///
/// 它只保存公开 URL 和版本号，不包含用户是否同意。把“当前政策是什么”和“某个
/// 用户是否同意”拆开后，配置可以独立注入，测试也不需要修改真实环境文件。
final class PrivacyPolicyConfig {
  const PrivacyPolicyConfig({
    required this.version,
    String? documentVersion,
    required this.url,
    String? userAgreementDocumentVersion,
    String? userAgreementUrl,
  }) : documentVersion = documentVersion ?? version,
       userAgreementDocumentVersion =
           userAgreementDocumentVersion ?? documentVersion ?? version,
       userAgreementUrl = userAgreementUrl ?? url,
       assert(version != ''),
       assert(documentVersion == null || documentVersion != ''),
       assert(url != ''),
       assert(
         userAgreementDocumentVersion == null ||
             userAgreementDocumentVersion != '',
       ),
       assert(userAgreementUrl == null || userAgreementUrl != '');

  /// 需要重新征得用户同意的授权版本，例如 `consent-2`。
  ///
  /// 为兼容已有项目继续叫 version。只有数据处理目的、范围或共享对象发生实质变化
  /// 时才升级；普通文案修订只修改 [documentVersion]。
  final String version;

  /// 当前完整政策文档版本，例如 `2026.07.01`。
  final String documentVersion;

  /// 用户可以阅读的完整政策地址。正式构建的 HTTPS/占位校验由 EnvConfig 完成。
  final String url;

  /// 用户本次同意的用户协议正文版本。
  ///
  /// 老项目未单独配置时回退到隐私政策文档版本，避免升级底座后立刻破坏现有构造；
  /// 正式项目仍应通过环境配置提供真实版本，便于日后追溯用户同意的两份正文。
  final String userAgreementDocumentVersion;

  /// 用户协议公开地址。未单独配置时兼容性回退到 [url]。
  final String userAgreementUrl;
}
