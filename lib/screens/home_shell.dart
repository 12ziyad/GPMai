// lib/screens/home_shell.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:gpmai_clean/prompts/bots_prompts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sql_chat_store.dart';
import 'chat_page.dart';
import 'explore_page.dart';
import '../services/model_prefs.dart';
import '../services/gpmai_brain.dart';
import '../services/gpmai_api_client.dart';
import '../services/models_api.dart';
import '../stores/models_store.dart';
import 'models/models_hub_page.dart';
import '../services/curated_models.dart';
import '../services/curated_media_models.dart';
import '../services/provider_branding.dart';
import 'models_explore_page.dart';
import 'model_info_page.dart';
import 'model_history_page.dart';
import 'ai_lab_page.dart';
import 'personas_all_page.dart';
import '../prompts/bots_prompts.dart' show kBuiltInPersonas, PersonaDefinition;
import 'persona_detail_page.dart';

// Advanced space pages:
import '../spaces/upload_ask_page.dart';
import '../spaces/solve_math_page.dart';
import '../spaces/homework_tutor_page.dart';
import '../spaces/pdf_summary_home.dart';
import '../spaces/email_writer_page.dart';
import '../spaces/deepsearch_page.dart';
import '../spaces/ocr_page.dart';
import '../spaces/ask_url_page.dart';
import '../spaces/yt_summary_page.dart';
import '../spaces/grammar_check_page.dart';
import '../spaces/ai_translation_page.dart';
import '../spaces/travel_page.dart';
import '../spaces/image_generator_page.dart';
import '../spaces/video_generator_page.dart';
import '../spaces/audio_generator_page.dart';

// Settings pages
import '../settings/faq_page.dart';
import '../settings/terms_of_use_page.dart';
import '../settings/privacy_policy_page.dart';
import 'points_manager_page.dart';
import 'memory_hub_page.dart';
import '../services/memory_session.dart';

typedef ThemeSetter = void Function(ThemeMode);

/// Robust bridge for native orb overlay.
class OrbBridge {
  static const _channels = <MethodChannel>[
    MethodChannel('gpmai/orb_channel'),
    MethodChannel('gpmai/brain'),
  ];

  static Future<T?> _tryAll<T>(List<String> methods) async {
    for (final m in methods) {
      for (final ch in _channels) {
        try {
          final r = await ch.invokeMethod<T>(m);
          return r;
        } catch (_) {}
      }
    }
    return null;
  }

  static Future<void> _fireAndForget(List<String> methods) async {
    for (final m in methods) {
      for (final ch in _channels) {
        try {
          await ch.invokeMethod(m);
          return;
        } catch (_) {}
      }
    }
    throw PlatformException(
      code: 'orb_method_not_found',
      message: 'No native method for ${methods.join(" / ")}',
    );
  }

  static Future<void> prewarm() async {
    await _tryAll<void>(['prewarmOrb', 'prewarm', 'warmUp']);
  }

  static Future<void> ensureOverlayPermissionIfAny() async {
    await _tryAll<void>([
      'ensureOverlayPermission',
      'requestOverlayPermission',
      'openOverlaySettings'
    ]);
  }

  static Future<bool> isRunning() async {
    for (final name in const ['isOrbRunning', 'is_orb_running', 'orbRunning']) {
      for (final ch in _channels) {
        try {
          final r = await ch.invokeMethod(name);
          if (r is bool) return r;
          if (r != null) return true;
        } catch (_) {}
      }
    }
    return false;
  }

  static Future<void> start() async {
    await ensureOverlayPermissionIfAny();
    await _fireAndForget(['startOrb', 'showOrb', 'startOverlay']);
  }

  static Future<void> stop() async {
    await _fireAndForget(['stopOrb', 'hideOrb', 'stopOverlay']);
  }
}

class HomeShell extends StatefulWidget {
  final String userId;
  final ThemeSetter? onChangeTheme;
  final ThemeMode? currentThemeMode;

  const HomeShell({
    super.key,
    required this.userId,
    this.onChangeTheme,
    this.currentThemeMode,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum HomeTab { aiModels, explore, aiLab, inbox }

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  HomeTab _tab = HomeTab.aiModels;
  bool _profileOpen = false;
  bool _floatingOrbRunning = false;

  static const _prefsThemeKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await OrbBridge.prewarm();
      await _applySavedTheme();
      await _applySavedModel();
      await MemorySession.ensureInitialized();
    });
  }

  Future<void> _applySavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_prefsThemeKey);
      if (s == null) return;
      final mode = s == 'light'
          ? ThemeMode.light
          : s == 'dark'
              ? ThemeMode.dark
              : ThemeMode.system;
      widget.onChangeTheme?.call(mode);
    } catch (_) {}
  }

  Future<void> _applySavedModel() async {
    const fallbackModelId = 'openai/gpt-5.2';
    try {
      final saved = (await ModelPrefs.getSelected())?.trim();
      if (saved != null && saved.isNotEmpty && saved.contains('/')) {
        GPMaiBrain.model = saved;
      } else {
        GPMaiBrain.model = fallbackModelId;
      }
    } catch (_) {
      GPMaiBrain.model = fallbackModelId;
    }
  }

  Future<void> _saveTheme(ThemeMode m) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsThemeKey,
        m == ThemeMode.light ? 'light' : m == ThemeMode.dark ? 'dark' : 'system',
      );
    } catch (_) {}
  }

  void _switch(HomeTab t) => setState(() => _tab = t);

  Future<void> _openProfileSheet() async {
    if (_profileOpen) return;
    _profileOpen = true;

    try {
      final running = await OrbBridge.isRunning();
      if (mounted) setState(() => _floatingOrbRunning = running);
    } catch (_) {}

    ThemeMode selected = widget.currentThemeMode ??
        (Theme.of(context).brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black.withOpacity(0.35),
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final h = MediaQuery.of(ctx).size.height * 0.9;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final ThemeData sheetTheme = selected == ThemeMode.light
                ? ThemeData.light().copyWith(
                    scaffoldBackgroundColor: Colors.white,
                    cardColor: Colors.white,
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF00B8FF),
                      secondary: Color(0xFF00B8FF),
                    ),
                  )
                : ThemeData.dark().copyWith(
                    scaffoldBackgroundColor: const Color(0xFF0D0F12),
                    cardColor: const Color(0xFF12151A),
                    colorScheme: const ColorScheme.dark(
                      primary: Color(0xFF00B8FF),
                      secondary: Color(0xFF00B8FF),
                    ),
                  );

            return Theme(
              data: sheetTheme,
              child: Container(
                height: h,
                decoration: BoxDecoration(
                  color: sheetTheme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: _ThemeChooser(
                  selected: selected,
                  onPick: (m) {
                    setLocal(() => selected = m);
                    widget.onChangeTheme?.call(m);
                    _saveTheme(m);
                    if (mounted) setState(() {});
                  },
                  initialFloatingOrb: _floatingOrbRunning,
                  onToggleFloatingOrb: (v) => setState(() => _floatingOrbRunning = v),
                ),
              ),
            );
          },
        );
      },
    );

    _profileOpen = false;
  }

  void _onExploreToolTap(String id) {
    switch (id) {
      case 'upload_ask':
        Navigator.push(context, MaterialPageRoute(builder: (_) => UploadAskPage(userId: widget.userId)));
        break;
      case 'solve_math':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SolveMathPage(userId: widget.userId)));
        break;
      case 'homework':
        Navigator.push(context, MaterialPageRoute(builder: (_) => HomeworkTutorPage(userId: widget.userId)));
        break;
      case 'pdf_summary':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfSummaryHomePage()));
        break;
      case 'email_writer':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailWriterPage()));
        break;
      case 'deepsearch':
        Navigator.push(context, MaterialPageRoute(builder: (_) => DeepSearchPage(userId: widget.userId)));
        break;
      case 'ocr':
        Navigator.push(context, MaterialPageRoute(builder: (_) => OcrPage(userId: widget.userId)));
        break;
      case 'ask_url':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AskUrlPage(userId: widget.userId)));
        break;
      case 'yt_summary':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const YTSummaryHomePage()));
        break;
      case 'grammar':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const GrammarCheckPage()));
        break;
      case 'translation':
        Navigator.push(context, MaterialPageRoute(builder: (_) => AiTranslationPage(userId: widget.userId)));
        break;
      case 'travel_tool':
        Navigator.push(context, MaterialPageRoute(builder: (_) => TravelPage(userId: widget.userId)));
        break;
      default:
        final title = _titleForTool(id);
        _openToolAsChat(toolId: id, title: title);
    }
  }

  Future<void> _openToolAsChat({required String toolId, required String title}) async {
    final store = SqlChatStore();
    final chatId = await store.createChat(name: title, preset: {'kind': 'tool', 'id': toolId});
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a1, __) => FadeTransition(
          opacity: a1,
          child: ChatPage(
            userId: widget.userId,
            chatId: chatId,
            chatName: title,
            systemPrompt: _systemPromptForTool(toolId),
          ),
        ),
      ),
    );
  }

  String _titleForTool(String id) {
    switch (id) {
      case 'upload_ask':
        return 'Upload Image & Ask';
      case 'solve_math':
        return 'Solve Math';
      case 'homework':
        return 'AI Homework Tutor';
      case 'pdf_summary':
        return 'PDF summary & Ask';
      case 'email_writer':
        return 'AI Email Writer';
      case 'deepsearch':
        return 'AI DeepSearch';
      case 'ocr':
        return 'OCR';
      case 'ask_url':
        return 'Ask about URL';
      case 'yt_summary':
        return 'YouTube Summary & Ask';
      case 'grammar':
        return 'Grammar Check';
      case 'translation':
        return 'AI Translation';
      case 'travel_tool':
        return 'Travel';
      default:
        return 'New Chat';
    }
  }

  String? _systemPromptForTool(String id) {
    switch (id) {
      case 'upload_ask':
        return '''
You analyze one or more images and answer the user's question.
Rules:
- Be concise (1â€“2 sentences unless asked to expand).
- State assumptions. If uncertain, ask 1 clarification Q max.
- If text is present in the image, read it and use it.
- If math or code is detected, format with LaTeX or code blocks.
- If safety-sensitive, warn briefly and give a safe alternative.
[mood: neutral]
''';
      case 'solve_math':
        return '''
You are a careful math solver.
Rules:
- Always show minimal step-by-step reasoning (2â€“6 lines).
- Use LaTeX for expressions; end with **Answer: â€¦**.
- If a diagram is attached, describe what you used from it.
- If the question is ambiguous, ask 1 short clarifying question first.
- Never fabricate data. If impossible, say so briefly.
[mood: neutral]
''';
      case 'homework':
        return '''
You are a friendly tutor. Teach; do not just give answers.
Rules:
- Start with a 1-sentence plan; then short steps or bullets.
- Explain simply; define terms. Offer a quick check question at the end.
- If the user attaches notes/diagrams/PDF, cite the relevant parts (â€œsee p. Xâ€).
- If the request is an exam/graded task, provide guidance, not the full solution.
[mood: happy]
''';
      case 'pdf_summary':
        return '''
You receive the extracted text of a PDF. Produce:
1) â€œKey pointsâ€ â€“ 5â€“8 crisp bullets, each â‰¤18 words.
2) â€œSummaryâ€ â€“ 1 compact paragraph.
Follow the chosen output language. No extra sections.
[mood: neutral]
''';
      case 'email_writer':
        return '''
You write emails in the selected tone, length, and language.
Rules:
- Subject (if applicable) then body.
- Keep it clear, human, and specific. No fluff.
- Respect the provided â€œLearning Resourceâ€ as hard constraints for style.
[mood: neutral]
''';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("GPMai"),
            const SizedBox(width: 12),
            InkWell(
              onTap: _openProfileSheet,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(Icons.person_rounded, size: 22),
              ),
            ),
          ],
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (c, a) => SlideTransition(
          position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(a),
          child: FadeTransition(opacity: a, child: c),
        ),
        child: switch (_tab) {
          HomeTab.aiModels => _AiHomePane(key: const ValueKey('ai_home'), userId: widget.userId),
          HomeTab.explore => ExplorePage(
              key: const ValueKey('explore'),
              onTapCategory: (id) {},
              onTapTool: _onExploreToolTap,
            ),
          HomeTab.aiLab => AILabPage(key: const ValueKey('ai_lab'), userId: widget.userId),
          HomeTab.inbox => _InboxPane(key: const ValueKey('inbox'), userId: widget.userId),
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  child: _BottomTab(
                    label: "AI Home",
                    icon: Icons.home_rounded,
                    selected: _tab == HomeTab.aiModels,
                    isLight: isLight,
                    onTap: () => _switch(HomeTab.aiModels),
                  ),
                ),
                Expanded(
                  child: _BottomTab(
                    label: "Explore",
                    icon: Icons.explore_rounded,
                    selected: _tab == HomeTab.explore,
                    isLight: isLight,
                    onTap: () => _switch(HomeTab.explore),
                  ),
                ),
                Expanded(
                  child: _BottomTab(
                    label: "AI Lab",
                    icon: Icons.science_rounded,
                    selected: _tab == HomeTab.aiLab,
                    isLight: isLight,
                    onTap: () => _switch(HomeTab.aiLab),
                  ),
                ),
                Expanded(
                  child: _BottomTab(
                    label: "Inbox",
                    icon: Icons.inbox_rounded,
                    selected: _tab == HomeTab.inbox,
                    isLight: isLight,
                    onTap: () => _switch(HomeTab.inbox),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= THEME CHOOSER SHEET ================= */

class _ThemeChooser extends StatefulWidget {
  final ThemeMode selected;
  final ValueChanged<ThemeMode> onPick;
  final bool initialFloatingOrb;
  final ValueChanged<bool> onToggleFloatingOrb;

  const _ThemeChooser({
    required this.selected,
    required this.onPick,
    required this.initialFloatingOrb,
    required this.onToggleFloatingOrb,
  });

  @override
  State<_ThemeChooser> createState() => _ThemeChooserState();
}

class _ThemeChooserState extends State<_ThemeChooser> {
  static const String _feedbackEmail = 'gpmai.app@gmail.com';

  late ThemeMode _picked;
  late bool _floatingOrbVisible;
  bool _startingOrb = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.selected;
    _floatingOrbVisible = widget.initialFloatingOrb;
  }

  Future<void> _toggleNativeOrb(bool turnOn) async {
    if (_startingOrb) return;
    if (turnOn) {
      setState(() {
        _floatingOrbVisible = true;
        _startingOrb = true;
      });
      try {
        await OrbBridge.start();
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _startingOrb = false);
        widget.onToggleFloatingOrb(true);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _startingOrb = false;
          _floatingOrbVisible = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start Orb. Check overlay permission & channel names.')),
        );
      }
    } else {
      setState(() => _floatingOrbVisible = false);
      try {
        await OrbBridge.stop();
      } catch (_) {}
      widget.onToggleFloatingOrb(false);
    }
  }

  Future<void> _shareApp() async {
    await Share.share('Try GPMai â€“ my AI companion.\nhttps://example.com');
  }

  Future<void> _openMail({required String to, required String subject}) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: {'subject': subject},
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    Widget card({required bool light, required bool active, required VoidCallback onTap}) {
      final bg = light ? Colors.white : const Color(0xFF151920);
      final border = active ? cs.primary : (isLight ? Colors.black12 : Colors.white12);
      final icon = light ? Icons.wb_sunny_rounded : Icons.nightlight_round;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Container(
            height: 210,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: border, width: 3),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 64,
                color: light ? const Color(0xFFFFA000) : cs.primary,
              ),
            ),
          ),
        ),
      );
    }

    Widget radioPill({required String label, required bool active, required VoidCallback onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? cs.primary.withOpacity(.18) : (isLight ? Colors.black12 : Colors.white10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: active ? cs.primary : (isLight ? Colors.black26 : Colors.white24), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 18,
                color: active ? cs.primary : (isLight ? Colors.black54 : Colors.white54),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isLight ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    BoxDecoration sectionBox() => BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isLight ? Colors.black.withOpacity(.04) : Colors.white.withOpacity(.04),
          border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
        );

    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isLight ? Colors.black26 : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Appearance", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  card(
                    light: true,
                    active: _picked == ThemeMode.light,
                    onTap: () {
                      setState(() => _picked = ThemeMode.light);
                      widget.onPick(ThemeMode.light);
                    },
                  ),
                  const SizedBox(width: 20),
                  card(
                    light: false,
                    active: _picked == ThemeMode.dark,
                    onTap: () {
                      setState(() => _picked = ThemeMode.dark);
                      widget.onPick(ThemeMode.dark);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                radioPill(
                  label: "Light",
                  active: _picked == ThemeMode.light,
                  onTap: () {
                    setState(() => _picked = ThemeMode.light);
                    widget.onPick(ThemeMode.light);
                  },
                ),
                radioPill(
                  label: "Dark",
                  active: _picked == ThemeMode.dark,
                  onTap: () {
                    setState(() => _picked = ThemeMode.dark);
                    widget.onPick(ThemeMode.dark);
                  },
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Orb", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: sectionBox(),
                child: ListTile(
                  title: const Text("Orb"),
                  subtitle: Text(
                    _floatingOrbVisible ? "Floating orb overlay is ON" : "Floating orb overlay is OFF",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _floatingOrbVisible,
                        onChanged: (v) => _toggleNativeOrb(v),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      if (_startingOrb) const SizedBox(width: 10),
                      if (_startingOrb)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  onTap: () => _toggleNativeOrb(!_floatingOrbVisible),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("AI Memory", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: sectionBox(),
                child: ValueListenableBuilder<String>(
                  valueListenable: MemorySession.activeModeNotifier,
                  builder: (context, activeMode, _) => ListTile(
                    leading: const Icon(Icons.account_tree_rounded),
                    title: const Text('Memory Profiles & Brain Graph'),
                    subtitle: Text('Active mode: ${MemorySession.modeLabel(activeMode)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(.2)),
                      ),
                      child: Text(
                        MemorySession.modeLabel(activeMode),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryHubPage()));
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Wallet", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: sectionBox(),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text("Points Manager"),
                      subtitle: const Text("Weekly + monthly usage graphs"),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PointsManagerPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text("Support & Legal", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                decoration: sectionBox(),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.help_outline_rounded),
                      title: const Text('FAQ'),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FaqPage()));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Terms of Use'),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfUsePage()));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacy Policy'),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.ios_share_rounded),
                      title: const Text('Share app'),
                      onTap: _shareApp,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text('Report / Feedback'),
                      subtitle: const Text(_feedbackEmail),
                      onTap: () => _openMail(
                        to: _feedbackEmail,
                        subject: 'GPMai Feedback',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/* ================= Bottom tab ================= */

class _BottomTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  const _BottomTab({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconColor = selected ? cs.primary : (isLight ? Colors.black87 : Colors.white);
    final labelColor = selected ? cs.primary : (isLight ? Colors.black54 : Colors.white60);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Center(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: iconColor),
                  SizedBox(height: selected ? 4 : 0),
                  selected
                      ? Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.0,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ================= AI HOME ================= */

class _AiHomePane extends StatefulWidget {
  final String userId;
  const _AiHomePane({super.key, required this.userId});

  @override
  State<_AiHomePane> createState() => _AiHomePaneState();
}

class _AiHomePaneState extends State<_AiHomePane> {
  final _askCtrl = TextEditingController();

  @override
  void dispose() {
    _askCtrl.dispose();
    super.dispose();
  }

  static Widget _bullet(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 7, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Color _providerColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'openai':
        return const Color(0xFFFF4DA6);
      case 'anthropic':
        return const Color(0xFFFF9F1C);
      case 'google':
        return const Color(0xFF42A5F5);
      case 'meta':
      case 'meta-llama':
        return const Color(0xFF00BFA6);
      case 'mistral':
      case 'mistralai':
        return const Color(0xFF7E57C2);
      case 'xai':
      case 'grok':
        return const Color(0xFFE53935);
      case 'deepseek':
        return const Color(0xFF7FA8FF);
      case 'qwen':
        return const Color(0xFF6BE4FF);
      case 'cohere':
        return const Color(0xFF8BFFB3);
      case 'openrouter':
        return const Color(0xFF90A4AE);
      case 'minimax':
        return const Color(0xFF63E6BE);
      case 'tencent':
        return const Color(0xFF4DABF7);
      case 'prunaai':
        return const Color(0xFFFFB04D);
      case 'kling':
        return const Color(0xFFD66BFF);
      case 'bytedance':
        return const Color(0xFFFF6B6B);
      default:
        return const Color(0xFF90A4AE);
    }
  }

  Future<void> _openModelsHub() async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelsExplorePage(
          initialCategory: 'chat',
          onModelTap: (model) => _openModelInfo(model),
          onMediaModelTap: (mediaModel) => _openDedicatedMediaPage(mediaModel),
        ),
      ),
    );
  }

  Future<void> _openMediaExplore(String categoryKey) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelsExplorePage(
          initialCategory: categoryKey,
          onModelTap: (model) => _openModelInfo(model),
          onMediaModelTap: (mediaModel) => _openDedicatedMediaPage(mediaModel),
        ),
      ),
    );
  }

  Future<void> _openModelInfo(CuratedModel model) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelInfoPage(
          model: model,
          onStartChat: () async {
            Navigator.of(context).pop();
            await _startCuratedChat(model);
          },
          onOpenHistory: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ModelHistoryPage(
                  model: model,
                  loadHistory: _loadHistoryForModel,
                  onOpenHistoryItem: (item) async {
                    final store = SqlChatStore();
                    final chat = await store.getChat(item.id);
                    if (!mounted || chat == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          userId: widget.userId,
                          chatId: chat.id,
                          chatName: chat.name,
                        ),
                      ),
                    );
                  },
                  onRename: (id, title) => SqlChatStore().rename(id, title),
                  onDelete: (id) => SqlChatStore().deleteChat(id),
                  onTogglePin: (id) => SqlChatStore().toggleStar(id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openDedicatedMediaPage(CuratedMediaModel mediaModel) async {
    if (!mounted) return;

    switch (mediaModel.category) {
      case MediaCategory.image:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageGeneratorPage(initialModel: mediaModel),
          ),
        );
        break;
      case MediaCategory.video:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoGeneratorPage(initialModel: mediaModel),
          ),
        );
        break;
      case MediaCategory.audio:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AudioGeneratorPage(initialModel: mediaModel),
          ),
        );
        break;
    }
  }

  Future<void> _openMediaInfo(CuratedMediaModel mediaModel) async {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModelInfoPage(
          mediaModel: mediaModel,
          onGenerate: () async { Navigator.of(context).pop(); await _openDedicatedMediaPage(mediaModel); },
        ),
      ),
    );
  }

  Future<void> _startMediaChat(CuratedMediaModel mediaModel) async {
    final store = SqlChatStore();

    final id = await store.createChat(
      name: mediaModel.name,
      preset: {
        'kind': 'media',
        'category': mediaModel.categoryKey,
        'modelId': mediaModel.id,
        'modelName': mediaModel.name,
        'provider': mediaModel.provider,
        'description': mediaModel.description,
      },
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userId: widget.userId,
          chatId: id,
          chatName: mediaModel.name,
        ),
      ),
    );
  }

  Future<void> _startCuratedChat(CuratedModel model) async {
    final store = SqlChatStore();

    final id = await store.createChat(
      name: model.displayName,
      preset: {
        'kind': 'free',
        'modelId': model.id,
        'modelName': model.displayName,
        'provider': model.provider,
        'description': model.description,
      },
    );

    await ModelPrefs.setSelected(model.id);
    GPMaiBrain.model = model.id;

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userId: widget.userId,
          chatId: id,
          chatName: model.displayName,
        ),
      ),
    );
  }

  Future<void> _startQuickChat() async {
    final prompt = _askCtrl.text.trim();
    final store = SqlChatStore();

    final selected = await ModelPrefs.getSelected();
    final modelId = (selected != null && selected.trim().contains('/'))
        ? selected.trim()
        : 'openai/gpt-5.2';

    final model = findCuratedModelById(modelId) ?? findCuratedModelById('openai/gpt-5.2')!;

    final id = await store.createChat(
      name: prompt.isEmpty ? model.displayName : prompt,
      preset: {
        'kind': 'free',
        'modelId': model.id,
        'modelName': model.displayName,
        'provider': model.provider,
        'description': model.description,
      },
    );

    if (prompt.isNotEmpty) {
      await store.addMessage(
        chatId: id,
        role: 'user',
        text: prompt,
      );
      _askCtrl.clear();
    }

    await ModelPrefs.setSelected(model.id);
    GPMaiBrain.model = model.id;

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userId: widget.userId,
          chatId: id,
          chatName: model.displayName,
        ),
      ),
    );
  }

  Future<List<ModelHistoryItem>> _loadHistoryForModel(String modelId) async {
    final store = SqlChatStore();
    final chats = await store.getChatsByModel(modelId);

    return chats
        .map(
          (c) => ModelHistoryItem(
            id: c.id,
            title: c.name,
            subtitle: null,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(c.lastAt),
            pinned: c.starred,
          ),
        )
        .toList();
  }

  Widget _modelsRow({
    required String title,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final items = mixedOfficialModels.take(80).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(
              onPressed: _openModelsHub,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final m = items[i];
              final brand = ProviderBranding.resolve(provider: m.provider, modelId: m.id, displayName: m.displayName);
              final c = brand.accent;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openModelInfo(m),
                child: Container(
                  width: 196,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: brand.vividGradient(Theme.of(context).brightness)),
                    border: Border.all(
                      color: brand.border(Theme.of(context).brightness),
                    ),
                    boxShadow: isLight ? null : [BoxShadow(color: c.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: brand.iconFill(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brand.border(Theme.of(context).brightness)),
                        ),
                        child: Center(
                          child: Text(
                            brand.initials(m.provider),
                            style: TextStyle(
                              color: c,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.provider,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: brand.mutedText(Theme.of(context).brightness),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m.popular ? 'Popular' : 'Official',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mediaModelsRow({
    required String title,
    required List<CuratedMediaModel> items,
    required String categoryKey,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => _openMediaExplore(categoryKey),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 98,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final m = items[i];
              final brand = ProviderBranding.resolve(provider: m.provider, modelId: m.id, displayName: m.name);
              final c = brand.accent;

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openDedicatedMediaPage(m),
                child: Container(
                  width: 224,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: brand.vividGradient(Theme.of(context).brightness)),
                    border: Border.all(
                      color: brand.border(Theme.of(context).brightness),
                    ),
                    boxShadow: isLight ? null : [BoxShadow(color: c.withOpacity(.10), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: brand.iconFill(Theme.of(context).brightness),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: brand.border(Theme.of(context).brightness)),
                        ),
                        child: Icon(
                          _mediaIconFor(m.category),
                          size: 20,
                          color: c,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.provider,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: brand.mutedText(Theme.of(context).brightness),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m.badge ?? m.categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: c,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static IconData _mediaIconFor(MediaCategory category) {
    switch (category) {
      case MediaCategory.image:
        return Icons.image_rounded;
      case MediaCategory.audio:
        return Icons.graphic_eq_rounded;
      case MediaCategory.video:
        return Icons.videocam_rounded;
    }
  }

  String _providerInitials(String provider) {
    final parts = provider.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _openPersonasAll() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PersonasAllPage(userId: widget.userId)),
    );
  }

  Future<void> _openBuiltInPersona(PersonaDefinition persona) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PersonaDetailPage.builtIn(userId: widget.userId, builtIn: persona)),
    );
  }

  Widget _personasRow({required String title}) {
    final items = kBuiltInPersonas.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const Spacer(),
            TextButton(onPressed: _openPersonasAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _openBuiltInPersona(p),
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(colors: [p.accent.withOpacity(.18), Colors.transparent]),
                    border: Border.all(color: Colors.white.withOpacity(.08)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: p.accent.withOpacity(.16),
                        border: Border.all(color: p.accent.withOpacity(.45)),
                      ),
                      child: Icon(p.icon, color: p.accent, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(p.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.35)),
                    ])),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _specialTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surfaceContainerHighest.withOpacity(.35),
          border: Border.all(color: cs.onSurface.withOpacity(.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(.18),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? Colors.black87 : Colors.white70;
    final fieldFill = isLight ? Colors.black.withOpacity(.04) : Colors.white.withOpacity(.05);
    final border = isLight ? Colors.black12 : Colors.white12;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          const SizedBox(height: 8),
          const Center(child: _BobbingOrb()),
          const SizedBox(height: 10),
          Center(
            child: _AnimatedGradientFloatText(
              'GPMai',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'What would you like to build today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: textColor,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: fieldFill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _askCtrl,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _startQuickChat(),
              decoration: const InputDecoration(
                hintText: 'Ask anything...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(16, 14, 16, 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _startQuickChat,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Start'),
            ),
          ),
          const SizedBox(height: 22),

          _modelsRow(title: 'Official Models'),
          const SizedBox(height: 22),

          _mediaModelsRow(
            title: 'Image Models',
            items: CuratedMediaCatalog.featuredImageModels,
            categoryKey: 'image',
          ),
          const SizedBox(height: 22),

          _mediaModelsRow(
            title: 'Audio Models',
            items: CuratedMediaCatalog.featuredAudioModels,
            categoryKey: 'audio',
          ),
          const SizedBox(height: 22),

          _mediaModelsRow(
            title: 'Video Models',
            items: CuratedMediaCatalog.featuredVideoModels,
            categoryKey: 'video',
          ),
          const SizedBox(height: 22),

          _personasRow(title: 'Expert Personas'),
          const SizedBox(height: 22),

          Text(
            'Quick tools',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          _specialTile(
            context,
            icon: Icons.record_voice_over_rounded,
            title: 'Hands-free Voice',
            color: const Color(0xFF42A5F5),
            onTap: () => _openMediaExplore('audio'),
          ),
          const SizedBox(height: 10),
          _specialTile(
            context,
            icon: Icons.image_rounded,
            title: 'Image Generator',
            color: const Color(0xFFFF4DA6),
            onTap: () => _openMediaExplore('image'),
          ),
          const SizedBox(height: 10),
          _specialTile(
            context,
            icon: Icons.travel_explore_rounded,
            title: 'Web Searcher',
            color: const Color(0xFF7E57C2),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DeepSearchPage(userId: widget.userId)),
              );
            },
          ),
        ],
      ),
    );
  }
}

/* ---- Animated text widgets ---- */

class _AnimatedGradientFloatText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _AnimatedGradientFloatText(this.text, {required this.style});

  @override
  State<_AnimatedGradientFloatText> createState() => _AnimatedGradientFloatTextState();
}

class _AnimatedGradientFloatTextState extends State<_AnimatedGradientFloatText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value * 2 * math.pi;
        final dy = math.sin(t) * 8.0;
        final scale = 1.0 + math.sin(t + math.pi / 2) * 0.06;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Text(
              widget.text,
              style: widget.style.copyWith(
                color: color,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black12,
                    offset: Offset(0, isDark ? 2 : 1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BobbingOrb extends StatefulWidget {
  const _BobbingOrb();

  @override
  State<_BobbingOrb> createState() => _BobbingOrbState();
}

class _BobbingOrbState extends State<_BobbingOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final dy = (_c.value - 0.5) * 8.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset('assets/ai_orb.png', height: 120),
          ),
        );
      },
    );
  }
}

/* ================= ALL MODELS ================= */

List<Color> _brandGradient(Color accent) => [accent.withOpacity(.26), accent.withOpacity(.14), const Color(0xFF090B10)];


String _resolveBotSystemPrompt(String id) {
  final persona = personaById(id);
  return (persona?.basePrompt ?? '').trim();
}
class _AllModelsPane extends StatelessWidget {
  final String userId;
  const _AllModelsPane({super.key, required this.userId});

  Future<void> _createLocalChat({
    required BuildContext context,
    required String chatTitle,
    Map<String, dynamic>? preset,
  }) async {
    final store = SqlChatStore();
    final id = await store.createChat(name: chatTitle, preset: preset);

    String? botSystem;
    final kind = preset?['kind'] as String?;
    if (kind == 'bot') {
      final botId = preset?['id'] as String?;
      botSystem = _resolveBotSystemPrompt(botId ?? '');
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a1, __) => FadeTransition(
          opacity: a1,
          child: ChatPage(
            userId: userId,
            chatId: id,
            chatName: chatTitle,
            systemPrompt: botSystem,
          ),
        ),
      ),
    );
  }

  Future<void> _createMediaChatAndOpen({
    required BuildContext context,
    required CuratedMediaModel mediaModel,
  }) async {
    final store = SqlChatStore();
    final id = await store.createChat(
      name: mediaModel.name,
      preset: {
        'kind': 'media',
        'category': mediaModel.categoryKey,
        'modelId': mediaModel.id,
        'modelName': mediaModel.name,
        'provider': mediaModel.provider,
        'description': mediaModel.description,
      },
    );

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          userId: userId,
          chatId: id,
          chatName: mediaModel.name,
        ),
      ),
    );
  }

  Future<void> _openMediaExplore(
    BuildContext context,
    String categoryKey,
  ) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ModelsExplorePage(
          initialCategory: categoryKey,
          onModelTap: (_) {},
          onMediaModelTap: (mediaModel) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ModelInfoPage(
                  mediaModel: mediaModel,
                  onGenerate: () async {
                    Navigator.of(context).pop();
                    await _createMediaChatAndOpen(
                      context: context,
                      mediaModel: mediaModel,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showOrbInfo(BuildContext context) async {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor = isLight ? Colors.black87 : Colors.white70;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Live Screen Reader (Orb)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AiHomePaneState._bullet("Double-tap the orb to open a full chat.", textColor),
                    _AiHomePaneState._bullet("Hold the orb to open the compact box.", textColor),
                    _AiHomePaneState._bullet("Ask about whatâ€™s on screen to get a short, relevant answer.", textColor),
                    _AiHomePaneState._bullet("No continuous monitoring â€” only after you ask.", textColor),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.check_rounded),
                label: const Text("Got it"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bots = <_Preset>[
      _Preset('Relationship Doctor', 'Your 24/7 wingman and love consultant!', Icons.favorite, {'kind': 'bot', 'id': 'relationship_doctor'}),
      _Preset('Spy', 'Look up people and stay updated!', Icons.visibility, {'kind': 'bot', 'id': 'spy'}),
      _Preset('Lawyer', 'General legal guidance bot', Icons.balance, {'kind': 'bot', 'id': 'lawyer'}),
      _Preset('Astrolog', 'Your personal astrologer', Icons.auto_awesome, {'kind': 'bot', 'id': 'astrolog'}),
      _Preset('Personal Trainer', 'Coach + motivation', Icons.fitness_center, {'kind': 'bot', 'id': 'trainer'}),
      _Preset('Doctor', 'Friendly health info (not medical advice)', Icons.local_hospital, {'kind': 'bot', 'id': 'doctor'}),
      _Preset('Writer', 'Any-type writer & rewriter', Icons.edit, {'kind': 'bot', 'id': 'writer'}),
    ];

    final models = <_Preset>[
      _Preset(
        'OpenAI GPT-4o Mini',
        'Fast, cheap multimodal (recommended)',
        Icons.bolt,
        {'kind': 'model', 'id': 'openai/gpt-5-mini'},
      ),
      _Preset(
        'OpenAI GPT-4o',
        'Multimodal flagship',
        Icons.auto_awesome,
        {'kind': 'model', 'id': 'openai/gpt-5.2'},
      ),
      _Preset(
        'OpenAI o3',
        'Dense reasoning',
        Icons.psychology,
        {'kind': 'model', 'id': 'openai/o3'},
      ),
      _Preset(
        'OpenAI o3 Mini',
        'Reasoning, faster tradeoff',
        Icons.psychology_alt,
        {'kind': 'model', 'id': 'openai/o3-mini'},
      ),
    ];

    final special = <_PresetAction>[
      _PresetAction(
        'Hands-free Voice',
        'Voice-first realtime assistant',
        Icons.record_voice_over,
        () => _openMediaExplore(context, 'audio'),
      ),
      _PresetAction(
        'Image Generator',
        'Text â†’ images',
        Icons.image,
        () => _openMediaExplore(context, 'image'),
      ),
      _PresetAction(
        'Live Screen Reader (Orb)',
        'Ask about whatâ€™s on screen',
        Icons.smart_toy,
        () => _showOrbInfo(context),
      ),
      _PresetAction(
        'Web Searcher',
        'Live web + citations',
        Icons.travel_explore,
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => DeepSearchPage(userId: userId))),
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text('AI Bots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...bots.map(
            (p) => _PresetRow(
              preset: p,
              showChatButton: true,
              onTap: () => _createLocalChat(context: context, chatTitle: p.title, preset: p.preset),
            ),
          ),
          const SizedBox(height: 18),
          const Text('AI Models', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...models.map(
            (p) => _PresetRow(
              preset: p,
              showChatButton: false,
              onTap: () async {
                final id = p.preset['id'] as String;
                await ModelPrefs.setSelected(id);
                GPMaiBrain.model = id;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Model set: ${p.title}')),
                );
                await _createLocalChat(context: context, chatTitle: p.title, preset: p.preset);
              },
            ),
          ),
          const SizedBox(height: 18),
          const Text('Special Models', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...special.map((p) => _PresetActionRow(action: p)),
        ],
      ),
    );
  }
}

class _Preset {
  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, dynamic> preset;
  const _Preset(this.title, this.subtitle, this.icon, this.preset);
}

class _PresetAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _PresetAction(this.title, this.subtitle, this.icon, this.onTap);
}

class _PresetRow extends StatelessWidget {
  final _Preset preset;
  final VoidCallback onTap;
  final bool showChatButton;

  const _PresetRow({
    required this.preset,
    required this.onTap,
    required this.showChatButton,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLight ? Colors.black.withOpacity(.06) : const Color(0xFFEFF3FF),
          child: Icon(preset.icon, color: isLight ? Colors.black87 : const Color(0xFF246BFD)),
        ),
        title: Text(preset.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(preset.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: showChatButton
            ? ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('CHAT'),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _PresetActionRow extends StatelessWidget {
  final _PresetAction action;
  const _PresetActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLight ? Colors.black.withOpacity(.06) : const Color(0xFFEFF3FF),
          child: Icon(action.icon, color: isLight ? Colors.black87 : const Color(0xFF246BFD)),
        ),
        title: Text(action.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(action.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: action.onTap,
      ),
    );
  }
}

/* ================= INBOX ================= */

class _InboxPane extends StatefulWidget {
  final String userId;
  const _InboxPane({super.key, required this.userId});

  @override
  State<_InboxPane> createState() => _InboxPaneState();
}

class _InboxPaneState extends State<_InboxPane> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);

  bool _selectionMode = false;
  final Set<String> _selected = <String>{};
  List<String> _visibleIds = [];

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _newChat(BuildContext context) async {
    final id = await SqlChatStore().createChat(name: 'New Chat');
    if (!context.mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, a1, __) => FadeTransition(
          opacity: a1,
          child: ChatPage(userId: widget.userId, chatId: id, chatName: 'New Chat'),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete selected?"),
        content: Text("Delete ${_selected.length} chat(s) locally."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok != true) return;

    final store = SqlChatStore();
    for (final chatId in _selected) {
      await store.deleteChat(chatId);
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = SqlChatStore();
    final isLight = Theme.of(context).brightness == Brightness.light;

    Widget list(bool starredOnly) {
      return StreamBuilder<List<Chat>>(
        stream: store.watchChats(starredOnly: starredOnly),
        builder: (_, snap) {
          final items = snap.data ?? const <Chat>[];
          _visibleIds = items.map((c) => c.id as String).toList();

          if (items.isEmpty) {
            return const Center(child: Text("Nothing here yet."));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final d = items[i];
              final String id = d.id;
              final name = d.name;
              final starred = d.starred;
              final selected = _selected.contains(id);

              Future<void> toggleStar() => store.toggleStar(id);

              return GestureDetector(
                onLongPress: () {
                  setState(() {
                    _selectionMode = true;
                    _selected.add(id);
                  });
                },
                child: Card(
                  child: ListTile(
                    leading: _selectionMode
                        ? Checkbox(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(id);
                                } else {
                                  _selected.remove(id);
                                }
                              });
                            },
                          )
                        : Icon(
                            starred ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
                            color: starred ? const Color(0xFF00B8FF) : (isLight ? Colors.black87 : null),
                          ),
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: _selectionMode
                        ? null
                        : IconButton(
                            icon: Icon(
                              starred ? Icons.star_rounded : Icons.star_border_rounded,
                              color: starred ? cs.primary : (isLight ? Colors.black45 : Colors.white60),
                            ),
                            onPressed: toggleStar,
                          ),
                    onTap: () {
                      if (_selectionMode) {
                        setState(() {
                          selected ? _selected.remove(id) : _selected.add(id);
                        });
                        return;
                      }
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 280),
                          pageBuilder: (_, a1, __) => FadeTransition(
                            opacity: a1,
                            child: ChatPage(userId: widget.userId, chatId: id, chatName: name),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Text("Inbox", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_selectionMode) ...[
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectionMode = false;
                      _selected.clear();
                    });
                  },
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectionMode = true;
                      _selected
                        ..clear()
                        ..addAll(_visibleIds);
                    });
                  },
                  child: const Text("Select all"),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text("Delete"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () => _newChat(context),
                  icon: const Icon(Icons.add_comment_rounded),
                  label: const Text("New Chat"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ],
          ),
        ),
        TabBar(
          controller: _tc,
          labelColor: cs.primary,
          unselectedLabelColor: isLight ? Colors.black54 : Colors.white60,
          tabs: const [Tab(text: "History"), Tab(text: "Starred")],
        ),
        Expanded(child: TabBarView(controller: _tc, children: [list(false), list(true)])),
      ],
    );
  }
}

