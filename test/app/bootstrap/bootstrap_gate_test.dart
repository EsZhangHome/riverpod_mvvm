// BootstrapGate 的 Widget 边界测试。
//
// 这里重点验证统一启动入口采用“外层项目 ProviderScope + 内层启动结果 Scope”时，
// 项目 overrides 仍能被 MyApp 内部读取。否则 README 中推荐的 rootBuilder 组合方式
// 看起来能编译，运行时却可能落回底座默认依赖。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_bootstrap.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_warmup.dart';
import 'package:riverpod_mvvm/app/bootstrap/bootstrap_gate.dart';
import 'package:riverpod_mvvm/app/navigation/app_route_bundle.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('project overrides reach the app inside BootstrapGate', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    var warmupCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        // 模拟 runApplication 的 rootBuilder：具体项目在外层替换预热任务。
        overrides: [
          // 本用例验证外层 override 与 Warmup，不测试隐私选择；预置当前版本是为了
          // 让需要授权的 Warmup 可以执行。
          privacyConsentRepositoryProvider.overrideWithValue(
            _MemoryPrivacyConsentRepository('starter-1'),
          ),
          appWarmupTasksProvider.overrideWithValue([
            AppWarmupTask(
              name: 'project_monitoring',
              run: () async {
                warmupCount++;
              },
            ),
          ]),
        ],
        child: BootstrapGate(
          // 测试不关心 SharedPreferences 插件，只让关键启动立即成功。
          bootstrap: AppBootstrap(
            validateConfiguration: () {},
            initializeStorage: () async {},
          ),
          routeBundle: AppRouteBundle(
            authenticatedHome: '/test-home',
            routes: [
              GoRoute(
                path: '/test-home',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 会话恢复完成后的 AppWarmup 应读到外层 override，而不是默认监控任务。
    expect(warmupCount, 1);
  });

  testWidgets('AppWarmup waits for login-time privacy consent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final privacyRepository = _MemoryPrivacyConsentRepository(null);
    var warmupCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          appWarmupTasksProvider.overrideWithValue([
            AppWarmupTask(
              name: 'sensitive_monitoring',
              run: () async => warmupCount++,
            ),
          ]),
        ],
        child: BootstrapGate(
          bootstrap: AppBootstrap(
            validateConfiguration: () {},
            initializeStorage: () async {},
          ),
          routeBundle: AppRouteBundle(
            authenticatedHome: '/test-home',
            routes: [
              GoRoute(
                path: '/test-home',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 首次启动先进入登录页但不自动弹窗；需要同意后才能运行的任务仍未启动。
    expect(find.byKey(const ValueKey('login.submit')), findsOneWidget);
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(warmupCount, 0);

    // 空表单点击登录先进入协议门禁。接受后只选中协议，不显示账号 Toast，但已足以
    // 放行需要授权的延迟初始化任务。
    await tester.tap(find.byKey(const ValueKey('login.submit')));
    await tester.pumpAndSettle();
    final acceptButton = find.byKey(const ValueKey('privacy.accept'));
    expect(acceptButton, findsOneWidget);
    await tester.ensureVisible(acceptButton);
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(privacyRepository.acceptedVersion, 'starter-1');
    expect(warmupCount, 1);
  });

  testWidgets('AppWarmup waits while policy upgrade dialog is unresolved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final privacyRepository = _MemoryPrivacyConsentRepository('old-version');
    var warmupCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privacyConsentRepositoryProvider.overrideWithValue(privacyRepository),
          appWarmupTasksProvider.overrideWithValue([
            AppWarmupTask(
              name: 'consent_required_sdk',
              run: () async => warmupCount++,
            ),
          ]),
        ],
        child: BootstrapGate(
          bootstrap: AppBootstrap(
            validateConfiguration: () {},
            initializeStorage: () async {},
          ),
          routeBundle: AppRouteBundle(
            authenticatedHome: '/test-home',
            routes: [
              GoRoute(
                path: '/test-home',
                builder: (context, state) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // MyApp 已创建并显示升级弹窗，但需要授权的预热任务仍然不能开始。
    expect(find.byKey(const ValueKey('privacy.dialog')), findsOneWidget);
    expect(warmupCount, 0);

    final acceptButton = find.byKey(const ValueKey('privacy.accept'));
    await tester.ensureVisible(acceptButton);
    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    expect(privacyRepository.acceptedVersion, 'starter-1');
    expect(find.byKey(const ValueKey('privacy.dialog')), findsNothing);
    expect(warmupCount, 1);
  });
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
