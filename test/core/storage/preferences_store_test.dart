import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_mvvm/core/storage/local_storage.dart';
import 'package:riverpod_mvvm/core/storage/preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('default adapter delegates to bootstrap initialized plugin', () async {
    SharedPreferences.setMockInitialValues({
      'name': 'starter',
      'enabled': true,
    });
    await LocalStorage.init();
    const store = BootstrappedPreferencesStore();

    expect(store.getString('name'), 'starter');
    expect(store.getBool('enabled'), isTrue);

    expect(await store.setString('name', 'project'), isTrue);
    expect(await store.setBool('enabled', false), isTrue);
    expect(store.getString('name'), 'project');
    expect(store.getBool('enabled'), isFalse);

    expect(await store.remove('name'), isTrue);
    expect(store.getString('name'), isNull);
  });
}
