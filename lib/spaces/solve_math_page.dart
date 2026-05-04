import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sql_chat_store.dart';
import '../screens/chat_page.dart';

class SolveMathPage extends StatefulWidget {
  const SolveMathPage({super.key, required this.userId});
  final String userId;

  @override
  State<SolveMathPage> createState() => _SolveMathPageState();
}

class _SolveMathPageState extends State<SolveMathPage> {
  bool _busy = false;

  // Multi-select state
  bool _selectMode = false;
  final Set<String> _selected = {};

  // Helper: keep only chats for this space, with a safe fallback for old rows.
  bool _inThisSpace(Chat c) {
    try {
      if (c.presetJson != null) {
        final m = jsonDecode(c.presetJson!) as Map<String, dynamic>;
        final s = m['space'];
        if (s is String) return s == 'solve_math';
      }
    } catch (_) {}
    // Fallback: include pre-existing chats that used the default title.
    return c.name == 'Solve Math';
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final id = await SqlChatStore().createChat(
        name: 'Solve Math',
        // Tag this chat so only Solve Math sees it.
        preset: const {'space': 'solve_math'},
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            userId: widget.userId,
            chatId: id,
            chatName: 'Solve Math',
            showMathShortcuts: true, // ✏️ / 📷 inside chat
            systemPrompt: _mathSystem,
            welcome:
                "Send a problem, draw it with ✏️, or snap a photo with 📷. I’ll show neat steps then the final **Answer**.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Stronger instruction so model transcribes handwriting first
  static const _mathSystem = '''
You are a careful math solver.

When an image/sketch is provided:
- First TRANSCRIBE the handwritten math (numbers, symbols, operators). Do not describe colored lines or strokes.
- If something is ambiguous, ask 1 short clarifying question.
- Then solve the transcribed problem step by step.

General rules:
- Show minimal, neat steps (2–8 lines). Use LaTeX for math.
- If a diagram/photo is attached, reference only the relevant parts.
- End with **Answer: ...**.
[mood: neutral]
''';

  String _formatLastAt(int epochMillis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis).toLocal();
    return DateFormat('yMMMd • HH:mm').format(dt);
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected chats?'),
        content: Text('You are about to delete ${_selected.length} chat(s). This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      final store = SqlChatStore();
      for (final id in _selected) {
        await store.deleteChat(id);
      }
      if (mounted) {
        setState(() {
          _selected.clear();
          _selectMode = false;
        });
      }
    }
  }

  Future<void> _renameChat(BuildContext context, Chat c) async {
    final ctrl = TextEditingController(text: c.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Chat title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await SqlChatStore().rename(c.id, newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final store = SqlChatStore();

    return Scaffold(
      appBar: AppBar(title: const Text('Solve Math')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: isLight ? Colors.black.withOpacity(.04) : const Color(0xFF171B22),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calculate_rounded, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Algebra • Calculus • Geometry\nStart a chat, then use ✏️ to draw or 📷 to snap.",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Recents header with selection toggle
            Row(
              children: [
                const Text('Recents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectMode = !_selectMode;
                    if (!_selectMode) _selected.clear();
                  }),
                  icon: Icon(_selectMode ? Icons.check_circle : Icons.checklist_rounded, color: cs.primary),
                  label: Text(_selectMode ? 'Done' : 'Select', style: TextStyle(color: cs.primary)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<Chat>>(
                stream: store.watchChats(starredOnly: false),
                builder: (_, snap) {
                  final items = (snap.data ?? const <Chat>[])
                      .where(_inThisSpace)
                      .toList()
                    ..sort((a, b) => b.lastAt.compareTo(a.lastAt));

                  if (items.isEmpty) {
                    return const Center(child: Text("Nothing here yet."));
                  }

                  void _toggleSelectAll() {
                    setState(() {
                      if (_selected.length == items.length) {
                        _selected.clear();
                      } else {
                        _selected..clear()..addAll(items.map((c) => c.id));
                      }
                    });
                  }

                  return Column(
                    children: [
                      if (_selectMode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selected.length == items.length && items.isNotEmpty,
                                onChanged: (_) => _toggleSelectAll(),
                              ),
                              const SizedBox(width: 6),
                              Text('Select all (${items.length})'),
                              const Spacer(),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _selected.isEmpty ? null : _deleteSelected,
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = items[i];
                            final selected = _selected.contains(c.id);

                            Future<void> _deleteOne() async {
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
                              if (ok == true) await store.deleteChat(c.id);
                            }

                            return GestureDetector(
                              onLongPress: () async {
                                final action = await showModalBottomSheet<String>(
                                  context: context,
                                  showDragHandle: true,
                                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  builder: (_) => SafeArea(
                                    child: Wrap(
                                      children: [
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
                                      ],
                                    ),
                                  ),
                                );
                                if (action == 'rename') {
                                  await _renameChat(context, c);
                                } else if (action == 'delete') {
                                  await _deleteOne();
                                }
                              },
                              child: Card(
                                child: ListTile(
                                  leading: _selectMode
                                      ? Checkbox(
                                          value: selected,
                                          onChanged: (_) {
                                            setState(() {
                                              if (selected) {
                                                _selected.remove(c.id);
                                              } else {
                                                _selected.add(c.id);
                                              }
                                            });
                                          },
                                        )
                                      : const Icon(Icons.chat_bubble_outline_rounded),
                                  title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(_formatLastAt(c.lastAt), style: const TextStyle(fontSize: 12)),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () {
                                    if (_selectMode) {
                                      setState(() {
                                        if (selected) {
                                          _selected.remove(c.id);
                                        } else {
                                          _selected.add(c.id);
                                        }
                                      });
                                      return;
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          userId: widget.userId,
                                          chatId: c.id,
                                          chatName: c.name,
                                          showMathShortcuts: true,
                                          systemPrompt: _mathSystem,
                                        ),
                                      ),
                                    );
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

            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.black,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
