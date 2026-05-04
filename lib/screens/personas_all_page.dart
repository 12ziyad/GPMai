import 'package:flutter/material.dart';

import '../prompts/bots_prompts.dart';
import '../services/custom_personas_service.dart';
import 'persona_builder_page.dart';
import 'persona_detail_page.dart';

class PersonasAllPage extends StatefulWidget {
  final String userId;
  const PersonasAllPage({super.key, required this.userId});

  @override
  State<PersonasAllPage> createState() => _PersonasAllPageState();
}

class _PersonasAllPageState extends State<PersonasAllPage> {
  List<CustomPersona> _custom = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await CustomPersonasService.all();
    if (mounted) setState(() => _custom = all);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<CustomPersona>(MaterialPageRoute(builder: (_) => const PersonaBuilderPage()));
    if (created == null) return;
    await _load();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonaDetailPage.custom(userId: widget.userId, custom: created)));
  }



  Future<void> _showCustomActions(CustomPersona persona) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: Icon(persona.pinned ? Icons.push_pin : Icons.push_pin_outlined), title: Text(persona.pinned ? 'Unpin' : 'Pin'), onTap: () => Navigator.pop(context, 'pin')), 
            ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete'), onTap: () => Navigator.pop(context, 'delete')),
          ],
        ),
      ),
    );
    if (action == 'pin') {
      await CustomPersonasService.togglePinned(persona.id);
      await _load();
      return;
    }
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete custom persona?'),
          content: Text('Delete ${persona.name}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) {
        await CustomPersonasService.delete(persona.id);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final custom = [..._custom]..sort((a,b){ if (a.pinned != b.pinned) return a.pinned ? -1 : 1; return b.updatedAt.compareTo(a.updatedAt); });
    final items = [...custom.map((e) => _CardItem.custom(e)), ...kBuiltInPersonas.map((e) => _CardItem.builtIn(e))];
    return Scaffold(
      backgroundColor: isLight ? const Color(0xFFF5F7FB) : Colors.black,
      appBar: AppBar(title: const Text('Expert Personas')), 
      body: Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: .78,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(26),
                onLongPress: item.custom != null ? () => _showCustomActions(item.custom!) : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.custom != null ? PersonaDetailPage.custom(userId: widget.userId, custom: item.custom!) : PersonaDetailPage.builtIn(userId: widget.userId, builtIn: item.builtIn!))),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(colors: [item.accent.withOpacity(isLight ? .14 : .18), isLight ? Colors.white : Colors.transparent]),
                    border: Border.all(color: item.accent.withOpacity(isLight ? .24 : .18)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (item.custom != null) Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: item.accent.withOpacity(.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: item.accent.withOpacity(.35)),
                        ),
                        child: Text(item.custom!.pinned ? 'Custom • Pinned' : 'Custom', style: TextStyle(color: item.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ]),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: item.accent.withOpacity(.16),
                        border: Border.all(color: item.accent.withOpacity(.5)),
                      ),
                      child: Center(child: item.emoji != null ? Text(item.emoji!, style: const TextStyle(fontSize: 28)) : Icon(item.icon, color: item.accent, size: 32)),
                    ),
                    const SizedBox(height: 12),
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, height: 1.12)),
                    const SizedBox(height: 8),
                    Expanded(child: Text(item.subtitle, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: isLight ? const Color(0xFF667085) : Colors.white70, height: 1.35))),
                  ]),
                ),
              );
            },
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Persona'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardItem {
  final PersonaDefinition? builtIn;
  final CustomPersona? custom;
  const _CardItem._(this.builtIn, this.custom);
  factory _CardItem.builtIn(PersonaDefinition p) => _CardItem._(p, null);
  factory _CardItem.custom(CustomPersona p) => _CardItem._(null, p);
  String get title => custom?.name ?? builtIn!.title;
  String get subtitle => custom?.description ?? builtIn!.subtitle;
  IconData get icon => custom?.icon ?? builtIn!.icon;
  String? get emoji => custom?.emoji;
  Color get accent => custom?.accent ?? builtIn!.accent;
}
