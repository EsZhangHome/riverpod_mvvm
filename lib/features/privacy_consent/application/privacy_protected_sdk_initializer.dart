import '../model/privacy_consent_state.dart';

/// 读取当前 App 级隐私状态的函数。
///
/// 项目在 Provider 中通常传 `() => ref.read(privacyConsentProvider)`；使用函数而不是
/// 保存某次 State 快照，确保真正初始化前再次核对最新授权版本。
typedef ReadPrivacyConsentState = PrivacyConsentState Function();

/// 只能由 [PrivacyProtectedSdkInitializer] 创建的授权凭据。
///
/// 构造函数私有，项目的 SDK Adapter 无法自己伪造一份“已同意”。Adapter 只能在
/// Riverpod 状态确认当前授权版本有效后收到该对象。若 Adapter 最终调用 Android
/// MethodChannel 或 iOS 原生桥，必须把 [consentVersion] 传到原生侧，由原生实现再次
/// 与当前构建要求的版本比较，然后才调用厂商 SDK initialize；这就是第二层门禁。
final class PrivacyConsentProof {
  const PrivacyConsentProof._({
    required this.consentVersion,
    required this.privacyDocumentVersion,
    required this.userAgreementDocumentVersion,
    required this.acceptedAtUtc,
  });

  /// 决定当前授权是否仍有效的版本。
  final String consentVersion;

  /// 用户同意时对应的隐私政策正文版本。
  final String privacyDocumentVersion;

  /// 用户同意时对应的用户协议正文版本。
  final String userAgreementDocumentVersion;

  /// 同意时间。旧版本迁移记录可能没有可靠时间，因此允许为 null。
  final DateTime? acceptedAtUtc;
}

/// 需要隐私授权才能初始化的 SDK 适配端口。
///
/// 每个真实 SDK 各自实现这个接口，例如 UmengSdkAdapter、BuglySdkAdapter。业务层只
/// 依赖本接口，不直接 import 厂商包。原生 SDK 的实现应在 initializeWithConsent 内
/// 完成“原生侧校验版本 → 初始化 SDK”，不能把厂商自动初始化留在 Application、
/// ContentProvider 或 AppDelegate 中绕过本入口。
abstract interface class PrivacyProtectedSdkAdapter {
  Future<void> initializeWithConsent(PrivacyConsentProof proof);
}

/// 为单个第三方 SDK 提供“授权检查 + 并发幂等”的初始化器。
///
/// App 层仍负责决定初始化时机：首帧后的 SDK 注册成 AppWarmupTask，功能专用 SDK
/// 放在对应 Provider 第一次使用时初始化。本类只保证无论从哪个时机调用：
/// - 当前授权版本无效时不会触碰 SDK Adapter；
/// - 并发或重复调用只初始化一次；
/// - Adapter 抛错时不伪装成功，AppWarmup 会把异常记录为非致命 issue，之后仍可重试。
///
/// 一个实例只对应一个 SDK，并应由非 autoDispose Provider 在 App 生命周期内持有。
final class PrivacyProtectedSdkInitializer {
  PrivacyProtectedSdkInitializer({
    required this.readConsentState,
    required this.adapter,
  });

  /// 每次准备初始化时读取最新隐私状态的函数。
  final ReadPrivacyConsentState readConsentState;

  /// 当前初始化器唯一负责的 SDK 适配器。
  final PrivacyProtectedSdkAdapter adapter;

  Future<bool>? _runningInitialization;
  bool _isInitialized = false;

  /// 当前进程内是否已经成功初始化。
  bool get isInitialized => _isInitialized;

  /// 仅在已经同意当前授权版本时初始化 SDK。
  ///
  /// 返回值：
  /// - true：本次完成初始化，或者此前已经初始化成功；
  /// - false：当前版本尚未同意，Adapter 完全没有被调用；
  /// - 抛出异常：Adapter 初始化失败，调用方应交给 Warmup/统一异常链处理。
  Future<bool> initializeIfAllowed() {
    // 在真正调用 Adapter 的同一时刻读取最新状态，不能使用注册 Warmup 时捕获的旧值。
    // 即使 SDK 过去已经初始化，也先重新核对：撤回或政策升级后必须返回 false，不能
    // 用“物理上已经启动过”冒充“现在仍允许采集”。停止已启动 SDK 仍由项目 Adapter
    // 按厂商能力处理。
    final state = readConsentState();
    final record = state.acceptedRecord;
    if (!state.hasAcceptedCurrentPolicy ||
        record == null ||
        record.consentVersion != state.policy.version) {
      return Future<bool>.value(false);
    }
    if (_isInitialized) return Future<bool>.value(true);
    final running = _runningInitialization;
    if (running != null) return running;

    final proof = PrivacyConsentProof._(
      consentVersion: record.consentVersion,
      privacyDocumentVersion: record.documentVersion,
      userAgreementDocumentVersion: record.userAgreementDocumentVersion,
      acceptedAtUtc: record.acceptedAtUtc,
    );
    late final Future<bool> operation;
    operation = _initialize(proof).whenComplete(() {
      // 只清理属于本次操作的引用。未来即使扩展重试，也不会让旧 Future 清掉新任务。
      if (identical(_runningInitialization, operation)) {
        _runningInitialization = null;
      }
    });
    _runningInitialization = operation;
    return operation;
  }

  Future<bool> _initialize(PrivacyConsentProof proof) async {
    await adapter.initializeWithConsent(proof);
    _isInitialized = true;
    return true;
  }
}
