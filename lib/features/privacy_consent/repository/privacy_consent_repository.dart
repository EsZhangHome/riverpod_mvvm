import '../../../core/storage/preferences_store.dart';
import '../model/privacy_consent_record.dart';

/// 隐私同意记录的存储端口。
///
/// Repository 只知道“同意记录”这一持久化事实，不知道页面、Riverpod 或 SDK
/// 初始化。这样 ViewModel 测试可以换成内存实现，未来迁移存储也不会修改 View。
abstract interface class PrivacyConsentRepository {
  /// 同步读取用户最后一次有效同意记录；没有记录或记录损坏时返回 null。
  PrivacyConsentRecord? readAcceptedPolicyRecord();

  /// 保存完整同意记录。true 才表示可以放行业务 App。
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record);

  /// 使同意记录失效。实现可以使用失败关闭墓碑，确保旧迁移记录不会重新放行。
  Future<bool> clearAcceptedPolicyVersion();
}

/// SharedPreferences 中隐私模块拥有的稳定 key。
///
/// shared_preferences Android 旧接口会给 Dart 逻辑 key 自动增加 `flutter.` 前缀。
/// 动态审计脚本因此读取 `flutter.privacy_consent_record_v1`，并从 JSON 中取得
/// consentVersion；修改 key 时必须同步更新 compliance 与 Frida 配置。
abstract final class PrivacyConsentStorageKeys {
  /// 当前结构化记录。单个 JSON 值避免多个字段分别写入造成半成功状态。
  static const acceptedRecordV1 = 'privacy_consent_record_v1';

  /// 旧版只保存授权版本的 key，仅用于兼容升级读取，新的同意不再写入这里。
  static const acceptedPolicyVersion = 'privacy_policy_accepted_version';
}

/// 使用底座普通偏好端口保存同意版本的默认实现。
///
/// 隐私同意版本不是 token 或身份证号，不需要安全存储；但写入失败必须视为未同意，
/// 不能先进入首页再“稍后补写”。
final class LocalPrivacyConsentRepository implements PrivacyConsentRepository {
  const LocalPrivacyConsentRepository(this._preferences);

  final PreferencesStore _preferences;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() {
    final encoded = _preferences.getString(
      PrivacyConsentStorageKeys.acceptedRecordV1,
    );
    if (encoded != null) {
      // 新记录存在但损坏时不能回退旧 key，否则已经被破坏或篡改的新记录可能借旧值
      // 绕过当前门禁。返回 null，让用户重新确认当前政策。
      return PrivacyConsentRecord.tryDecode(encoded);
    }

    final legacyVersion = _preferences.getString(
      PrivacyConsentStorageKeys.acceptedPolicyVersion,
    );
    if (legacyVersion == null || legacyVersion.trim().isEmpty) return null;
    return PrivacyConsentRecord.fromLegacyVersion(legacyVersion);
  }

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) {
    // 只有这一笔写入决定授权是否成功，避免“新记录成功、清理旧 key 失败”导致页面
    // 提示失败但下次启动又已授权。旧 key 即使保留也不会被读取或覆盖新事实。
    return _preferences.setString(
      PrivacyConsentStorageKeys.acceptedRecordV1,
      record.encode(),
    );
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    // 先写入“非有效记录”作为撤回墓碑，而不是先删新 key。读取逻辑只有在新 key
    // 不存在时才兼容旧版本；墓碑可以保证即使清理旧 key 失败，也绝不会回退旧同意
    // 而重新放行。下一次真正同意会用完整 JSON 原子覆盖它。
    final revoked = await _preferences.setString(
      PrivacyConsentStorageKeys.acceptedRecordV1,
      '{"revoked":true}',
    );
    if (!revoked) return false;
    try {
      await _preferences.remove(
        PrivacyConsentStorageKeys.acceptedPolicyVersion,
      );
    } catch (_) {
      // 墓碑已经使撤回生效；旧 key 清理失败不能把用户重新变成已同意。
    }
    return true;
  }
}
