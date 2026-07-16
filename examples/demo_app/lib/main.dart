// 独立教学应用入口。
//
// 当前 package 单向依赖企业底座，企业底座完全不依赖本 package。因此运行 Demo
// 可以看到完整案例；删除 examples/demo_app 后，根项目不需要修改任何引用。

import 'package:flutter/foundation.dart';
import 'package:riverpod_mvvm/riverpod_mvvm.dart';

import 'demo_route_bundle.dart';

Future<void> main() async {
  // 教学 App 自己承担防误发布责任，底座中不保留任何 Demo 开关。
  if (kReleaseMode) {
    throw UnsupportedError('教学应用不能用于正式发布，请构建仓库根目录的企业底座。');
  }
  await runApplication(createDemoRouteBundle());
}
