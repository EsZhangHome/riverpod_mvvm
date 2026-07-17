// 企业应用唯一入口。
// 这里只组装底座默认路由和可删除的开发 Mock；真实项目接入自己的路由与依赖后替换。
// main 不直接初始化 SDK，也不创建 ProviderContainer，所有项目都沿用同一启动顺序。

import 'app/bootstrap/run_application.dart';
import 'app/starter/starter.dart';

Future<void> main() {
  // createStarterRouteBundle() 只用于“尚未接入真实业务”时验证完整启动和登录闭环。
  // 接入项目首页后，把 import 和下面的函数调用替换为项目自己的组合文件：
  //
  // import 'project_routes.dart';
  // return runApplication(createProjectRouteBundle());
  //
  // createProjectRouteBundle() 返回 AppRouteBundle，其中 authenticatedHome 必须等于真实
  // 首页 GoRoute.path；routes 注册页面；protectedPaths/protectedPrefixes 决定哪些地址
  // 必须登录。它不是框架内置函数，需要项目自己创建，README 第 9 节有完整示例。
  // 替换完成后可直接删除 lib/app/starter；路由、占位页面、开发 Mock 及其 Provider
  // override 会一起消失，认证 Feature 默认仍然使用真实后端 Repository。
  return runApplication(
    createStarterRouteBundle(),
    rootBuilder: buildStarterRoot,
  );
}
