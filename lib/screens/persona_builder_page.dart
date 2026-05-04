import 'package:flutter/material.dart';

import '../services/custom_personas_service.dart';

class PersonaBuilderPage extends StatefulWidget {
  const PersonaBuilderPage({super.key});

  @override
  State<PersonaBuilderPage> createState() => _PersonaBuilderPageState();
}

class _PersonaBuilderPageState extends State<PersonaBuilderPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _behavior = TextEditingController();
  final _greeting = TextEditingController();
  final _emoji = TextEditingController();

  IconData? _icon = Icons.psychology_alt_rounded;
  Color _accent = const Color(0xFF12C6FF);
  bool _saving = false;
  int _savingStage = 0;

  static const _accentOptions = [
    Color(0xFF12C6FF),
    Color(0xFF8D63FF),
    Color(0xFF2CCB9B),
    Color(0xFFFF6B8A),
    Color(0xFF4E7BFF),
    Color(0xFF4BD6C3),
  ];

  static const _iconOptions = [
    Icons.psychology_alt_rounded,
    Icons.favorite_rounded,
    Icons.fitness_center_rounded,
    Icons.gavel_rounded,
    Icons.auto_awesome_rounded,
    Icons.edit_rounded,
    Icons.school_rounded,
    Icons.workspace_premium_rounded,
  ];

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _behavior.dispose();
    _greeting.dispose();
    _emoji.dispose();
    super.dispose();
  }

  String get _savingText {
    switch (_savingStage) {
      case 1:
        return 'Forging persona identity...';
      case 2:
        return 'Locking in behavior...';
      case 3:
        return 'Preparing first impression...';
      default:
        return 'Creating persona...';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _savingStage = 1;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _savingStage = 2);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => _savingStage = 3);
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    final now = DateTime.now();
    final persona = CustomPersona(
      id: 'custom_${now.microsecondsSinceEpoch}',
      name: _name.text.trim(),
      description: _description.text.trim(),
      behaviorPrompt: _behavior.text.trim(),
      greeting: _greeting.text.trim(),
      emoji: _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
      iconCodePoint: _emoji.text.trim().isEmpty ? _icon?.codePoint : null,
      accentValue: _accent.value,
      createdAt: now,
      updatedAt: now,
    );
    await CustomPersonasService.save(persona);
    if (!mounted) return;
    Navigator.pop(context, persona);
  }

  InputDecoration _dec(BuildContext context, String label, String hint) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF0B1118),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? const Color(0xFFF5F7FB) : Colors.black;
    final titleColor = isLight ? const Color(0xFF101828) : Colors.white;
    final subColor = isLight ? const Color(0xFF667085) : Colors.white70;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: const Text('Create Persona'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _accent.withOpacity(isLight ? .24 : .20)),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _accent.withOpacity(isLight ? .15 : .18),
                      _accent.withOpacity(isLight ? .05 : .08),
                      isLight ? Colors.white : const Color(0xFF0F141B),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Build a serious persona',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: titleColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a role that feels premium, deliberate, and worth coming back to. The stronger the setup, the stronger the conversation feels.',
                      style: TextStyle(color: subColor, height: 1.45),
                    ),
                    const SizedBox(height: 18),
                    _PreviewCard(
                      accent: _accent,
                      icon: _icon,
                      emoji: _emoji.text.trim().isEmpty ? null : _emoji.text.trim(),
                      name: _name.text.trim().isEmpty ? 'Personal Gym Coach' : _name.text.trim(),
                      description: _description.text.trim().isEmpty
                          ? 'A role-first helper that feels focused, human, and consistent in chat.'
                          : _description.text.trim(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                accent: _accent,
                title: 'Identity',
                subtitle: 'Set the name, icon, and the first impression users will remember.',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      maxLength: 50,
                      decoration: _dec(context, 'Persona name', 'Personal Gym Coach'),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Give it a stronger name' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emoji,
                      maxLength: 4,
                      decoration: _dec(context, 'Optional emoji', '💪'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _iconOptions
                          .map(
                            (icon) => InkWell(
                              onTap: () => setState(() => _icon = icon),
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: _accent.withOpacity(.12),
                                  border: Border.all(color: (_icon == icon ? _accent : (isLight ? Colors.black12 : Colors.white24))),
                                ),
                                child: Icon(icon, color: _accent),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: _accentOptions
                          .map(
                            (c) => InkWell(
                              onTap: () => setState(() => _accent = c),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: c,
                                  border: Border.all(
                                    color: _accent == c ? (isLight ? const Color(0xFF101828) : Colors.white) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                accent: _accent,
                title: 'Role & Purpose',
                subtitle: 'Explain exactly what this persona is for and how users should rely on it.',
                child: TextFormField(
                  controller: _description,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 320,
                  onChanged: (_) => setState(() {}),
                  decoration: _dec(context, 'Description', 'Describe what this persona helps with and what kind of support or output it should provide.'),
                  validator: (v) => (v == null || v.trim().length < 20) ? 'Make the purpose more specific' : null,
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                accent: _accent,
                title: 'Behavior Rules',
                subtitle: 'This is the core. Lock the tone, boundaries, and role consistency here.',
                child: TextFormField(
                  controller: _behavior,
                  minLines: 8,
                  maxLines: 12,
                  maxLength: 3000,
                  decoration: _dec(context, 'Behavior prompt', 'Example: You are a disciplined but supportive gym coach. Stay focused on workouts, consistency, recovery, motivation, and realistic plans. Respond naturally, briefly, and like a real coach in chat.'),
                  validator: (v) => (v == null || v.trim().length < 40) ? 'Give this persona stronger behavior rules' : null,
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                accent: _accent,
                title: 'Opening Message',
                subtitle: 'The first thing your persona says should instantly feel on-brand.',
                child: TextFormField(
                  controller: _greeting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: _dec(context, 'Greeting message', 'Hey — I’m your coach here. Tell me your goal and I’ll help you build a plan that actually fits your life.'),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Add a stronger first message' : null,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      _accent.withOpacity(isLight ? .15 : .22),
                      _accent.withOpacity(isLight ? .05 : .08),
                      isLight ? Colors.white : const Color(0xFF0F141B),
                    ],
                  ),
                  border: Border.all(color: _accent.withOpacity(.22)),
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What happens after you create it?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: titleColor)),
                    const SizedBox(height: 10),
                    Text(
                      'We save the persona, lock in its behavior, and open its overview so you can start chatting right away.',
                      style: TextStyle(color: subColor, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(_saving ? _savingText : 'Create Persona'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final Color accent;
  final IconData? icon;
  final String? emoji;
  final String name;
  final String description;

  const _PreviewCard({
    required this.accent,
    required this.icon,
    required this.emoji,
    required this.name,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isLight ? const Color(0xFF101828) : Colors.white;
    final subColor = isLight ? const Color(0xFF667085) : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: isLight ? Colors.white.withOpacity(.78) : const Color(0xFF0B1118),
        border: Border.all(color: accent.withOpacity(.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: accent.withOpacity(.16),
              border: Border.all(color: accent.withOpacity(.45)),
            ),
            child: Center(
              child: emoji != null && emoji!.trim().isNotEmpty
                  ? Text(emoji!, style: const TextStyle(fontSize: 26))
                  : Icon(icon, color: accent, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: titleColor)),
                const SizedBox(height: 6),
                Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: subColor, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Color accent;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({required this.accent, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = isLight ? const Color(0xFF101828) : Colors.white;
    final subColor = isLight ? const Color(0xFF667085) : Colors.white70;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? Colors.white : const Color(0xFF0F141B),
        border: Border.all(color: isLight ? Colors.black12 : Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? .04 : .12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: titleColor)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: subColor, height: 1.45)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
