import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clayton_agent/data/services/prompt_settings_service.dart';

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
}
