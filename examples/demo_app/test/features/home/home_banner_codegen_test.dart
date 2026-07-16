// Demo 首页 Model 的代码生成测试。
//
// HomeBanner 只服务于独立教学应用，因此测试也归当前 package 所有。
// 企业底座的 codegen 测试不引用它；删除整个示例应用不会影响底座测试。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm_demo/features/home/model/home_banner.dart';

void main() {
  test('home banner uses generated toJson', () {
    // json_serializable 生成的 toJson 应保持后端协议中的字段名。
    // 一旦 Model 字段或注解被误改，这个断言会尽早暴露兼容性问题。
    const banner = HomeBanner(
      id: 'banner_1',
      title: 'Banner',
      imageUrl: 'https://example.com/banner.png',
    );

    expect(banner.toJson(), {
      'id': 'banner_1',
      'title': 'Banner',
      'imageUrl': 'https://example.com/banner.png',
    });
  });
}
