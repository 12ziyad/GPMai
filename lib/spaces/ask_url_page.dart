// lib/spaces/ask_url_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as ul;
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/expandable_textbox.dart';
import '../services/gpmai_brain.dart';

/// Accent to match the "Ask about URL" tool tile (purple)
const _urlAccent = Color(0xFF8E24AA);
const _electricBlue = Color(0xFF00B8FF);

/* ─────────────────────────────────────────────────────────────
 * STEP 1: Entry screen — collect URL with paste + Continue
 * ──────────────────────────────────────────────────────────── */
class AskUrlPage extends StatefulWidget {
  final String userId;
  const AskUrlPage({super.key, required this.userId});

  @override
  State<AskUrlPage> createState() => _AskUrlPageState();
}

class _AskUrlPageState extends State<AskUrlPage> {
  final _urlCtrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.addListener(_validate);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  void _validate() {
    final t = _urlCtrl.text.trim();
    setState(() => _valid = _normalizeUrl(t) != null);
  }

  String? _normalizeUrl(String raw) {
    if (raw.isEmpty) return null;
    String s = raw.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    try {
      final u = Uri.parse(s);
      if ((u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty) {
        return u.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final txt = data?.text ?? '';
    if (txt.isEmpty) return;
    _urlCtrl.text = txt;
    _urlCtrl.selection =
        TextSelection.fromPosition(TextPosition(offset: _urlCtrl.text.length));
  }

  void _continue() {
    final normalized = _normalizeUrl(_urlCtrl.text.trim());
    if (normalized == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AskUrlChatPage(userId: widget.userId, url: normalized),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ring = isLight ? Colors.black12 : Colors.white10;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask about URL')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderBadge(),
              const SizedBox(height: 16),
              Text('Enter or paste a link',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cs.onSurface)),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: ring, width: 1.2),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.link_rounded, color: _urlAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          hintText: 'https://example.com/article',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _valid ? _continue() : null,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Paste',
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _HintLine(),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _valid ? _continue : null,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _valid ? _urlAccent : cs.surfaceVariant,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final grad = const LinearGradient(
      colors: [Color(0xFF00B8FF), Color(0xFFBA68C8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final border = Theme.of(context).colorScheme.onSurface.withOpacity(.16);
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: grad,
            border: Border.all(color: border, width: 1.2),
          ),
          child: const Center(
            child: Icon(Icons.language_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Ask questions about any webpage. I’ll read it and answer, summarize, or extract key points.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.85),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tip: You can paste links without http(s); we’ll fix it.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/* ─────────────────────────────────────────────────────────────
 * STEP 2: Custom lightweight chat specialized for URL Q&A
 * ──────────────────────────────────────────────────────────── */
class AskUrlChatPage extends StatefulWidget {
  final String userId;
  final String url;
  const AskUrlChatPage({super.key, required this.userId, required this.url});

  @override
  State<AskUrlChatPage> createState() => _AskUrlChatPageState();
}

enum _Role { user, bot }

class _Msg {
  final _Role role;
  final String text;
  _Msg(this.role, this.text);
}

class _AskUrlChatPageState extends State<AskUrlChatPage>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  final List<_Msg> _messages = [];
  bool _generating = false;

  // Page fetch/cache
  bool _fetching = false;
  String? _pageText;

  // Single-flight future so first send can await it.
  Future<String>? _fetchFuture;

  // Invisible WebView (fallback).
  WebViewController? _wvCtrl;

  static const _suggestions = <String>[
    'Summarize',
    'Extract key points',
    'Outline headings',
    'Find FAQs',
  ];

  @override
  void initState() {
    super.initState();
    _seedWelcome();
    _loadPage(); // kickoff fetch once
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _seedWelcome() {
    _messages.add(_Msg(
      _Role.bot,
      'I’m ready to help with:\n${widget.url}\n\nWhat would you like to do?',
    ));
  }

  Future<void> _loadPage() async {
    setState(() => _fetching = true);
    _fetchFuture ??= _fetchPageText(widget.url);
    final txt = await _fetchFuture!;
    if (!mounted) return;
    setState(() {
      _pageText = txt.isNotEmpty ? txt : null;
      _fetching = false;
    });
  }

  /// Ensure we don’t answer before we’ve given fetching a chance.
  Future<void> _ensurePageReady({Duration timeout = const Duration(seconds: 15)}) async {
    if (_pageText != null) return;
    _fetchFuture ??= _fetchPageText(widget.url);
    try {
      final txt = await _fetchFuture!.timeout(timeout);
      if (!mounted) return;
      setState(() {
        _pageText = txt.isNotEmpty ? txt : null;
        _fetching = false;
      });
    } catch (_) {
      // Timeout or error — we’ll fall back gracefully.
    }
  }

  /// Robust fetcher pipeline: direct → Jina → alt → WebView
  Future<String> _fetchPageText(String url) async {
    String text = '';
    const timeout = Duration(seconds: 12);

    // 1) Direct fetch
    try {
      final uri = Uri.parse(url);
      final res = await http
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/124.0 Safari/537.36 GPMai/1.0',
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.7',
              'Referer': '${uri.scheme}://${uri.host}/',
              'Cache-Control': 'no-cache',
            },
          )
          .timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final html = utf8.decode(res.bodyBytes, allowMalformed: true);
        text = _extractVisibleText(html);
      }
    } catch (_) {}

    // 2) Jina reader
    if (text.length < 600) {
      try {
        final proxy = Uri.parse('https://r.jina.ai/http/${Uri.encodeFull(url)}');
        final res2 = await http
            .get(proxy, headers: const {
              'User-Agent': 'curl/8.0',
              'Accept': 'text/plain; charset=utf-8',
            })
            .timeout(timeout);
        if (res2.statusCode >= 200 && res2.statusCode < 300) {
          final body = utf8.decode(res2.bodyBytes, allowMalformed: true).trim();
          if (body.isNotEmpty) {
            const cap = 12000;
            text = body.length > cap ? '${body.substring(0, cap)}…' : body;
          }
        }
      } catch (_) {}
    }

    // 3) Alt reader chain
    if (text.length < 600) {
      for (final altUrl in [
        'https://r.jina.ai/http/https://r.jina.ai/http/${Uri.encodeFull(url)}',
        'https://r.jina.ai/http/http://r.jina.ai/http/${Uri.encodeFull(url)}',
      ]) {
        try {
          final alt = Uri.parse(altUrl);
          final res3 = await http
              .get(alt, headers: const {
                'User-Agent': 'curl/8.0',
                'Accept': 'text/plain; charset=utf-8',
              })
              .timeout(timeout);
          if (res3.statusCode >= 200 && res3.statusCode < 300) {
            final body = utf8.decode(res3.bodyBytes, allowMalformed: true).trim();
            if (body.isNotEmpty) {
              const cap = 12000;
              text = body.length > cap ? '${body.substring(0, cap)}…' : body;
              break;
            }
          }
        } catch (_) {}
      }
    }

    // 4) WebView fallback (render like real browser), no visible UI change
    if (text.length < 600) {
      final viaWebView = await _tryWebViewScrape(url);
      if (viaWebView.length > text.length) {
        text = viaWebView;
      }
    }

    return text;
  }

  // Invisible WebView scraper
  Future<String> _tryWebViewScrape(String url) async {
    try {
      if (_wvCtrl == null) {
        final c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000));
        _wvCtrl = c;
        if (mounted) setState(() {}); // mount Offstage host
      }

      final done = Completer<void>();
      _wvCtrl!.setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (!done.isCompleted) done.complete();
        },
        onWebResourceError: (_) {
          if (!done.isCompleted) done.complete();
        },
      ));

      await _wvCtrl!.loadRequest(Uri.parse(url));
      await done.future.timeout(const Duration(seconds: 15));

      final obj = await _wvCtrl!.runJavaScriptReturningResult(
        "(() => (document.body && document.body.innerText) ? document.body.innerText : '')();",
      );

      String txt = obj is String ? obj : obj.toString();
      try { txt = jsonDecode(txt); } catch (_) {}
      txt = txt.trim();
      if (txt.length > 12000) txt = '${txt.substring(0, 12000)}…';
      return txt;
    } catch (_) {
      return '';
    }
  }

  String _extractVisibleText(String html) {
    String s = html.replaceAll(RegExp(r'(?is)<script.*?>.*?</script>'), ' ');
    s = s.replaceAll(RegExp(r'(?is)<style.*?>.*?</style>'), ' ');
    s = s.replaceAll(RegExp(r'(?is)<[^>]+>'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    const cap = 12000;
    if (s.length > cap) s = '${s.substring(0, cap)}…';
    return s;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _generating) return;

    setState(() {
      _messages.add(_Msg(_Role.user, text));
      _generating = true;
    });
    _controller.clear();
    _scrollToBottom();

    // 👇 NEW: wait once for page fetch to finish (or timeout) before first answer
    await _ensurePageReady();

    final ctx = (_pageText != null && _pageText!.isNotEmpty)
        ? '''
You are given the content of a web page at:
${widget.url}

[PAGE_TEXT_START]
${_pageText!}
[PAGE_TEXT_END]

Follow the user’s instruction about this page.
- If asked “summarize”, write 1 compact paragraph.
- If asked “extract key points”, give 5–8 crisp bullets (≤18 words each).
- If asked “outline”, list the major headings/subheadings.
- If asked “FAQs”, list short Q&A pairs.
- For specific questions, answer based only on this page. If unsure, say so briefly.
'''
        : '''
You are assisting with this URL: ${widget.url}

The page text could not be fetched (paywall or blocked). If possible,
answer from your knowledge; otherwise, ask the user to paste the relevant text
or upload a PDF/screenshot.
- Be brief by default.
- If you need more context, ask exactly one short clarifying question.
''';

    final prompt = '$ctx\n\nUser message:\n$text';

    String answer;
    try {
      answer = await GPMaiBrain.send(prompt);
    } catch (e) {
      answer = 'Sorry — I hit an error: $e';
    }

    final clean =
        answer.replaceAll(RegExp(r'\[mood:.*?\]', caseSensitive: false), '').trim();

    if (!mounted) return;
    setState(() {
      _messages.add(_Msg(_Role.bot, clean.isEmpty ? '(no answer)' : clean));
      _generating = false;
    });
    _scrollToBottom();
  }

  void _tapChip(String label) {
    final base = switch (label) {
      'Summarize' => 'Please summarize this page:',
      'Extract key points' => 'Extract 5–8 key points from this page:',
      'Outline headings' => 'Create an outline of headings from this page:',
      'Find FAQs' => 'List likely FAQs with short answers from this page:',
      _ => 'Help me with this page:'
    };
    _controller.text = '$base ${widget.url}';
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask about URL'),
        actions: [
          IconButton(
            tooltip: 'Open link',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final u = Uri.parse(widget.url);
              if (await ul.canLaunchUrl(u)) {
                await ul.launchUrl(u, mode: ul.LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Couldn’t open this URL.')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_fetching) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
              itemCount: _messages.length + (_generating ? 1 : 0),
              itemBuilder: (_, i) {
                if (_generating && i == _messages.length) {
                  return const _TypingBubble();
                }
                final m = _messages[i];
                final isUser = m.role == _Role.user;
                final bg = isUser
                    ? (isLight ? const Color(0xFFEFF8FF) : const Color(0xFF0F1218))
                    : (isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22));
                final border =
                    isUser ? Border.all(color: _electricBlue, width: 1.2) : null;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                      isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!isUser) ...[
                      const SizedBox(width: 6),
                      const _UrlAvatar(),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(18),
                          border: border,
                        ),
                        child: SelectableText(
                          m.text,
                          style: TextStyle(
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (isUser) const SizedBox(width: 6),
                  ],
                );
              },
            ),
          ),

          // Suggestion chips
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(s),
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                  onPressed: () => _tapChip(s),
                  backgroundColor: _urlAccent.withOpacity(.14),
                  shape: StadiumBorder(
                    side: BorderSide(color: _urlAccent.withOpacity(.35)),
                  ),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                );
              }).toList(),
            ),
          ),

          // Composer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SmallRound(
                    icon: Icons.link_rounded,
                    color: _urlAccent,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: widget.url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('URL copied')),
                      );
                    },
                    tooltip: 'Copy URL',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ExpandableTextBox(
                      controller: _controller,
                      focusNode: _focus,
                      isLight: isLight,
                      borderColor: _urlAccent,
                      onExpandSend: (value) => _send(value),
                      hintText: 'Ask about this page…',
                      attachmentPreview: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _generating ? null : () => _send(_controller.text),
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: _electricBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child:
                            Icon(Icons.arrow_upward_rounded, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Invisible WebView host (keeps UI unchanged)
          if (_wvCtrl != null)
            Offstage(
              offstage: true,
              child: SizedBox(
                height: 1,
                width: 1,
                child: WebViewWidget(controller: _wvCtrl!),
              ),
            ),
        ],
      ),
    );
  }
}

/// Purple URL avatar to match the space icon color.
class _UrlAvatar extends StatelessWidget {
  const _UrlAvatar();

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: _urlAccent.withOpacity(.20),
      child: const Icon(Icons.language_rounded, color: _urlAccent, size: 20),
    );
  }
}

/// Tiny bubble while generating.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg =
        isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22);

    Widget dot(double s) => Transform.scale(
          scale: s,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const _UrlAvatar(),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  dot(0.8 + _ctrl.value * 0.4),
                  const SizedBox(width: 6),
                  dot(0.7 + (1 - _ctrl.value) * 0.5),
                  const SizedBox(width: 6),
                  dot(0.8 + _ctrl.value * 0.4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallRound extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;
  const _SmallRound({
    required this.icon,
    required this.color,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    const w = 42.0;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(w / 2),
        child: Ink(
          width: w,
          height: w,
          decoration: BoxDecoration(
            color: color.withOpacity(.14),
            border: Border.all(color: color.withOpacity(.38)),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
