import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';

class FailingWriteStore extends InMemorySharedPreferencesStore {
  FailingWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadAgentRole returns defaultAgentRole when nothing is saved', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    expect(await service.loadAgentRole(), defaultAgentRole);
  });

  test('saveAgentRole persists and loadAgentRole returns the saved role', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    await service.saveAgentRole('Eres un experto en SQL y modelado de datos.');

    expect(
      await service.loadAgentRole(),
      'Eres un experto en SQL y modelado de datos.',
    );
  });

  test('loadAgentRole falls back to default when the saved value is blank', () async {
    SharedPreferences.setMockInitialValues({'agent_role': '   '});
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    expect(await service.loadAgentRole(), defaultAgentRole);
  });

  test('saveAgentRole throws when the platform rejects the write', () async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesStorePlatform.instance = FailingWriteStore();
    SharedPreferences.resetStatic();
    final prefs = await SharedPreferences.getInstance();
    final service = PromptSettingsServiceImpl(preferences: prefs);

    await expectLater(
      service.saveAgentRole('Rol nuevo'),
      throwsA(isA<Exception>()),
    );
  });
}
