// 企业应用唯一入口。
// 这里只组装底座默认路由；真实项目创建自己的 AppRouteBundle 后在这里替换。
// main 不直接初始化 SDK，也不创建 ProviderContainer，所有项目都沿用同一启动顺序。

import 'app/bootstrap/run_application.dart';
import 'app/navigation/app_route_bundle.dart';

Future<void> main() {
  // starter() 不是环境开关，而是“尚未接入真实业务”时使用的最小路由包：
  // 登录成功后只进入 /starter。接入项目首页后替换为 createProjectRoutes()。
  return runApplication(const AppRouteBundle.starter());
}
