// Starter 的依赖组合入口。
//
// 路由与 Mock 都属于“项目尚未接入真实业务时”的可删除能力，因此统一留在
// app/starter。认证 Feature 只提供真实 Repository 和可替换 Provider，不读取
// ENV_ENABLE_MOCK，也不会因为教学模式增加第二条数据源分支。

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/env_config.dart';
import '../../features/auth/auth.dart';
import 'starter_mock_login_repository.dart';

/// 为 Starter 包装项目级 ProviderScope。
///
/// [child] 是 runApplication 创建的 BootstrapGate，必须原样放回 Widget 树。开发配置
/// 开启 Mock 时，只在这里 override loginRepositoryProvider；testing/staging 和
/// production 未开启时继续使用 Feature 默认的 RemoteLoginRepository。
///
/// 真实项目删除 Starter 后，可以在自己的 rootBuilder 中注入正式项目依赖，或者没有
/// override 时完全不传 rootBuilder。Mock 选择不会残留在 Repository 业务代码中。
Widget buildStarterRoot(Widget child) {
  if (!EnvConfig.enableMock) {
    return ProviderScope(child: child);
  }
  return ProviderScope(
    overrides: [
      loginRepositoryProvider.overrideWithValue(
        const StarterMockLoginRepository(),
      ),
    ],
    child: child,
  );
}
