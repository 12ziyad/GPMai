import 'package:flutter/material.dart';

import '../prompts/bots_prompts.dart';
import '../services/custom_personas_service.dart';
import '../services/persona_prefs.dart';
import '../services/sql_chat_store.dart';
import 'chat_page.dart';

class PersonaDetailPage extends StatefulWidget {
  final String userId;
  final PersonaDefinition? builtIn;
  final CustomPersona? custom;

  const PersonaDetailPage.builtIn({super.key, required this.userId, required PersonaDefinition this.builtIn}) : custom = null;
  const PersonaDetailPage.custom({super.key, required this.userId, required CustomPersona this.custom}) : builtIn = null;

  @override
  State<PersonaDetailPage> createState() => _PersonaDetailPageState();
}

class _PersonaDetailPageState extends State<PersonaDetailPage> {
  final _styleCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  String get _id => widget.custom?.id ?? widget.builtIn!.id;
  String get _name => widget.custom?.name ?? widget.builtIn!.title;
  String get _subtitle => widget.custom?.description ?? widget.builtIn!.subtitle;
  String get _overview => widget.custom?.description ?? widget.builtIn!.overview;
  String get _greeting => widget.custom?.greeting ?? widget.builtIn!.greeting;
  Color get _accent => widget.custom?.accent ?? widget.builtIn!.accent;
  IconData? get _icon => widget.custom?.icon ?? widget.builtIn!.icon;
  String? get _emoji => widget.custom?.emoji;
  List<String> get _chips => widget.builtIn?.tryAsking ?? <String>['Tell me what you can help with.', 'How should I use you best?', 'Start with a quick introduction.'];

  @override
  void initState() {
    super.initState();
    PersonaPrefs.getStyle(_id).then((v) {
      if (mounted) _styleCtrl.text = v;
    });
  }

  @override
  void dispose() {
    _styleCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _saveStyle() async {
    setState(() => _saving = true);
    await PersonaPrefs.saveStyle(_id, _styleCtrl.text);
    _focus.unfocus();
    if (mounted) setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Response style saved')));
    }
  }

  Future<void> _startChat({String? firstUserMessage}) async {
    final style = await PersonaPrefs.getStyle(_id);
    final store = SqlChatStore();
    final isCustom = widget.custom != null;
    final preset = {
      'kind': isCustom ? 'custom_persona' : 'persona',
      'personaId': _id,
      'personaName': _name,
      'modelId': 'openai/gpt-5-mini',
      'modelName': _name,
      'responseStyle': style,
      if (isCustom) 'customPersona': widget.custom!.toJson(),
    };
    final chatId = await store.createChat(name: firstUserMessage?.trim().isNotEmpty == true ? firstUserMessage!.trim() : _name, preset: preset);
    
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatPage(
        userId: widget.userId,
        chatId: chatId,
        chatName: _name,
        welcome: _greeting,
        seedUserText: firstUserMessage,
        systemPrompt: widget.custom != null
            ? buildCustomPersonaSystemPrompt(
                name: widget.custom!.name,
                description: widget.custom!.description,
                behaviorPrompt: widget.custom!.behaviorPrompt,
                responseStyle: style,
              )
            : buildPersonaSystemPrompt(_id, customStyle: style),
      ),
    ));
  }

  Future<void> _openHistory() async {
    final store = SqlChatStore();
    final all = await store.watchChats().first;
    final filtered = all.where((c) => (c.presetJson ?? '').contains('"personaId":"$_id"')).toList();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PersonaHistoryPage(personaName: _name, chats: filtered, userId: widget.userId, accent: _accent)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _openHistory, icon: const Icon(Icons.history_rounded), label: const Text('History'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton.icon(onPressed: () => _startChat(), icon: const Icon(Icons.chat_bubble_rounded), label: const Text('New Chat'))),
        ]),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(colors: [_accent.withOpacity(.18), Colors.transparent]),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: _accent.withOpacity(.16),
                      border: Border.all(color: _accent.withOpacity(.5)),
                    ),
                    child: Center(child: _emoji != null ? Text(_emoji!, style: const TextStyle(fontSize: 28)) : Icon(_icon, color: _accent, size: 32)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(_subtitle, style: const TextStyle(color: Colors.white70, height: 1.35)),
                  ])),
                ]),
                const SizedBox(height: 18),
                Text(_overview, style: const TextStyle(color: Colors.white70, height: 1.45)),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF0F141B), border: Border.all(color: Colors.white.withOpacity(.08))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Response Style', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                const Text('Refine how this persona talks without changing who it is. Example: be more gentle, slower, direct, practical, or more emotionally supportive.', style: TextStyle(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 14),
                TextField(
                  controller: _styleCtrl,
                  focusNode: _focus,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Be more calm and supportive. Keep replies shorter and more chat-like.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _saving ? null : _saveStyle, child: Text(_saving ? 'Saving...' : 'Save')),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF0F141B), border: Border.all(color: Colors.white.withOpacity(.08))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Try asking', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _chips.map((e) => ActionChip(label: Text(e), onPressed: () => _startChat(firstUserMessage: e))).toList(),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaHistoryPage extends StatefulWidget {
  final String personaName;
  final List<Chat> chats;
  final String userId;
  final Color accent;
  const _PersonaHistoryPage({required this.personaName, required this.chats, required this.userId, required this.accent});

  @override
  State<_PersonaHistoryPage> createState() => _PersonaHistoryPageState();
}

class _PersonaHistoryPageState extends State<_PersonaHistoryPage> {
  final Set<String> _selected = <String>{};
  bool _selectionMode = false;
  List<Chat> get _items => [...widget.chats]..sort((a, b) => b.lastAt.compareTo(a.lastAt));

  void _toggleSelection(String id) {
    setState(() {
      _selectionMode = true;
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  Future<void> _confirmDelete(List<Chat> chats) async {
    if (chats.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete chats?'),
        content: Text('Delete ${chats.length} selected chat(s)?'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancel')),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final store = SqlChatStore();
    for (final c in chats) {
      await store.deleteChat(c.id);
    }
    if (!mounted) return;
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
    Navigator.pop(context);
  }

  Future<void> _rename(Chat chat) async {
    final ctrl = TextEditingController(text: chat.name);
    final next = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: ()=>Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (next == null || next.trim().isEmpty) return;
    await SqlChatStore().rename(chat.id, next.trim());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selected.length} selected' : '${widget.personaName} History'),
        leading: _selectionMode
            ? IconButton(
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selected.clear();
                }),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  onPressed: () => setState(() {
                    if (_selected.length == _items.length) {
                      _selected.clear();
                      _selectionMode = false;
                    } else {
                      _selected..clear()..addAll(_items.map((e) => e.id));
                    }
                  }),
                  icon: const Icon(Icons.select_all_rounded),
                ),
                IconButton(
                  onPressed: () => _confirmDelete(_items.where((e) => _selected.contains(e.id)).toList(growable: false)),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ]
            : null,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final c = _items[i];
          final selected = _selected.contains(c.id);
          return Material(
            color: isLight ? Colors.white : const Color(0xFF0F141B),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: () => _toggleSelection(c.id),
              onTap: () async {
                if (_selectionMode) {
                  _toggleSelection(c.id);
                  return;
                }
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(userId: widget.userId, chatId: c.id, chatName: c.name)));
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [widget.accent.withOpacity(isLight ? .12 : .16), Colors.transparent]),
                  border: Border.all(color: selected ? widget.accent.withOpacity(.72) : (isLight ? Colors.black12 : Colors.white10)),
                ),
                child: Row(
                  children: [
                    _selectionMode
                        ? Checkbox(value: selected, onChanged: (_) => _toggleSelection(c.id))
                        : Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: widget.accent.withOpacity(.14),
                              border: Border.all(color: widget.accent.withOpacity(.45)),
                            ),
                            child: Icon(Icons.chat_bubble_outline_rounded, color: widget.accent),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                              if (c.starred) Icon(Icons.push_pin_rounded, size: 18, color: widget.accent),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(DateTime.fromMillisecondsSinceEpoch(c.lastAt).toString().substring(0,16), style: TextStyle(color: isLight ? Colors.black54 : Colors.white70)),
                        ],
                      ),
                    ),
                    if (!_selectionMode)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') await _rename(c);
                          if (value == 'pin') {
                            await SqlChatStore().toggleStar(c.id);
                            if (mounted) setState(() {});
                          }
                          if (value == 'delete') await _confirmDelete([c]);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'pin', child: Text(c.starred ? 'Unpin' : 'Pin')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemCount: _items.length,
      ),
    );
  }
}
