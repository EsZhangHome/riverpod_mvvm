// 基础设施 Provider 生命周期测试。
//
// 重点不是测试 sqflite 本身，而是确保“拿到 DatabaseService”这个依赖注入动作
// 不会打开数据库。只有 Repository 真正执行 CRUD，按需 Provider 才开始初始化。

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/database/database_exception.dart';
import 'package:riverpod_mvvm/core/providers/service_providers.dart';

void main() {
  test('database stays lazy until the first CRUD operation', () async {
    var openCount = 0;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async {
          openCount++;
          throw StateError('stop before opening a real test database');
        }),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(databaseServiceProvider);
    expect(openCount, 0, reason: '注入 DatabaseService 时不应该打开 SQLite');

    // DatabaseService 会把 sqflite 或数据库工厂抛出的底层异常，统一转换成
    // DatabaseException。Repository 因而不需要认识 StateError、sqflite 异常等
    // 实现细节，只处理底座公开的稳定异常类型。
    await expectLater(
      service.query('unused_table'),
      throwsA(isA<DatabaseException>()),
    );
    expect(openCount, 1, reason: '第一次 CRUD 才应该请求数据库实例');
  });
}
