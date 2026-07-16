import 'dart:convert';

/// 一次已经成功持久化的隐私同意记录。
///
/// 过去只保存一个版本字符串，只能回答“同意没同意”，无法说明用户同意的是哪份
/// 文档、发生在什么时间。本模型仍只保存合规审计真正需要的最小字段，不保存账号、
/// 设备标识等个人信息，避免为了证明同意反而扩大数据收集范围。
final class PrivacyConsentRecord {
  const PrivacyConsentRecord({
    required this.consentVersion,
    required this.documentVersion,
    required this.userAgreementDocumentVersion,
    required this.acceptedAtUtc,
  });

  /// 决定是否必须重新征得同意的“授权版本”。
  ///
  /// 只有处理目的、信息范围、共享对象等实质内容变化时才应升级。排版或错别字修改
  /// 只升级 [documentVersion]，否则每次小改动都弹窗会造成用户疲劳。
  final String consentVersion;

  /// 用户当时实际阅读的政策文档版本，可用于追溯具体正文。
  final String documentVersion;

  /// 用户当时实际阅读并同意的用户协议正文版本。
  final String userAgreementDocumentVersion;

  /// 同意时间，统一使用 UTC，避免跨时区设备产生歧义。
  ///
  /// 从旧版字符串记录迁移时没有可靠时间，因此允许为 null，不能用迁移时间伪造
  /// 用户当年的真实同意时间。
  final DateTime? acceptedAtUtc;

  Map<String, Object?> toJson() => <String, Object?>{
    'consentVersion': consentVersion,
    'documentVersion': documentVersion,
    'userAgreementDocumentVersion': userAgreementDocumentVersion,
    'acceptedAtUtc': acceptedAtUtc?.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  /// 尝试读取持久化 JSON。任何字段损坏都返回 null，由上层按“未同意”处理。
  ///
  /// 隐私门禁必须失败关闭（fail closed）：损坏记录不能被乐观解释成已授权。
  static PrivacyConsentRecord? tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return null;
      final consentVersion = decoded['consentVersion'];
      final documentVersion = decoded['documentVersion'];
      final rawUserAgreementVersion = decoded['userAgreementDocumentVersion'];
      final acceptedAt = decoded['acceptedAtUtc'];
      if (consentVersion is! String || consentVersion.trim().isEmpty) {
        return null;
      }
      if (documentVersion is! String || documentVersion.trim().isEmpty) {
        return null;
      }
      // 兼容已经发布过的 v1 JSON：旧记录只有隐私政策正文版本。缺少新字段时使用
      // 当时的隐私正文版本，不把一次安全的数据结构升级误判成用户从未同意。
      final userAgreementDocumentVersion =
          rawUserAgreementVersion ?? documentVersion;
      if (userAgreementDocumentVersion is! String ||
          userAgreementDocumentVersion.trim().isEmpty) {
        return null;
      }
      final acceptedAtUtc = acceptedAt is String && acceptedAt.isNotEmpty
          ? DateTime.tryParse(acceptedAt)?.toUtc()
          : null;
      if (acceptedAt is String &&
          acceptedAt.isNotEmpty &&
          acceptedAtUtc == null) {
        return null;
      }
      return PrivacyConsentRecord(
        consentVersion: consentVersion.trim(),
        documentVersion: documentVersion.trim(),
        userAgreementDocumentVersion: userAgreementDocumentVersion.trim(),
        acceptedAtUtc: acceptedAtUtc,
      );
    } on FormatException {
      return null;
    }
  }

  /// 把旧版单字符串记录转换成内存模型。
  ///
  /// 这只是兼容读取；用户下一次主动同意时会写入完整 v1 记录。
  factory PrivacyConsentRecord.fromLegacyVersion(String version) {
    final normalized = version.trim();
    return PrivacyConsentRecord(
      consentVersion: normalized,
      documentVersion: normalized,
      userAgreementDocumentVersion: normalized,
      acceptedAtUtc: null,
    );
  }
}
