// Demo 应用的根依赖组合入口。
//
// 这里是 Demo 唯一读取 ENV_ENABLE_MOCK 的位置。Repository、UseCase、ViewModel 和
// View 都不读取环境变量，只接收组合层最终选择的依赖，保持单一职责和可测试性。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_mvvm/core/config/env_config.dart';
import 'package:riverpod_mvvm/features/auth/auth.dart';
import 'package:riverpod_mvvm/features/privacy_consent/privacy_consent.dart';

import '../features/privacy_demo/privacy_demo.dart';
import 'demo_mock_login_repository.dart';

/// 为 [runApplication] 创建的根 Widget 安装 Demo 级 ProviderScope。
///
/// - `ENV_ENABLE_MOCK=true`：覆盖 [loginRepositoryProvider]，登录完全离线；
/// - `ENV_ENABLE_MOCK=false`：保留 Feature 默认的真实登录仓库，调用配置的 API；
/// - [child]：启动框架创建的 BootstrapGate，必须原样放入 Widget 树，不能丢弃。
///
/// Mock 选择只发生在应用最外层，符合 Riverpod“在组合根替换实现”的依赖注入方式。
Widget buildDemoRoot(Widget child) {
  return ProviderScope(
    overrides: [
      if (EnvConfig.enableMock)
        loginRepositoryProvider.overrideWithValue(
          const DemoMockLoginRepository(),
        ),
      // Demo 只替换“当前政策配置”的来源。底座的授权 Repository、状态机和全局
      // Dialog Host 全部保持正式实现，所以模拟升级能真实验证完整业务链路。
      privacyPolicyConfigProvider.overrideWith(
        (ref) => ref.watch(demoPrivacyPolicyConfigProvider),
      ),
    ],
    child: child,
  );
}
