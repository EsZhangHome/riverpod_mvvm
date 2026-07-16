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
}
