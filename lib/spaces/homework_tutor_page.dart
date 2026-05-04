import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/sql_chat_store.dart';
import '../screens/chat_page.dart';

class HomeworkTutorPage extends StatefulWidget {
  final String userId;
  const HomeworkTutorPage({super.key, required this.userId});

  @override
  State<HomeworkTutorPage> createState() => _HomeworkTutorPageState();
}

class _HomeworkTutorPageState extends State<HomeworkTutorPage> {
  bool _busy = false;

  // Selection mode (Recents)
  bool _selectMode = false;
  final Set<String> _selected = <String>{};

  // Only keep chats for this space; fallback for old rows by title.
  bool _inThisSpace(Chat c) {
    try {
      if (c.presetJson != null) {
        final m = jsonDecode(c.presetJson!) as Map<String, dynamic>;
        final s = m['space'];
        if (s is String) return s == 'homework_tutor';
      }
    } catch (_) {}
    return c.name == 'AI Homework Tutor';
  }

  // System prompt tuned for reading sketches/images as content
  static const _system = '''
You are a friendly homework tutor. Teach; do not just give answers.

When a sketch/photo is attached (whiteboard screenshot or drawing):
- Assume it is the user's working. READ equations, symbols, labels, arrows, axes and text.
- Do OCR-like reading of the math/labels. Do **not** describe colors or “a red/black/vertical line”.
- If multiple steps are written, treat them as context and continue from there concisely.
- If truly ambiguous, ask exactly 1 short clarifying question; otherwise proceed.

General rules:
- Start with a 1-sentence plan, then short steps or bullets.
- Explain simply; define terms briefly. Offer a quick check question at the end.
- If the user attaches notes/diagrams/PDF, reference them explicitly (“see sketch”, “see p. X”).
- If this looks like a graded exam, guide with hints instead of giving a full final solution on first try.
- Use LaTeX for math. End with **Answer: …** when a final numeric/algebraic result exists.
- Never hallucinate; if something is unreadable in the sketch, say so briefly and move on.
[mood: happy]
''';

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final id = await SqlChatStore().createChat(
        name: 'AI Homework Tutor',
        // Tag this chat so only Homework Tutor sees it.
        preset: const {'space': 'homework_tutor'},
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            userId: widget.userId,
            chatId: id,
            chatName: 'AI Homework Tutor',
            systemPrompt: _system,
            showMathShortcuts: true, // ✏️ + 📷 inside chat
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _renameChat(SqlChatStore store, String id, String currentName) async {
    final c = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rename chat"),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Chat title"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text("Save")),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await store.rename(id, newName);
  }

  Future<void> _deleteChat(SqlChatStore store, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete chat?"),
        content: const Text("This will remove the chat locally."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok == true) await store.deleteChat(id);
  }

  Future<void> _deleteSelected(SqlChatStore store) async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Delete ${_selected.length} chat(s)?"),
        content: const Text("This will remove them locally."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );
    if (ok != true) return;
    for (final id in _selected.toList()) {
      await store.deleteChat(id);
    }
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final store = SqlChatStore();
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('AI Homework Tutor'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Intro card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Card(
                elevation: 0,
                color: isLight ? Colors.black.withOpacity(.04) : const Color(0xFF171B22),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.menu_book_rounded, size: 30),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Use the chat to ask homework questions. Inside the chat, tap ✏️ to sketch or 📷 to snap notes; "
                          "the tutor will read your equations/labels from the sketch and explain clearly.",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Recents header with tick button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const Text('Recents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (_selectMode)
                    Row(
                      children: [
                        Checkbox(
                          value: false, // handled below when we know items
                          onChanged: (_) {},
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  Tooltip(
                    message: _selectMode ? 'Exit selection' : 'Select chats',
                    child: IconButton(
                      icon: Icon(_selectMode ? Icons.close_rounded : Icons.checklist_rounded),
                      onPressed: () => setState(() {
                        _selectMode = !_selectMode;
                        if (!_selectMode) _selected.clear();
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Recents list (space-filtered)
            Expanded(
              child: StreamBuilder<List<Chat>>(
                stream: store.watchChats(), // global stream; we filter locally
                builder: (context, snap) {
                  final items = (snap.data ?? const <Chat>[])
                      .where(_inThisSpace)
                      .toList()
                    ..sort((a, b) => b.lastAt.compareTo(a.lastAt));

                  if (items.isEmpty) {
                    return const Center(child: Text("Nothing here yet."));
                  }

                  final allIds = items.map((c) => c.id).toList();
                  final allSelected = _selected.length == items.length && items.isNotEmpty;

                  return Column(
                    children: [
                      if (_selectMode)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: Row(
                            children: [
                              Checkbox(
                                value: allSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected..clear()..addAll(allIds);
                                    } else {
                                      _selected.clear();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 6),
                              const Text('Select all'),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _selected.isEmpty ? null : () => _deleteSelected(store),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.delete_rounded),
                                label: Text('Delete (${_selected.length})'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final d = items[i];
                            final id = d.id;
                            final name = d.name;
                            final starred = d.starred;

                            final selected = _selected.contains(id);

                            return GestureDetector(
                              onLongPress: () async {
                                final action = await showModalBottomSheet<String>(
                                  context: context,
                                  showDragHandle: true,
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                  builder: (_) => SafeArea(
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      ListTile(
                                        leading: const Icon(Icons.drive_file_rename_outline_rounded),
                                        title: const Text("Rename"),
                                        onTap: () => Navigator.pop(context, 'rename'),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                        title: const Text("Delete"),
                                        onTap: () => Navigator.pop(context, 'delete'),
                                      ),
                                      const SizedBox(height: 8),
                                    ]),
                                  ),
                                );
                                if (action == 'rename') {
                                  await _renameChat(store, id, name);
                                } else if (action == 'delete') {
                                  await _deleteChat(store, id);
                                }
                              },
                              child: Card(
                                child: ListTile(
                                  leading: _selectMode
                                      ? Checkbox(
                                          value: selected,
                                          onChanged: (v) => setState(() {
                                            if (v == true) {
                                              _selected.add(id);
                                            } else {
                                              _selected.remove(id);
                                            }
                                          }),
                                        )
                                      : Icon(
                                          starred ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
                                          color: starred ? const Color(0xFF00B8FF) : null,
                                        ),
                                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: const Text(''),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    if (_selectMode) {
                                      setState(() {
                                        if (selected) {
                                          _selected.remove(id);
                                        } else {
                                          _selected.add(id);
                                        }
                                      });
                                      return;
                                    }
                                    Navigator.of(context).push(PageRouteBuilder(
                                      transitionDuration: const Duration(milliseconds: 280),
                                      pageBuilder: (_, a1, __) => FadeTransition(
                                        opacity: a1,
                                        child: ChatPage(
                                          userId: widget.userId,
                                          chatId: id,
                                          chatName: name,
                                          systemPrompt: _system,
                                          showMathShortcuts: true,
                                        ),
                                      ),
                                    ));
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Start button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
