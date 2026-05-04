import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../brain_channel.dart' show BrainChannel;
import 'package:flutter/foundation.dart' show ValueListenable;

// Voice I/O
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Gold accent (works on light & dark).
const _kAccent = Color(0xFFFFB300); // amber-700

class AiTranslationPage extends StatefulWidget {
  final String userId;
  const AiTranslationPage({super.key, required this.userId});

  @override
  State<AiTranslationPage> createState() => _AiTranslationPageState();
}

class _AiTranslationPageState extends State<AiTranslationPage> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();

  // Voice
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isListening = false;
  bool _ttsPlaying = false;

  bool _isBusy = false;
  String _sourceLang = 'Auto';
  String _targetLang = 'English'; // default To = English

  String? _detectedLang;
  String? _output;

  // TTS speed
  static const double _kDefaultRate = 0.45;
  static const double _kPitch = 1.0;

  @override
  void initState() {
    super.initState();
    // Ensure we get completion callbacks and keep UI in sync
    try {
      _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _ttsPlaying = false);
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => _ttsPlaying = false);
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() => _ttsPlaying = false);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    try {
      _tts.stop();
    } catch (_) {}
    super.dispose();
  }

  /* ───────────── Languages & locales ───────────── */

  // Keep a rich global list. "Auto" is only for the From picker.
  static const List<String> _allLanguages = [
    // Indian
    'English', 'Hindi', 'Tamil', 'Telugu', 'Malayalam', 'Kannada', 'Bengali', 'Urdu',
    'Marathi', 'Gujarati', 'Punjabi',
    // Major world
    'Spanish', 'French', 'German', 'Arabic',
    'Chinese (Simplified)', 'Chinese (Traditional)', 'Japanese', 'Korean',
    'Portuguese (Brazil)', 'Portuguese (Portugal)', 'Russian', 'Italian', 'Turkish',
    'Vietnamese', 'Thai', 'Indonesian', 'Filipino (Tagalog)', 'Dutch',
    'Greek', 'Hebrew', 'Persian (Farsi)', 'Polish', 'Czech', 'Hungarian',
    'Romanian', 'Ukrainian', 'Swedish', 'Danish', 'Norwegian', 'Finnish',
    'Afrikaans', 'Amharic', 'Nepali', 'Sinhala', 'Swahili',
  ];

  // name -> TTS locale
  static const Map<String, String> _ttsLocale = {
    'English': 'en-US',
    'Hindi': 'hi-IN',
    'Tamil': 'ta-IN',
    'Telugu': 'te-IN',
    'Malayalam': 'ml-IN',
    'Kannada': 'kn-IN',
    'Bengali': 'bn-IN',
    'Urdu': 'ur-PK',
    'Marathi': 'mr-IN',
    'Gujarati': 'gu-IN',
    'Punjabi': 'pa-IN',
    'Spanish': 'es-ES',
    'French': 'fr-FR',
    'German': 'de-DE',
    'Arabic': 'ar-SA',
    'Chinese (Simplified)': 'zh-CN',
    'Chinese (Traditional)': 'zh-TW',
    'Japanese': 'ja-JP',
    'Korean': 'ko-KR',
    'Portuguese (Brazil)': 'pt-BR',
    'Portuguese (Portugal)': 'pt-PT',
    'Russian': 'ru-RU',
    'Italian': 'it-IT',
    'Turkish': 'tr-TR',
    'Vietnamese': 'vi-VN',
    'Thai': 'th-TH',
    'Indonesian': 'id-ID',
    'Filipino (Tagalog)': 'fil-PH', // some engines use "tl-PH"
    'Dutch': 'nl-NL',
    'Greek': 'el-GR',
    'Hebrew': 'he-IL',
    'Persian (Farsi)': 'fa-IR',
    'Polish': 'pl-PL',
    'Czech': 'cs-CZ',
    'Hungarian': 'hu-HU',
    'Romanian': 'ro-RO',
    'Ukrainian': 'uk-UA',
    'Swedish': 'sv-SE',
    'Danish': 'da-DK',
    'Norwegian': 'nb-NO',
    'Finnish': 'fi-FI',
    'Afrikaans': 'af-ZA',
    'Amharic': 'am-ET',
    'Nepali': 'ne-NP',
    'Sinhala': 'si-LK',
    'Swahili': 'sw-KE',
  };

  String _ttsLocaleForLang(String name) => _ttsLocale[name] ?? 'en-US';
  String _sttLocaleForLang(String name) => _ttsLocaleForLang(name).replaceAll('-', '_');

  Future<void> _applyTtsSettings(String langName) async {
    final locale = _ttsLocaleForLang(langName);
    try {
      await _tts.setLanguage(locale);
    } catch (_) {}
    try {
      await _tts.setSpeechRate(_kDefaultRate);
      await _tts.setPitch(_kPitch);
    } catch (_) {}
  }

  Future<void> _speakOrStop() async {
    // Toggle Speak/Stop
    if (_ttsPlaying) {
      try {
        await _tts.stop();
      } catch (_) {}
      setState(() => _ttsPlaying = false);
      return;
    }

    final say = (_output ?? '').trim();
    if (say.isEmpty) return;
    await _applyTtsSettings(_targetLang);
    try {
      await _tts.stop();
      setState(() => _ttsPlaying = true);
      await _tts.speak(say);
      // Completion handler will flip _ttsPlaying = false
    } catch (_) {
      if (mounted) setState(() => _ttsPlaying = false);
    }
  }

  Future<void> _doTranslate({bool regenerate = false}) async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isBusy = true;
      if (!regenerate) {
        _output = null;
        _detectedLang = null;
      }
    });

    final system = '''
You are a careful, robust translation engine.
Return exactly one compact JSON object:
{"detected":"<language name>","translation":"<translated text>"}

Rules:
- Handle informal speech, slang, typos, code-mixing (e.g., Hinglish/Tanglish), and fragments.
- If "Source language" is "auto-detect", infer it from the text.
- Keep "detected" as a human language name (e.g., "English", "Tamil").
- If source and target are the same, paraphrase lightly in the target language/script.
- Do not add explanations, code fences, or extra keys.
''';

    final user = '''
Source language: ${_sourceLang == 'Auto' ? 'auto-detect' : _sourceLang}
Target language: $_targetLang

Source text:
$text
''';

    try {
      final raw = await BrainChannel.textOnly(
        system: system,
        user: user,
        tag: 'Translate',
      );

      Map<String, dynamic>? data;
      try {
        data = json.decode(raw) as Map<String, dynamic>;
      } catch (_) {
        final start = raw.indexOf('{');
        final end = raw.lastIndexOf('}');
        if (start != -1 && end > start) {
          data = json.decode(raw.substring(start, end + 1)) as Map<String, dynamic>;
        }
      }

      final detected = (data?['detected'] ?? _sourceLang) as String;
      final translation = (data?['translation'] ?? raw).toString().trim();

      setState(() {
        _detectedLang = detected;
        _output = translation;
      });

      TranslationHistoryStore.add(TranslationRecord(
        sourceText: text,
        detectedLang: detected,
        targetLang: _targetLang,
        translatedText: translation,
        at: DateTime.now(),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translate failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _swap() {
    if (_sourceLang == 'Auto') return;
    final s = _sourceLang;
    setState(() {
      _sourceLang = _targetLang;
      _targetLang = s;
      if ((_output ?? '').isNotEmpty) {
        _input.text = _output!;
        _output = null;
        _detectedLang = null;
        _inputFocus.requestFocus();
      }
    });
  }

  // Mic → STT in native script (follows "From"), DO NOT auto-translate
  Future<void> _micCaptureOnly() async {
    if (_isBusy) return;

    // permission
    final micOk = await Permission.microphone.request().isGranted;
    if (!micOk) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied.')));
      return;
    }

    // Initialize (safe to call repeatedly)
    await _speech.initialize(
      onStatus: (s) => setState(() => _isListening = s != 'done' && s != 'notListening'),
      onError: (_) => setState(() => _isListening = false),
    );

    // Decide STT locale
    String? localeId;
    if (_sourceLang != 'Auto') {
      localeId = _sttLocaleForLang(_sourceLang); // follow "From"
    } else {
      try {
        final sys = await _speech.systemLocale();
        localeId = sys?.localeId ?? 'en_US';
      } catch (_) {
        localeId = 'en_US';
      }
    }

    setState(() => _isListening = true);

    _speech.listen(
      localeId: localeId,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onResult: (val) async {
        final words = val.recognizedWords.trim();
        _input.text = words;
        _input.selection = TextSelection.fromPosition(TextPosition(offset: _input.text.length));

        if (val.finalResult) {
          await _speech.stop();
          setState(() => _isListening = false);
          // IMPORTANT: no auto-translate here; user taps "Translate".
        }
      },
    );
  }

  Color _cardColor(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? const Color(0xFF12151A) : Colors.white;

  Color _softBorder(BuildContext c) {
    final isDark = Theme.of(c).brightness == Brightness.dark;
    return isDark ? _kAccent.withOpacity(.55) : _kAccent.withOpacity(.70);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCard = _cardColor(context);
    final edge = _softBorder(context);
    final screenH = MediaQuery.of(context).size.height;
    final inputMinH = screenH * 0.66; // ~2/3 screen

    final clearBg = isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.06);
    final clearFg = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Translation'),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const _HistoryScreen(),
              ));
            },
            icon: const Icon(Icons.history_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // INPUT
            Stack(
              children: [
                Container(
                  constraints: BoxConstraints(minHeight: inputMinH),
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 68),
                  decoration: BoxDecoration(
                    color: baseCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: edge, width: 2),
                    boxShadow: [
                      if (isDark)
                        BoxShadow(color: _kAccent.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 8))
                      else
                        BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
                    minLines: 8,
                    maxLines: null,
                    style: TextStyle(fontSize: 16, height: 1.35, color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Speak or type to translate…',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(.6),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                // Clear
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      _input.clear();
                      setState(() {
                        _output = null;
                        _detectedLang = null;
                      });
                      _inputFocus.requestFocus();
                    },
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: clearBg,
                      foregroundColor: clearFg,
                    ),
                  ),
                ),
                // Mic (manual; does NOT auto-translate)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'mic',
                    tooltip: 'Speak',
                    onPressed: _isBusy ? null : _micCaptureOnly,
                    backgroundColor: _isListening ? Colors.redAccent : _kAccent,
                    foregroundColor: Colors.black,
                    child: Icon(_isListening ? Icons.mic : Icons.mic_none_rounded),
                  ),
                ),
                // Translate
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: FloatingActionButton.extended(
                    heroTag: 'go',
                    onPressed: _isBusy ? null : () => _doTranslate(),
                    label: const Text('Translate'),
                    icon: _isBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_rounded),
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // PICKERS (searchable)
            Row(
              children: [
                Expanded(
                  child: _LangPickerField(
                    label: 'From',
                    value: _sourceLang,
                    allowAuto: true,
                    options: _allLanguages,
                    accent: _kAccent,
                    onPicked: (v) => setState(() => _sourceLang = v),
                  ),
                ),
                const SizedBox(width: 8),
                _SwapButton(onTap: _swap),
                const SizedBox(width: 8),
                Expanded(
                  child: _LangPickerField(
                    label: 'To',
                    value: _targetLang,
                    allowAuto: false,
                    options: _allLanguages,
                    accent: _kAccent,
                    onPicked: (v) => setState(() => _targetLang = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // OUTPUT
            if (_output != null)
              _OutputCard(
                detectedLang: _detectedLang ?? _sourceLang,
                targetLang: _targetLang,
                text: _output!,
                isSpeaking: _ttsPlaying,
                onCopy: () => Share.share(_output!),
                onShare: () => Share.share(_output!),
                onRegenerate: _isBusy ? null : () => _doTranslate(regenerate: true),
                onSpeakOrStop: _speakOrStop,
              ),
          ],
        ),
      ),
    );
  }
}

/* ───────────── Searchable language picker ───────────── */

class _LangPickerField extends StatelessWidget {
  final String label;
  final String value;
  final bool allowAuto;
  final List<String> options;
  final Color accent;
  final ValueChanged<String> onPicked;

  const _LangPickerField({
    required this.label,
    required this.value,
    required this.allowAuto,
    required this.options,
    required this.accent,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF12151A)
        : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _LanguageSearchSheet(
            title: '$label language',
            current: value,
            options: allowAuto ? ['Auto', ...options] : options,
            accent: accent,
          ),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: accent),
          filled: true,
          fillColor: base,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accent.withOpacity(.5), width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accent, width: 2.2),
          ),
          suffixIcon: const Icon(Icons.search_rounded),
        ),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _LanguageSearchSheet extends StatefulWidget {
  final String title;
  final String current;
  final List<String> options;
  final Color accent;
  const _LanguageSearchSheet({
    required this.title,
    required this.current,
    required this.options,
    required this.accent,
  });

  @override
  State<_LanguageSearchSheet> createState() => _LanguageSearchSheetState();
}

class _LanguageSearchSheetState extends State<_LanguageSearchSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface.withOpacity(.18);
    final items = widget.options;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: ring, borderRadius: BorderRadius.circular(999))),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                hintText: 'Search language…',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final lang = items[i];
                final q = _q.text.trim().toLowerCase();
                if (q.isNotEmpty && !lang.toLowerCase().contains(q)) {
                  return const SizedBox.shrink();
                }
                final active = lang == widget.current;
                return ListTile(
                  title: Text(lang, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                  trailing: active ? Icon(Icons.check_circle_rounded, color: widget.accent) : null,
                  onTap: () => Navigator.pop(context, lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────── Small widgets ───────────── */

class _SwapButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SwapButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent.withOpacity(.12),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(10.0),
          child: Icon(Icons.swap_horiz_rounded, color: _kAccent, size: 26),
        ),
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String detectedLang;
  final String targetLang;
  final String text;
  final bool isSpeaking;
  final VoidCallback? onRegenerate;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onSpeakOrStop;

  const _OutputCard({
    required this.detectedLang,
    required this.targetLang,
    required this.text,
    required this.isSpeaking,
    required this.onCopy,
    required this.onShare,
    required this.onSpeakOrStop,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12151A) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kAccent, width: 2),
        boxShadow: [
          if (isDark)
            BoxShadow(color: _kAccent.withOpacity(.12), blurRadius: 18, offset: const Offset(0, 10))
          else
            BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detected: $detectedLang  →  $targetLang',
              style: TextStyle(color: _kAccent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ChipBtn(
                icon: isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                label: isSpeaking ? 'Stop' : 'Speak',
                onTap: onSpeakOrStop,
              ),
              const SizedBox(width: 8),
              _ChipBtn(
                icon: Icons.restart_alt_rounded,
                label: 'Regenerate',
                onTap: onRegenerate,
              ),
              const SizedBox(width: 8),
              _ChipBtn(
                icon: Icons.file_upload_outlined,
                label: 'Share',
                onTap: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ChipBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: _kAccent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
      ),
    );
  }
}

/* ───────────── History ───────────── */

class TranslationRecord {
  final String sourceText;
  final String detectedLang;
  final String targetLang;
  final String translatedText;
  final DateTime at;

  TranslationRecord({
    required this.sourceText,
    required this.detectedLang,
    required this.targetLang,
    required this.translatedText,
    required this.at,
  });
}

class TranslationHistoryStore {
  static final ValueNotifier<List<TranslationRecord>> _items =
      ValueNotifier<List<TranslationRecord>>(<TranslationRecord>[]);

  static ValueListenable<List<TranslationRecord>> listenable() => _items;

  static void add(TranslationRecord r) {
    _items.value = [r, ..._items.value];
  }

  static void removeMany(Set<int> indices) {
    final list = [..._items.value];
    final sorted = indices.toList()..sort();
    for (final i in sorted.reversed) {
      if (i >= 0 && i < list.length) list.removeAt(i);
    }
    _items.value = list;
  }

  static List<TranslationRecord> snapshot() => _items.value;
}

class _HistoryScreen extends StatefulWidget {
  const _HistoryScreen();

  @override
  State<_HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<_HistoryScreen> {
  bool _selectMode = false;
  final Set<int> _selected = <int>{};

  void _toggleSelect(int idx) {
    setState(() {
      if (_selected.contains(idx)) {
        _selected.remove(idx);
      } else {
        _selected.add(idx);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectMode ? '${_selected.length} selected' : 'History'),
        actions: [
          if (_selectMode) ...[
            IconButton(
              tooltip: 'Delete',
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      TranslationHistoryStore.removeMany(_selected);
                      setState(() {
                        _selected.clear();
                        _selectMode = false;
                      });
                    },
              icon: const Icon(Icons.delete_rounded),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: _selected.isEmpty
                  ? null
                  : () {
                      final items = _selected.toList()..sort();
                      final all = TranslationHistoryStore.snapshot();
                      final list = <TranslationRecord>[];
                      for (final i in items) {
                        if (i >= 0 && i < all.length) list.add(all[i]);
                      }
                      final text = list
                          .map((r) =>
                              '[${r.detectedLang} → ${r.targetLang}]\n${r.sourceText}\n→ ${r.translatedText}')
                          .join('\n\n---\n\n');
                      Share.share(text);
                    },
              icon: const Icon(Icons.file_upload_outlined),
            ),
          ],
          TextButton(
            onPressed: () {
              setState(() {
                _selectMode = !_selectMode;
                _selected.clear();
              });
            },
            child: Text(_selectMode ? 'Done' : 'Select'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ValueListenableBuilder<List<TranslationRecord>>(
        valueListenable: TranslationHistoryStore.listenable(),
        builder: (_, items, __) {
          if (items.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = items[i];
              final selected = _selected.contains(i);

              return InkWell(
                onLongPress: () {
                  if (!_selectMode) setState(() => _selectMode = true);
                  _toggleSelect(i);
                },
                onTap: _selectMode ? () => _toggleSelect(i) : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF12151A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? _kAccent : Colors.black12.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.0 : 1.0),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.translate_rounded, color: _kAccent, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${it.detectedLang} → ${it.targetLang}',
                              style: TextStyle(
                                color: _kAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.sourceText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              it.translatedText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_selectMode)
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: selected ? _kAccent : Colors.white38,
                        )
                      else
                        PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                          onSelected: (v) {
                            if (v == 'share') {
                              Share.share(
                                  '[${it.detectedLang} → ${it.targetLang}]\n${it.sourceText}\n→ ${it.translatedText}');
                            } else if (v == 'delete') {
                              TranslationHistoryStore.removeMany({i});
                              setState(() {});
                            }
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
