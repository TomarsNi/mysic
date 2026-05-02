import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysic_flutter/features/settings/data/delete_preference.dart';

void main() {
  group('DeletePreference', () {
    setUp(() async {
      // 初始化测试用的 SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('默认值为 false', () async {
      final value = await DeletePreference.getDeleteWithFile();
      expect(value, isFalse);
    });

    test('设置后可正确读取', () async {
      await DeletePreference.setDeleteWithFile(true);
      final value = await DeletePreference.getDeleteWithFile();
      expect(value, isTrue);
    });

    test('可以修改回 false', () async {
      await DeletePreference.setDeleteWithFile(true);
      expect(await DeletePreference.getDeleteWithFile(), isTrue);

      await DeletePreference.setDeleteWithFile(false);
      expect(await DeletePreference.getDeleteWithFile(), isFalse);
    });
  });
}