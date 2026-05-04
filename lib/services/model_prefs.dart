import 'package:shared_preferences/shared_preferences.dart';

import 'curated_models.dart';

class ModelPrefs {
  static const _kSelectedModelId = 'selected_model_id';
  static const _kSelectedModelName = 'selected_model_name';
  static const _kSelectedProvider = 'selected_model_provider';

  static const String fallbackModelId = 'openai/gpt-5-mini';

  static CuratedModel get _fallbackModel =>
      findCuratedModelById(fallbackModelId) ??
      curatedOfficialModels.first;

  static Future<String?> getSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSelectedModelId);

    if (raw == null || raw.trim().isEmpty) return null;

    final normalized = _normalizeIncoming(raw);
    if (normalized != raw) {
      await prefs.setString(_kSelectedModelId, normalized);
    }
    return normalized;
  }

  static Future<String> getSelectedOrFallback() async {
    return (await getSelected()) ?? _fallbackModel.id;
  }

  static Future<CuratedModel> getSelectedModel() async {
    final id = await getSelectedOrFallback();
    return findCuratedModelById(id) ??
        findCuratedModelByAnyKey(id) ??
        _fallbackModel;
  }

  static Future<void> setSelected(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeIncoming(raw);
    final model =
        findCuratedModelById(normalized) ??
        findCuratedModelByAnyKey(normalized) ??
        _fallbackModel;

    await prefs.setString(_kSelectedModelId, model.id);
    await prefs.setString(_kSelectedModelName, model.displayName);
    await prefs.setString(_kSelectedProvider, model.provider);
  }

  static Future<void> setSelectedModel(CuratedModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedModelId, model.id);
    await prefs.setString(_kSelectedModelName, model.displayName);
    await prefs.setString(_kSelectedProvider, model.provider);
  }

  static Future<String?> getSelectedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedModelName);
  }

  static Future<String?> getSelectedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kSelectedProvider);
  }

  static String _normalizeIncoming(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return _fallbackModel.id;

    // If already a curated full id.
    final byId = findCuratedModelById(v);
    if (byId != null) return byId.id;

    // If matched by key/display/alias.
    final byAny = findCuratedModelByAnyKey(v);
    if (byAny != null) return byAny.id;

    // Legacy short keys.
    switch (v.toLowerCase()) {
      case 'gpt52':
      case 'gpt5':
      case 'gpt-5':
      case 'gpt51':
      case 'gpt-5.1':
        return 'openai/gpt-5-mini';

      case 'gpt5mini':
      case 'gpt-5-mini':
      case 'mini':
        return 'openai/gpt-5-mini';

      case 'gpt41mini':
      case 'gpt-4.1-mini':
        return 'openai/gpt-4.1-mini';

      case 'o1mini':
      case 'o1-mini':
        return 'openai/o1-mini';

      case 'claude':
      case 'claude-sonnet':
      case 'claude-sonnet-4.6':
        return 'anthropic/claude-sonnet-4.6';

      case 'gemini':
      case 'gemini-flash':
      case 'gemini-1.5-flash':
        return 'google/gemini-1.5-flash';

      default:
        return _fallbackModel.id;
    }
  }
}