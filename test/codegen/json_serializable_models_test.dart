// test/codegen/json_serializable_models_test.dart
//
// 验证使用 json_serializable 的示例 Model 能正常 fromJson / toJson。
// 后续新增 Model 时，可以参考这些写法。

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_request.dart';
import 'package:riverpod_mvvm/features/auth/login/model/login_response.dart';
import 'package:riverpod_mvvm/features/auth/session/model/user_model.dart';

void main() {
  group('json serializable models', () {
    test('user model parses json with generated code', () {
      // Arrange + Act：模拟 Repository 收到的 JSON，并交给生成的 fromJson。
      final user = UserModel.fromJson(const {
        'id': '1',
        'name': 'Test User',
        'email': 'test@example.com',
        'avatarUrl': 'https://example.com/avatar.png',
      });

      // Assert：字段解析和反向序列化都遵守接口 key。
      expect(user.id, '1');
      expect(user.name, 'Test User');
      expect(user.toJson()['email'], 'test@example.com');
    });

    test('login request uses generated toJson', () {
      const request = LoginRequest(
        account: 'test@example.com',
        password: '123456',
      );

      expect(request.toJson(), {
        'account': 'test@example.com',
        'password': '123456',
      });
    });

    test('login response string never exposes the access token', () {
      const secretToken = 'secret-access-token';
      const response = LoginResponse(
        token: secretToken,
        user: UserModel(id: '1', name: 'Test User', email: 'test@example.com'),
      );

      // 日志和调试器经常隐式调用 toString，敏感 token 必须始终被替换。
      expect(response.toString(), contains('<redacted>'));
      expect(response.toString(), isNot(contains(secretToken)));
    });
  });
}
