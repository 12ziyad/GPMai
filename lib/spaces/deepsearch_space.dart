// lib/spaces/deepsearch_space.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../services/sql_chat_store.dart';
import '../services/gpmai_brain.dart';
import '../widgets/markdown_bubble.dart';

class DeepSearchSpace extends StatefulWidget {
  const DeepSearchSpace({super.key, required this.userId});
  final String userId;

  @override
  State<DeepSearchSpace> createState() => _DeepSearchSpaceState();
}

class _DeepSearchSpaceState extends State<DeepSearchSpace> {
  final _store = SqlChatStore();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();

  String? _chatId;
  bool _sending = false;

  // 3-color cycle for assistant side stripe
  static const _stripe = <Color>[
    Color(0xFF00B8FF), // blue
    Color(0xFF7E57C2), // purple
    Color(0xFFFF7043), // orange
  ];

  static const String _welcome =
      "Hi! I’m **AI DeepSearch**. Ask about news, research, products, people — "
      "or attach text — and I’ll search the live web, fact-check across multiple sources, and cite what I find.";

  static const String _systemPrompt = r"""
You are **AI DeepSearch**, a professional web researcher.
For EVERY user query, you MUST run a live web search first and then answer.

Rules
- Do 1–3 focused searches; read diverse, reputable sources.
- Start with a 1–2 line summary, then 3–6 crisp bullets.
- Cite 3–6 sources with readable names as clickable markdown links.
- If sources disagree, note it in one short line.
- Never fabricate. If not found after reasonable searching, say so and suggest a better query.
- Match the user’s language. Keep it tight; no filler; no “as an AI”.

Formatting
- Use markdown. Example: [BBC](https://www.bbc.com/news/...).
- End with “Further reading:” if you have extra high-quality links.
[mood: neutral]
""";

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final id = await _store.createChat(
        name: 'AI DeepSearch',
        preset: {
          'kind': 'tool',
          'id': 'deepsearch',
          'model': 'gpt-4o-search-preview', // router can switch tools from this
        },
      );
      _chatId = id;
      final existing = await _store.watchMessages(id).first;
      if (existing.isEmpty) {
        await _store.addMessage(chatId: id, role: 'gpm', text: _welcome);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open DeepSearch: $e')),
      );
      Navigator.pop(context);
    }
  }

  Future<String> _memorySlice() async {
    try {
      if (_chatId == null) return '';
      final msgs = await _store.watchMessages(_chatId!).first;
      if (msgs.isEmpty) return '';
      final take = msgs.length > 10 ? msgs.sublist(msgs.length - 10) : msgs;
      final b = StringBuffer();
      for (final m in take) {
        final who = m.role == 'user' ? 'User' : 'GPMai';
        b.writeln('$who: ${m.text}');
        b.writeln();
      }
      return b.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<void> _send() async {
    if (_sending || _chatId == null) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _ctrl.clear();

    await _store.addMessage(chatId: _chatId!, role: 'user', text: text);

    final transcript = await _memorySlice();
    final composed = transcript.isEmpty
        ? text
        : "Conversation so far:\n$transcript\n\n---\nLatest user message:\n$text\n\nRespond in BRIEF MODE and cite sources.";

    String reply;
    try {
      reply = await GPMaiBrain.sendRich(
        composed,
        systemPrompt: _systemPrompt,
        modelOverride: 'gpt-4o-search-preview', // << force search model
      );
    } catch (e) {
      reply = "[Error] $e";
    }

    await _store.addMessage(chatId: _chatId!, role: 'gpm', text: reply.trim().isEmpty ? "[Error] Empty reply." : reply.trim());
    if (mounted) setState(() => _sending = false);

    // scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _editCompare(String original) async {
    final c1 = TextEditingController(text: original);
    final c2 = TextEditingController(text: original);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;
        return DefaultTabController(
          length: 2,
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsets),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TabBar(tabs: [Tab(text: 'Result A'), Tab(text: 'Result B')]),
                SizedBox(
                  height: 320,
                  child: TabBarView(children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: c1, maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Editable Result A',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: c2, maxLines: null,
                        decoration: const InputDecoration(
                          labelText: 'Editable Result B',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final merged = '${c1.text}\n\n---\n\n${c2.text}'.trim();
                          await Clipboard.setData(ClipboardData(text: merged));
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied merged edits')));
                          }
                        },
                        icon: const Icon(Icons.copy_all_rounded),
                        label: const Text('Copy both'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (_chatId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI DeepSearch'),
        actions: const [Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.public_rounded))],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _store.watchMessages(_chatId!),
              builder: (_, snap) {
                final msgs = snap.data ?? const <Message>[];
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final m = msgs[i];
                    final isUser = m.role == 'user';

                    // cycle assistant stripes based on assistant index up to this point
                    int aiIndex = 0;
                    for (int k = 0; k <= i; k++) {
                      if (msgs[k].role != 'user') aiIndex++;
                    }
                    final stripeColor = _stripe[(aiIndex - 1).clamp(0, 999) % _stripe.length];

                    final bg = isUser
                        ? (isLight ? const Color(0xFFEFF8FF) : const Color(0xFF0F1218))
                        : (isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22));
                    final fg = isLight ? Colors.black87 : Colors.white;

                    final bubble = Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(18),
                        border: isUser
                            ? Border.all(color: const Color(0xFF00B8FF), width: 1.2)
                            : Border(left: BorderSide(color: stripeColor, width: 3)),
                      ),
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: MarkdownBubble(text: m.text, textColor: fg, linkColor: const Color(0xFF00B8FF)),
                    );

                    final avatar = isUser
                        ? const SizedBox(width: 36) // keep alignment clean
                        : CircleAvatar(
                            radius: 18,
                            backgroundColor: stripeColor.withOpacity(.18),
                            child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                          );

                    final row = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isUser) Padding(padding: const EdgeInsets.only(top: 4, right: 10), child: avatar),
                        Flexible(child: GestureDetector(
                          onLongPress: () {
                            if (!isUser) _editCompare(m.text);
                          },
                          child: bubble,
                        )),
                      ],
                    );

                    return row;
                  },
                );
              },
            ),
          ),

          // custom composer with "Search web" CTA
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Search the web…',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.search_rounded),
                    label: Text(_sending ? 'Searching…' : 'Search web'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
