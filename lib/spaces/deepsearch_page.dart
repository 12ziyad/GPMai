// lib/spaces/deepsearch_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/sql_chat_store.dart';
import '../services/gpmai_brain.dart';
import '../widgets/markdown_bubble.dart';

class DeepSearchPage extends StatefulWidget {
  const DeepSearchPage({super.key, required this.userId});
  final String userId;

  @override
  State<DeepSearchPage> createState() => _DeepSearchPageState();
}

/* ───────── inline image helpers (data:... in message text) ───────── */

class _InlineImage {
  final String mime;
  final Uint8List bytes;
  const _InlineImage(this.mime, this.bytes);
}

class _ParsedInline {
  final String text;
  final List<_InlineImage> images;
  const _ParsedInline(this.text, this.images);
}

class _DeepSearchPageState extends State<DeepSearchPage> {
  final _store = SqlChatStore();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  String? _chatId;
  bool _sending = false;

  // picked images (shown above composer; get embedded into the user bubble on send)
  final List<_PickedImage> _images = [];

  static const _stripe = <Color>[
    Color(0xFF00B8FF), // blue
    Color(0xFF7E57C2), // purple
    Color(0xFFFF7043), // orange
  ];

  static const String _welcome =
      "Hi! I’m **AI DeepSearch**. Ask about news, research, products, people — "
      "and I’ll search the live web, fact-check across multiple sources, and cite what I find.";

  static const String _systemPrompt = r"""
You are **AI DeepSearch**, a professional research assistant.

Rules
- Be brief, structured, and cite sources when you can.
- If you cannot verify, say what you *can* do and suggest better query wording.
Formatting
- Use markdown.
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
          'model': 'mini',
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
        b.writeln('${m.role == 'user' ? 'User' : 'GPMai'}: ${m.text}\n');
      }
      return b.toString().trim();
    } catch (_) {
      return '';
    }
  }

  // ===== image picking & preview =====
  Future<void> _pickFromCamera() async {
    if (!await Permission.camera.request().isGranted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Camera permission denied.')));
      return;
    }
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 86);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _images.add(_PickedImage('photo.jpg', bytes)));
  }

  Future<void> _pickFromGallery() async {
    final list = await _picker.pickMultiImage(imageQuality: 88);
    if (list.isEmpty) return;
    final toAdd =
        await Future.wait(list.map((x) async => _PickedImage(x.name, await x.readAsBytes())));
    setState(() => _images.addAll(toAdd));
  }

  void _showImageSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(context);
              _pickFromCamera();
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose photos'),
            onTap: () {
              Navigator.pop(context);
              _pickFromGallery();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _attachmentPreview() {
    if (_images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 6, right: 6, top: 8, bottom: 6),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: _images.length,
        itemBuilder: (_, i) {
          final p = _images[i];
          return Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(p.bytes, width: 72, height: 72, fit: BoxFit.cover),
            ),
            Positioned(
              right: 2,
              top: 2,
              child: GestureDetector(
                onTap: () => setState(() => _images.removeAt(i)),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  // ===== inline images in message text =====
  String _mimeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  String _asDataUrl(Uint8List bytes, String name) =>
      'data:${_mimeFor(name)};base64,${base64Encode(bytes)}';

  _ParsedInline _parseInlineImages(String s) {
    final reg = RegExp(r'data:(image\/[a-zA-Z0-9.+-]+);base64,([A-Za-z0-9\/+=]+)');
    final images = <_InlineImage>[];
    for (final m in reg.allMatches(s)) {
      images.add(_InlineImage(m.group(1)!, base64Decode(m.group(2)!)));
    }
    final cleaned = s.replaceAll(reg, '').trim();
    return _ParsedInline(cleaned, images);
  }

  void _openImageViewer(Uint8List bytes) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) {
        return Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.96))),
            Positioned.fill(
              child: SafeArea(
                child: InteractiveViewer(
                  child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===== send =====
  Future<void> _send() async {
    if (_sending || _chatId == null) return;
    final text = _ctrl.text.trim();
    final hasAny = text.isNotEmpty || _images.isNotEmpty;
    if (!hasAny) return;

    setState(() => _sending = true);

    // 1) Build the USER message text with inline data: images so they render in the bubble
    final buf = StringBuffer();
    buf.write(text.isEmpty ? '(no text)' : text);
    for (final p in _images) {
      buf.write('\n\n${_asDataUrl(p.bytes, p.name)}');
    }
    final userBubbleText = buf.toString();

    // 2) Insert the user message immediately
    await _store.addMessage(chatId: _chatId!, role: 'user', text: userBubbleText);

    // 3) Clear the composer preview instantly
    _ctrl.clear();
    _images.clear();
    if (mounted) setState(() {}); // hide preview row right away

    // 4) Compose for the model (text only)
    final transcript = await _memorySlice();
    final composed = transcript.isEmpty
        ? text
        : "Conversation so far:\n$transcript\n\n---\nLatest user message:\n$text\n\nBe brief and structured.";

    String reply;
    try {
      final r = await GPMaiBrain.sendRich(
        userText: composed,
        systemPrompt: _systemPrompt,
        userId: widget.userId,
        chatId: _chatId,
        uiModel: "mini",
        modelOverride: null,
        contentParts: null,
      );
      reply = r.text.trim();
      if (reply.isEmpty) reply = "[Error] Empty reply.";
    } catch (e) {
      reply = "[Error] $e";
    }

    await _store.addMessage(
      chatId: _chatId!,
      role: 'gpm',
      text: reply.trim().isEmpty ? "[Error] Empty reply." : reply.trim(),
    );

    if (mounted) setState(() => _sending = false);

    // scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 260,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  // ===== links extraction for "Sources" chips =====
  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<_Link> _extractLinks(String text) {
    final out = <_Link>[];
    final seen = <String>{};

    // [title](https://...)
    final md = RegExp(r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)');
    for (final m in md.allMatches(text)) {
      final title = m.group(1)!.trim();
      final url = m.group(2)!.trim();
      if (seen.add(url)) out.add(_Link(title, url));
    }

    // bare urls
    final bare = RegExp(r'(?<!\()\bhttps?:\/\/[^\s)]+');
    for (final m in bare.allMatches(text)) {
      final url = m.group(0)!.trim();
      if (seen.add(url)) out.add(_Link(Uri.parse(url).host.replaceFirst('www.', ''), url));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (_chatId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI DeepSearch'),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 12), child: Icon(Icons.public_rounded)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _store.watchMessages(_chatId!),
              builder: (_, snap) {
                final msgs = snap.data ?? const <Message>[];
                final count = msgs.length + (_sending ? 1 : 0);

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
                  itemCount: count,
                  itemBuilder: (_, i) {
                    if (_sending && i == count - 1) {
                      return _SearchingBubble(
                        stripeColor: _stripe[(msgs.where((m) => m.role != 'user').length) %
                            _stripe.length],
                      );
                    }

                    final m = msgs[i];
                    final isUser = m.role == 'user';

                    int aiCount = 0;
                    for (int k = 0; k <= i; k++) {
                      if (msgs[k].role != 'user') aiCount++;
                    }
                    final stripeColor =
                        _stripe[(aiCount - 1).clamp(0, 999) % _stripe.length];

                    final bg = isUser
                        ? (isLight ? const Color(0xFFEFF8FF) : const Color(0xFF0F1218))
                        : (isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22));
                    final fg = isLight ? Colors.black87 : Colors.white;

                    final parsed = _parseInlineImages(m.text);
                    final links = isUser ? const <_Link>[] : _extractLinks(parsed.text);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      children: [
                        if (!isUser)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, right: 10),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: stripeColor.withOpacity(.18),
                              child: const Icon(Icons.search_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        Flexible(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 14),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(18),
                              border: isUser
                                  ? Border.all(
                                      color: const Color(0xFF00B8FF), width: 1.2)
                                  : Border(
                                      left: BorderSide(
                                          color: stripeColor, width: 3)),
                            ),
                            constraints: const BoxConstraints(maxWidth: 640),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (parsed.text.isNotEmpty)
                                  MarkdownBubble(
                                    text: parsed.text,
                                    textColor: fg,
                                    linkColor: const Color(0xFF00B8FF),
                                  ),
                                if (parsed.images.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  for (final im in parsed.images)
                                    GestureDetector(
                                      onTap: () => _openImageViewer(im.bytes),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          width: 320,
                                          height: 180,
                                          color: Colors.black12,
                                          child: Image.memory(
                                            im.bytes,
                                            gaplessPlayback: true,
                                            filterQuality: FilterQuality.low,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                                if (links.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text("Sources:",
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: fg.withOpacity(.7),
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: links
                                        .map((l) => ActionChip(
                                              label: Text(
                                                _truncate(l.title, 26),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              avatar: const Icon(
                                                Icons.link_rounded, size: 16),
                                              onPressed: () => _openUrl(l.url),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ===== composer =====
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _attachmentPreview(),
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Add images",
                        onPressed: _sending ? null : _showImageSheet,
                        icon: const Icon(Icons.add_photo_alternate_rounded),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Search…',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border:
                                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.search_rounded),
                        label: Text(_sending ? 'Searching…' : 'Search'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
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

// ===== searching bubble =====

class _SearchingBubble extends StatefulWidget {
  final Color stripeColor;
  const _SearchingBubble({required this.stripeColor});

  @override
  State<_SearchingBubble> createState() => _SearchingBubbleState();
}

class _SearchingBubbleState extends State<_SearchingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat();

  static const _sites = <(String, IconData)>[
    ('News', Icons.article_rounded),
    ('Wikipedia', Icons.menu_book_rounded),
    ('Blogs', Icons.rss_feed_rounded),
    ('Search', Icons.public_rounded),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22);
    final fg = isLight ? Colors.black87 : Colors.white;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 10, left: 12),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: widget.stripeColor.withOpacity(.18),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
          ),
        ),
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: widget.stripeColor, width: 3)),
            ),
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Searching…',
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sites.map((s) {
                    final (name, icon) = s;
                    return AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: widget.stripeColor.withOpacity(.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 14, color: widget.stripeColor),
                          const SizedBox(width: 6),
                          Text(name, style: TextStyle(color: fg, fontSize: 12)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(widget.stripeColor),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===== helpers =====

class _PickedImage {
  final String name;
  final Uint8List bytes;
  _PickedImage(this.name, this.bytes);
}

class _Link {
  final String title;
  final String url;
  _Link(this.title, this.url);
}

String _truncate(String s, int max) =>
    (s.length <= max) ? s : '${s.substring(0, max - 1)}…';
