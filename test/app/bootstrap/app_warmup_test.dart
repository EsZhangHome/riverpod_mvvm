// AppWarmup 生命周期测试。
//
// 这些测试不启动真实监控 SDK，而是通过 Provider override 注入普通闭包，验证：
// Provider 创建时不会自动预热、显式 start 只执行一次、单个失败不会变成 AsyncError。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/app/bootstrap/app_warmup.dart';

void main() {
  test('warmup stays idle until start is called', () async {
    var executions = 0;
    final container = ProviderContainer(
      overrides: [
        appWarmupTasksProvider.overrideWithValue([
          AppWarmupTask(
            name: 'test',
            run: () async {
              executions++;
            },
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    // 读取 Provider 只创建 Notifier，build() 返回 AsyncData(null)，不执行任务。
    expect(container.read(appWarmupProvider).value, isNull);
    expect(executions, 0);

    await container.read(appWarmupProvider.notifier).start();

    expect(executions, 1);
    expect(container.read(appWarmupProvider).value?.isSuccessful, isTrue);
  });

  test('repeated start calls do not initialize an SDK twice', () async {
    var executions = 0;
    final container = ProviderContainer(
      overrides: [
        appWarmupTasksProvider.overrideWithValue([
          AppWarmupTask(
            name: 'monitoring',
            run: () async {
              executions++;
            },
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(appWarmupProvider.notifier);

    await Future.wait([notifier.start(), notifier.start()]);

    expect(executions, 1);
  });

  test('task failure is collected without blocking other tasks', () async {
    var secondTaskCompleted = false;
    final container = ProviderContainer(
      overrides: [
        appWarmupTasksProvider.overrideWithValue([
          AppWarmupTask(
            name: 'broken_sdk',
            run: () async => throw StateError('sdk unavailable'),
          ),
          AppWarmupTask(
            name: 'healthy_sdk',
            run: () async {
              secondTaskCompleted = true;
            },
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appWarmupProvider.notifier).start();

    final state = container.read(appWarmupProvider);
    expect(state.hasError, isFalse);
    expect(secondTaskCompleted, isTrue);
    expect(state.value?.isSuccessful, isFalse);
    expect(state.value?.issues.single.task, 'broken_sdk');
  });

  test('hung task times out without blocking warmup completion', () async {
    final container = ProviderContainer(
      overrides: [
        appWarmupTasksProvider.overrideWithValue([
          AppWarmupTask(
            name: 'hung_sdk',
            timeout: const Duration(milliseconds: 10),
            run: () => Future<void>.delayed(const Duration(seconds: 1)),
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(appWarmupProvider.notifier).start();

    final result = container.read(appWarmupProvider).value;
    expect(result?.issues.single.error, isA<TimeoutException>());
  });
}
