// App 关键流程集成测试。
//
// 与 test/ 下的单元/Widget 测试相比，这里通过 IntegrationTestWidgetsFlutterBinding
// 驱动完整 MyApp，连续经过 LoginPage、LoginNotifier、SignInUseCase、
// LoginRepository、SessionActivator、AuthNotifier、SessionStore 和 GoRouter 守卫。
// 外部后端与设备安全存储仍使用可控的
// Fake，避免 CI 因测试账号、网络或系统钥匙串状态而随机失败；它验证的是底座各层能否
// 正确协作，不是某个真实后端环境是否在线。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:riverpod_mvvm/app/app.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/core/network/network_status_service.dart';
import 'package:riverpod_mvvm/core/network/request_cancellation.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/auth/login/login_providers.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_response.dart';
import 'package:riverpod_mvvm/features/auth/login/repository/login_repository.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';

const _homePath = '/integration-home';
const _protectedReportPath = '/integration-report';
const _policy = PrivacyPolicyConfig(
  version: 'integration-v1',
  url: 'https://example.test/privacy',
);

/// 内存会话仓库实现真实 SessionStore 契约，但不会访问 Keychain/Keystore。
/// 同一个实例可跨 ProviderContainer 保存状态，用来模拟 App 重启后的会话恢复。
final class _MemorySessionStore implements SessionStore {
  _MemorySessionStore([this.session]);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> write(AuthSession value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

/// 固定成功的登录仓库。测试仍然经过 Repository 抽象和取消令牌参数，只跳过外部
/// HTTP 服务，确保结果稳定且不会在 CI 中使用真实账号。
final class _SuccessfulLoginRepository implements LoginRepository {
  LoginRequest? receivedRequest;
  RequestCancellationToken? receivedCancelToken;

  @override
  Future<LoginResponse> login(
    LoginRequest request, {
    RequestCancellationToken? cancelToken,
  }) async {
    receivedRequest = request;
    receivedCancelToken = cancelToken;
    return const LoginResponse(
      token: 'integration_token',
      user: UserModel(
        id: 'integration-user',
        name: 'Integration User',
        email: 'integration@example.com',
      ),
    );
  }
}

/// 网络反馈组件需要连接状态流。集成测试固定为在线，避免调用平台插件或弹出与当前
/// 认证流程无关的 Toast。
final class _OnlineNetworkStatusService implements NetworkStatusService {
  @override
  Future<NetworkStatus> getCurrentStatus() async {
    return const NetworkStatus(NetworkConnectionType.wifi);
  }

  @override
  Stream<NetworkStatus> watchStatus() => const Stream.empty();
}

final class _MemoryPrivacyConsentRepository
    implements PrivacyConsentRepository {
  _MemoryPrivacyConsentRepository(this.acceptedVersion);

  String? acceptedVersion;

  @override
  PrivacyConsentRecord? readAcceptedPolicyRecord() => acceptedVersion == null
      ? null
      : PrivacyConsentRecord.fromLegacyVersion(acceptedVersion!);

  @override
  Future<bool> saveAcceptedPolicyRecord(PrivacyConsentRecord record) async {
    acceptedVersion = record.consentVersion;
    return true;
  }

  @override
  Future<bool> clearAcceptedPolicyVersion() async {
    acceptedVersion = null;
    return true;
  }
}

AppRouteBundle _routeBundle() {
  return AppRouteBundle(
    authenticatedHome: _homePath,
    protectedPaths: const [_protectedReportPath],
    routes: [
      GoRoute(
        path: _homePath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('integration home'))),
      ),
      GoRoute(
        path: _protectedReportPath,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('protected report'))),
      ),
    ],
  );
}

Widget _buildApp({
  required _MemorySessionStore store,
  required LoginRepository repository,
  bool hasAcceptedPrivacy = true,
}) {
  return ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(store),
      loginRepositoryProvider.overrideWithValue(repository),
      privacyPolicyConfigProvider.overrideWithValue(_policy),
      privacyConsentRepositoryProvider.overrideWithValue(
        _MemoryPrivacyConsentRepository(
          hasAcceptedPrivacy ? _policy.version : null,
        ),
      ),
      networkStatusServiceProvider.overrideWithValue(
        _OnlineNetworkStatusService(),
      ),
    ],
    child: MyApp(routeBundle: _routeBundle()),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'protected target redirects to login and returns after complete login use case',
    (tester) async {
      final store = _MemorySessionStore();
      final repository = _SuccessfulLoginRepository();
      await tester.pumpWidget(
        _buildApp(
          store: store,
          repository: repository,
          hasAcceptedPrivacy: false,
        ),
      );
      await tester.pumpAndSettle();

      // 首次进入登录页自动展示协议。此时没有输入，不会发登录请求；同意后只选中。
      expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
      expect(repository.receivedRequest, isNull);
      await tester.tap(find.byKey(const ValueKey('privacy.accept')));
      await tester.pumpAndSettle();

      // 未登录时主动访问受保护报表。守卫会进入登录页并把原目标编码为 returnTo。
      tester
          .element(find.byKey(const ValueKey('login.submit')))
          .go(_protectedReportPath);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);

      expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('login.account')),
        '  user@example.com  ',
      );
      await tester.enterText(
        find.byKey(const ValueKey('login.password')),
        ' pass word ',
      );
      await tester.tap(find.byKey(const ValueKey('login.submit')));
      await tester.pumpAndSettle();

      // 一次点击已经依次完成参数处理、Repository 请求、SessionStore 持久化、
      // AuthState 更新和路由守卫返回原目标，View 没有手工搬运 token/user。
      expect(repository.receivedRequest?.account, 'user@example.com');
      expect(repository.receivedRequest?.password, ' pass word ');
      expect(repository.receivedCancelToken, isNotNull);
      expect(store.session?.token, 'integration_token');
      expect(find.text('protected report'), findsOneWidget);
      expect(find.byKey(const ValueKey('login.submit')), findsNothing);
    },
  );

  testWidgets('saved session restores directly to authenticated home', (
    tester,
  ) async {
    final store = _MemorySessionStore(
      const AuthSession(
        token: 'saved_token',
        user: UserModel(
          id: 'saved-user',
          name: 'Saved User',
          email: 'saved@example.com',
        ),
      ),
    );

    await tester.pumpWidget(
      _buildApp(store: store, repository: _SuccessfulLoginRepository()),
    );
    // 第一帧处于 restoring，不应该短暂绘制登录表单。
    await tester.pump();
    expect(find.byKey(const ValueKey('login.submit')), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('integration home'), findsOneWidget);
    expect(find.byKey(const ValueKey('login.submit')), findsNothing);
  });
}
