import 'package:shared_preferences/shared_preferences.dart';

const String defaultAgentRole = """
Responde la siguiente pregunta técnica sobre Dart/Flutter basándote en
la documentación y los plugins provistos en el contexto. Si encuentras
código relevante o patrones de arquitectura en el contexto, úsalos para
armar un ejemplo práctico.
""";

abstract class PromptSettingsService {
  Future<String> loadAgentRole();
  Future<void> saveAgentRole(String role);
}

class PromptSettingsServiceImpl implements PromptSettingsService {
  static const String agentRoleKey = 'agent_role';
  final SharedPreferences preferences;

  PromptSettingsServiceImpl({required this.preferences});

  @override
  Future<String> loadAgentRole() async {
    final saved = preferences.getString(agentRoleKey)?.trim();
    if (saved == null || saved.isEmpty) {
      return defaultAgentRole;
    }
    return saved;
  }

  @override
  Future<void> saveAgentRole(String role) async {
    final saved = await preferences.setString(agentRoleKey, role);
    if (!saved) {
      throw Exception('No se pudo guardar el rol del agente.');
    }
  }
}
