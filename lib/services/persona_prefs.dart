import 'package:shared_preferences/shared_preferences.dart';

class PersonaPrefs {
  static String _key(String personaId) => 'persona_style:$personaId';

  static Future<String> getStyle(String personaId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(personaId)) ?? '';
  }

  static Future<void> saveStyle(String personaId, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(personaId), value.trim());
  }
}
