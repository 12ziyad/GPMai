// lib/spaces/yt_summary_page.dart
// YouTube Summary & Ask — refreshed.
// - Fixed player sizing when YouTube forces the watch page (no more half-shrunk header)
// - Transcript → Highlights (concise, jumpable; uses captions/page text)
// - Persistent Notes per video (save/list/delete)
// - Softer colors, more breathing room, small UI tune-ups
//
// Requires: http, url_launcher, share_plus, path_provider, pdf, webview_flutter, xml

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:xml/xml.dart' as xml;

import '../services/gpmai_brain.dart';

/// Brand accents
const _ytRed = Color(0xFFE11D48); // rose-600
const _ytRedDark = Color(0xFF9F1239); // rose-700
const _electricBlue = Color(0xFF00B8FF);

/// ───────────────────────── Home (Recents) ─────────────────────────

class YTSummaryHomePage extends StatefulWidget {
  const YTSummaryHomePage({super.key});
  @override
  State<YTSummaryHomePage> createState() => _YTSummaryHomePageState();
}

class _YtItem {
  final String id; // videoId
  final String title;
  final String url;
  final String thumb;
  final String preview; // snippet for recent card
  _YtItem({
    required this.id,
    required this.title,
    required this.url,
    required this.thumb,
    required this.preview,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'url': url, 'thumb': thumb, 'preview': preview};
  static _YtItem fromJson(Map<String, dynamic> m) => _YtItem(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        url: m['url'] ?? '',
        thumb: m['thumb'] ?? '',
        preview: m['preview'] ?? '',
      );
}

class _YTSummaryHomePageState extends State<YTSummaryHomePage> {
  final List<_YtItem> _items = [];
  bool _loading = true;

  Future<File> _storeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/yt_recents.json');
  }

  Future<void> _load() async {
    try {
      final f = await _storeFile();
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as List;
        _items
          ..clear()
          ..addAll(j.map((e) => _YtItem.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      final f = await _storeFile();
      final j = jsonEncode(_items.map((e) => e.toJson()).toList());
      await f.writeAsString(j);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _addFlow() async {
    final link = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AddLinkSheet(),
    );
    if (link == null || link.trim().isEmpty) return;

    final id = _extractVideoId(link.trim());
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t read that YouTube link.')),
      );
      return;
    }

    // fetch meta (title + thumb) via oEmbed → robust & fast
    final meta = await _fetchMeta(link);
    final item = _YtItem(
      id: id,
      title: meta['title'] ?? 'YouTube video',
      url: _normalizeYouTubeUrl(link),
      thumb: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      preview: meta['preview'] ?? '',
    );

    // persist & open detail
    setState(() {
      _items.removeWhere((e) => e.id == id);
      _items.insert(0, item);
    });
    await _save();

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _YTDetailPage(item: item)),
    ).then((_) => _load());
  }

  Future<Map<String, String>> _fetchMeta(String url) async {
    try {
      final res =
          await http.get(Uri.parse('https://noembed.com/embed?url=${Uri.encodeComponent(url)}'));
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final title = (m['title'] as String?) ?? '';
        final auth = (m['author_name'] as String?) ?? '';
        return {
          'title': title,
          'preview': '${title.isNotEmpty ? title : 'YouTube'}${auth.isNotEmpty ? ' — $auth' : ''}',
        };
      }
    } catch (_) {}
    return const {'title': 'YouTube video', 'preview': ''};
  }

  void _openNotesSheet(_YtItem it) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AskNotesSheet(
        item: it,
        lang: const _Lang('English', 'en'),
        basisBuilder: () async {
          final segs = await _fetchTranscript(it.id, lang: 'en');
          if (segs.isNotEmpty) return _segmentsToPlainText(segs);
          final alt = await _fetchReadablePage(it.id);
          return alt.isNotEmpty ? alt : it.title;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube Summary & Ask'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _ytRed,
        foregroundColor: Colors.white,
        onPressed: _addFlow,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_items.isEmpty
              ? const Center(child: Text('Add your first video with the + button.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => _YTDetailPage(item: it)),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  it.thumb,
                                  width: 96,
                                  height: 54,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(it.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(
                                      it.preview,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => _YTDetailPage(item: it)),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: cs.surfaceVariant,
                                            foregroundColor: cs.onSurface,
                                            shape: StadiumBorder(
                                              side: BorderSide(
                                                  color: cs.onSurface.withOpacity(.18)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.play_circle),
                                          label: const Text('Open Summary'),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _openNotesSheet(it),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _electricBlue,
                                            foregroundColor: Colors.black,
                                            shape: const StadiumBorder(),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                          ),
                                          icon: const Icon(Icons.note_alt_outlined),
                                          label: const Text('Video Notes'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'share') {
                                    await Share.share(it.url);
                                  } else if (v == 'delete') {
                                    setState(() => _items.removeAt(i));
                                    await _save();
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'share', child: Text('Share link')),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete from Recents',
                                          style: TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )),
    );
  }
}

/// ───────────────────────── Add link sheet ─────────────────────────

class _AddLinkSheet extends StatefulWidget {
  const _AddLinkSheet();

  @override
  State<_AddLinkSheet> createState() => _AddLinkSheetState();
}

class _AddLinkSheetState extends State<_AddLinkSheet> {
  final _ctrl = TextEditingController();
  bool _valid = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() => _valid = _extractVideoId(_ctrl.text.trim()) != null);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _ytRed.withOpacity(.12),
                    border: Border.all(color: _ytRed.withOpacity(.35)),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: _ytRed),
                ),
                const SizedBox(width: 12),
                const Text('Enter a YouTube link',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final raw = data?.text ?? '';
                    if (raw.isEmpty) return;
                    // find first YouTube URL inside any pasted text
                    final url = _firstYouTubeUrlInText(raw) ?? raw.trim();
                    _ctrl.text = url;
                  },
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Paste'),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://youtu.be/… or youtube.com/watch?v=…',
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _ytRed),
                  ),
                ),
                onSubmitted: (_) {
                  if (_valid) Navigator.pop(context, _ctrl.text.trim());
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final u =
                          Uri.tryParse(_normalizeYouTubeUrl(_ctrl.text.trim()));
                      if (u != null) {
                        await launchUrl(u, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Open YouTube'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _valid ? () => Navigator.pop(context, _ctrl.text.trim()) : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _valid ? _ytRed : cs.surfaceVariant,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue'),
                  )
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ───────────────────────── Detail page ─────────────────────────

class _YTDetailPage extends StatefulWidget {
  final _YtItem item;
  const _YTDetailPage({required this.item});

  @override
  State<_YTDetailPage> createState() => _YTDetailPageState();
}

class _YTDetailPageState extends State<_YTDetailPage> {
  late final String _videoId = widget.item.id;
  late final WebViewController _web;
  bool _embedOk = true; // if blocked, we’ll switch to watch view
  bool _loadingPlayer = true;
  bool _inWatchView = false; // true if showing m.youtube.com/watch

  // language & sections
  final List<_Lang> _langs = const [
    _Lang('English', 'en'),
    _Lang('हिन्दी', 'hi'),
    _Lang('தமிழ்', 'ta'),
    _Lang('తెలుగు', 'te'),
    _Lang('ಕನ್ನಡ', 'kn'),
    _Lang('മലയാളം', 'ml'),
    _Lang('मराठी', 'mr'),
    _Lang('বাংলা', 'bn'),
    _Lang('ગુજરાતી', 'gu'),
    _Lang('ਪੰਜਾਬੀ', 'pa'),
    _Lang('اردو', 'ur'),
    _Lang('العربية', 'ar'),
    _Lang('فارسی', 'fa'),
    _Lang('中文 (简体)', 'zh-Hans'),
    _Lang('中文 (繁體)', 'zh-Hant'),
    _Lang('日本語', 'ja'),
    _Lang('한국어', 'ko'),
    _Lang('ไทย', 'th'),
    _Lang('Tiếng Việt', 'vi'),
    _Lang('Bahasa Indonesia', 'id'),
    _Lang('Español', 'es'),
    _Lang('Português', 'pt'),
    _Lang('Français', 'fr'),
    _Lang('Deutsch', 'de'),
    _Lang('Italiano', 'it'),
    _Lang('Türkçe', 'tr'),
    _Lang('Русский', 'ru'),
    _Lang('Українська', 'uk'),
    _Lang('Polski', 'pl'),
    _Lang('Română', 'ro'),
    _Lang('Ελληνικά', 'el'),
    _Lang('Nederlands', 'nl'),
  ];
  _Lang _lang = const _Lang('English', 'en');

  String? _keyPoints;
  String? _summary;
  List<_Segment>? _transcript;
  bool _loadingSummary = true;
  bool _loadingHighlights = false;

  // chapters (major parts)
  List<_Chapter>? _chapters;
  bool _loadingChapters = false;

  Timer? _probeTimer1;
  Timer? _probeTimer2;

  @override
  void initState() {
    super.initState();
    _initWeb();
    _summarize();
  }

  @override
  void dispose() {
    _probeTimer1?.cancel();
    _probeTimer2?.cancel();
    super.dispose();
  }

  void _initWeb() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) async {
            final u = req.url;
            // Keep everything in-app. If YouTube tries to bounce to app/intent, prevent.
            if (u.startsWith('intent:') || u.startsWith('vnd.youtube:')) {
              return NavigationDecision.prevent;
            }
            // If user taps “Watch on YouTube”, load the watch page INSIDE WebView.
            if (_isYouTubeWatchUrl(u) || u.contains('/shorts/')) {
              _loadWatchInWeb(url: u);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            setState(() => _loadingPlayer = false);
            // Probe for blocked embeds / "Watch on YouTube" overlays.
            _scheduleProbes();
          },
          onWebResourceError: (_) {
            // Switch to in-app watch view (works for most blocked embeds)
            _loadWatchInWeb();
          },
        ),
      )
      ..loadRequest(Uri.parse(
          'https://www.youtube-nocookie.com/embed/$_videoId?rel=0&modestbranding=1'));
  }

  void _scheduleProbes() {
    if (_inWatchView) return;
    _probeTimer1?.cancel();
    _probeTimer2?.cancel();

    _probeTimer1 = Timer(const Duration(milliseconds: 450), _probeEmbedForBlock);
    _probeTimer2 = Timer(const Duration(seconds: 2), _probeEmbedForBlock);
  }

  Future<void> _probeEmbedForBlock() async {
    if (_inWatchView) return;
    try {
      final js = '''
(function(){
  try {
    const err = document.querySelector('.ytp-error-content-wrap');
    const watch = document.querySelector('.ytp-watch-on-youtube-button');
    const textErr = document.body && document.body.innerText && document.body.innerText.toLowerCase().includes('video unavailable');
    return (!!err || !!watch || textErr) ? '1' : '0';
  } catch(e) { return '0'; }
})()
''';
      final res = await _web.runJavaScriptReturningResult(js);
      final blocked = ('$res').contains('1');
      if (blocked) _loadWatchInWeb();
    } catch (_) {/* ignore */}
  }

  void _loadWatchInWeb({String? url, int? start}) {
    _embedOk = false;
    _inWatchView = true;
    _loadingPlayer = true;
    final t = (start ?? 0) <= 0 ? '' : '&t=${start!.round()}s';
    final target =
        url ?? 'https://m.youtube.com/watch?v=$_videoId$t&app=desktop&persist_app=1';
    _web.loadRequest(Uri.parse(target));
    if (mounted) setState(() {});
  }

  Future<void> _jumpTo(int seconds) async {
    setState(() => _loadingPlayer = true);
    if (_inWatchView) {
      _web.loadRequest(Uri.parse(
          'https://m.youtube.com/watch?v=$_videoId&t=${seconds}s&persist_app=1'));
    } else {
      _web.loadRequest(Uri.parse(
          'https://www.youtube-nocookie.com/embed/$_videoId?start=$seconds&autoplay=1&rel=0&modestbranding=1'));
    }
  }

  Future<void> _summarize() async {
    setState(() {
      _loadingSummary = true;
    });

    // Prefer transcript text; fallback to r.jina.ai page text; last resort: title only
    String basis = '';
    final t = await _fetchTranscript(_videoId, lang: _lang.code);
    if (t.isNotEmpty) {
      _transcript = t;
      basis = _segmentsToPlainText(t);
    } else {
      final alt = await _fetchReadablePage(_videoId);
      if (alt.isNotEmpty) basis = alt;
    }
    if (basis.isEmpty) {
      basis = 'Title: ${widget.item.title}';
    }

    final keyPrompt = '''
You are given raw text for a YouTube video. Produce 6–8 crisp bullet points (≤18 words each).
Avoid repetition. No preface.
[TEXT START]
$basis
[TEXT END]

Write the bullets in ${_lang.name}.
''';

    final sumPrompt = '''
Write one compact paragraph (80–120 words) summarizing the video content above.
Avoid repeating the bullets verbatim. Stay factual; if uncertain, say "not available".
Write in ${_lang.name}.
[TEXT START]
$basis
[TEXT END]
''';

    String keys = '', sum = '';
    try {
      keys = await GPMaiBrain.send(keyPrompt);
    } catch (_) {}
    try {
      sum = await GPMaiBrain.send(sumPrompt);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _keyPoints = _clean(keys);
      _summary = _clean(sum);
      _loadingSummary = false;
    });

    // Build chapters once we have transcript
    unawaited(_ensureChapters());
  }

  Future<void> _reloadForLang(_Lang l) async {
    setState(() => _lang = l);
    await _summarize();
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'\[mood:.*?\]', caseSensitive: false), '').trim();

  Future<void> _ensureChapters() async {
    if (_chapters != null) return;
    setState(() => _loadingChapters = true);

    List<_Chapter> out = [];
    // Load user-edited chapters from disk first
    out = await _loadChaptersFromDisk(_videoId);
    if (out.isEmpty) {
      // need transcript
      List<_Segment> segs = _transcript ?? [];
      if (segs.isEmpty) {
        segs = await _fetchTranscript(_videoId, lang: _lang.code);
        _transcript = segs.isEmpty ? null : segs;
      }
      out = await _autoChaptersFromTranscript(segs);
      if (out.isNotEmpty) {
        await _saveChaptersToDisk(_videoId, out);
      }
    }

    if (!mounted) return;
    setState(() {
      _chapters = out;
      _loadingChapters = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelp(context),
          ),
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => Share.share(widget.item.url),
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _playerSection(),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _LangChip(
                value: _lang,
                options: _langs,
                onChanged: (l) => _reloadForLang(l),
              ),
              // Transcript -> Highlights
              ActionChip(
                avatar: _loadingHighlights
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Highlights'),
                onPressed: _openHighlights,
                backgroundColor: _ytRed.withOpacity(.12),
                shape: StadiumBorder(
                  side: BorderSide(color: _ytRed.withOpacity(.35)),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              ActionChip(
                avatar: _loadingChapters
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.video_collection_rounded, size: 16),
                label: const Text('Chapters'),
                onPressed: () async {
                  await _ensureChapters();
                  if (!mounted) return;
                  _showChaptersEditor();
                },
                backgroundColor: _ytRed.withOpacity(.12),
                shape: StadiumBorder(
                  side: BorderSide(color: _ytRed.withOpacity(.35)),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // Quick notes entry point (also available via FAB)
              ActionChip(
                avatar: const Icon(Icons.note_alt_outlined, size: 16),
                label: const Text('Notes'),
                onPressed: _openAskNotes,
                backgroundColor: _electricBlue.withOpacity(.18),
                shape: StadiumBorder(
                  side: BorderSide(color: _electricBlue.withOpacity(.42)),
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((_chapters ?? []).isNotEmpty)
            _ChipsChapters(
              chapters: _chapters!,
              onTap: (c) => _jumpTo(c.start.round()),
            ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Key points',
                  style:
                      TextStyle(color: _ytRed, fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadingSummary ? null : _summarize,
                icon: _loadingSummary
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              )
            ],
          ),
          const SizedBox(height: 6),
          if (_loadingSummary)
            const _ShimmerLines()
          else if ((_keyPoints ?? '').isEmpty)
            const Text('No key points available.')
          else
            _Bullets(text: _keyPoints!),

          const SizedBox(height: 18),
          const Text('Summary',
              style:
                  TextStyle(color: _ytRed, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (_loadingSummary)
            const _ShimmerLines(count: 5)
          else if ((_summary ?? '').isEmpty)
            const Text('No summary available.')
          else
            const SizedBox(height: 2),
          if ((_summary ?? '').isNotEmpty)
            Text(_summary!, style: const TextStyle(height: 1.35)),
        ],
      ),
      floatingActionButton: _AskAndNoteFab(onTap: _openAskNotes),
    );
  }

  Widget _playerSection() {
    // When YouTube forces the "watch" page (with top header),
    // use extra height so the video is never half-visible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final base = w * 9 / 16;
        final extra = _inWatchView ? 120.0 : 0.0; // space for YouTube header/controls
        final h = base + extra;

        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              SizedBox(
                height: h,
                width: double.infinity,
                child: WebViewWidget(controller: _web),
              ),
              if (_loadingPlayer)
                Positioned.fill(
                  child: Container(
                    color: Colors.black12,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(widget.item.url),
                      mode: LaunchMode.externalApplication),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: StadiumBorder(side: BorderSide(color: Colors.white12)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open YouTube'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openAskNotes() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AskNotesSheet(
        item: widget.item,
        lang: _lang,
        basisBuilder: () async {
          if (_transcript != null && _transcript!.isNotEmpty) {
            return _segmentsToPlainText(_transcript!);
          }
          return (_summary?.isNotEmpty ?? false) ? _summary! : widget.item.title;
        },
      ),
    );
  }

  Future<void> _openHighlights() async {
    setState(() => _loadingHighlights = true);

    // Ensure transcript or readable text exists
    List<_Segment> segs = _transcript ?? [];
    if (segs.isEmpty) {
      segs = await _fetchTranscript(_videoId, lang: _lang.code);
      _transcript = segs.isEmpty ? null : segs;
    }

    final List<_Highlight> highlights = await _makeHighlights(_videoId, segs, lang: _lang);

    setState(() => _loadingHighlights = false);

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _HighlightsPage(
        title: widget.item.title,
        videoUrl: widget.item.url,
        highlights: highlights,
        onJump: (t) => _jumpTo(t.round()),
      ),
    ));
  }

  Future<void> _exportPdf() async {
    try {
      final pdf = pw.Document();

      // Load notes (if any)
      final notes = await _loadNotesForVideo(_videoId);

      pdf.addPage(
        pw.Page(
          build: (c) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(widget.item.title,
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.UrlLink(
                    destination: widget.item.url,
                    child: pw.Text(widget.item.url,
                        style: pw.TextStyle(color: PdfColor.fromInt(0xFF1565C0)))),
                pw.SizedBox(height: 12),
                pw.Text('Key points',
                    style:
                        pw.TextStyle(fontSize: 16, color: PdfColor.fromInt(_ytRed.value))),
                pw.SizedBox(height: 6),
                pw.Text(_keyPoints ?? '(none)'),
                pw.SizedBox(height: 12),
                pw.Text('Summary',
                    style:
                        pw.TextStyle(fontSize: 16, color: PdfColor.fromInt(_ytRed.value))),
                pw.SizedBox(height: 6),
                pw.Text(_summary ?? '(none)'),
                if (notes.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  pw.Text('My Notes',
                      style: pw.TextStyle(
                          fontSize: 16, color: PdfColor.fromInt(_electricBlue.value))),
                  pw.SizedBox(height: 6),
                  for (final n in notes)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Text('• ${n.text}'),
                    ),
                ],
              ],
            );
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/youtube_summary_${_videoId}.pdf';
      final f = File(path);
      await f.writeAsBytes(await pdf.save());

      if (!mounted) return;
      await Share.shareXFiles([XFile(f.path)], text: widget.item.title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('About this page'),
        content: const Text(
          '• If the embed is blocked, it auto-switches to an in-app YouTube page (extra height so it fits).\n'
          '• Tap Chapters to jump to important parts (edit & save).\n'
          '• Highlights are concise, time-stamped nuggets generated from captions.\n'
          '• Notes are saved per video and included when you export PDF.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<List<_Chapter>> _autoChaptersFromTranscript(List<_Segment> segs) async {
    try {
      if (segs.isEmpty) return [];
      // Build a compact lines text with timestamps
      final buf = StringBuffer();
      for (final s in segs.take(400)) {
        buf.writeln('${_formatTime(s.start)}  ${s.text}');
      }
      final basis = buf.toString();
      final prompt = '''
Divide this video into 5–8 main chapters.
Return STRICT JSON array like:
[{"t": 0, "title": "Intro"}, {"t": 85, "title": "Key Topic"}, ...]

Rules:
- "t" = start time in seconds (use the nearest timestamp).
- Titles 2–6 words; no emojis.
- Start at 0 if unsure about the first time.

[BASIS]
$basis
[/BASIS]
''';
      final raw = await GPMaiBrain.send(prompt);
      final cleaned =
          raw.replaceAll(RegExp(r'```json|```', multiLine: true), '').trim();
      final arr = jsonDecode(cleaned) as List;
      final out = arr
          .map((e) => _Chapter(
                (e['t'] as num).toDouble(),
                (e['title'] ?? '').toString(),
              ))
          .where((c) => c.title.trim().isNotEmpty)
          .toList();
      out.sort((a, b) => a.start.compareTo(b.start));
      return out;
    } catch (_) {
      // fallback: equally spaced chapters
      if (segs.isEmpty) return [];
      final total = (segs.last.start + segs.last.dur).round();
      final parts = 6;
      final step = (total / parts).floor().clamp(45, 240);
      final out = <_Chapter>[];
      for (int i = 0; i < parts; i++) {
        final t = i * step;
        out.add(_Chapter(t.toDouble(), 'Part ${i + 1}'));
      }
      return out;
    }
  }

  Future<void> _showChaptersEditor() async {
    if (!mounted) return;
    final list = List<_Chapter>.from(_chapters ?? const []);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final tcList =
            list.map((c) => TextEditingController(text: c.title)).toList();
        final timeCtrls =
            list.map((c) => TextEditingController(text: _formatTime(c.start))).toList();

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              left: 16,
              right: 16,
              top: 8),
          child: StatefulBuilder(builder: (ctx, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit chapters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 360,
                  child: ReorderableListView(
                    onReorder: (a, b) {
                      setLocal(() {
                        if (b > a) b -= 1;
                        final c = list.removeAt(a);
                        final t1 = tcList.removeAt(a);
                        final t2 = timeCtrls.removeAt(a);
                        list.insert(b, c);
                        tcList.insert(b, t1);
                        timeCtrls.insert(b, t2);
                      });
                    },
                    children: [
                      for (int i = 0; i < list.length; i++)
                        Card(
                          key: ValueKey('row$i'),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Icon(Icons.drag_handle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: tcList[i],
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) => list[i].title = v,
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: timeCtrls[i],
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Start (mm:ss or hh:mm:ss)',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) => list[i].start =
                                            _parseClockToSeconds(v).toDouble(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded,
                                      color: Colors.redAccent),
                                  onPressed: () {
                                    setLocal(() {
                                      list.removeAt(i);
                                      tcList.removeAt(i);
                                      timeCtrls.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setLocal(() {
                          list.add(_Chapter(0, 'New chapter'));
                          tcList.add(TextEditingController(text: 'New chapter'));
                          timeCtrls.add(TextEditingController(text: '00:00'));
                        });
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () async {
                        list.sort((a, b) => a.start.compareTo(b.start));
                        await _saveChaptersToDisk(_videoId, list);
                        if (mounted) {
                          setState(() => _chapters = List<_Chapter>.from(list));
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ytRed,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            );
          }),
        );
      },
    );
  }
}

/// ───────────────────────── Highlights viewer ─────────────────────────

class _Highlight {
  final double t;
  final String text;
  _Highlight(this.t, this.text);
}

class _HighlightsPage extends StatelessWidget {
  final String title;
  final String videoUrl;
  final List<_Highlight> highlights;
  final ValueChanged<double> onJump;

  const _HighlightsPage({
    required this.title,
    required this.videoUrl,
    required this.highlights,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open YouTube',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () =>
                launchUrl(Uri.parse(videoUrl), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: highlights.isEmpty
          ? const Center(child: Text('Highlights unavailable.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: highlights.length,
              itemBuilder: (_, i) {
                final h = highlights[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _ytRed.withOpacity(.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _ytRed.withOpacity(.35)),
                      ),
                      child: Text(
                        _formatTime(h.t),
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(h.text),
                    trailing: const Icon(Icons.play_arrow_rounded),
                    onTap: () => onJump(h.t),
                  ),
                );
              },
            ),
    );
  }
}

/// ───────────────────────── Ask + Notes sheet ─────────────────────────

class _AskNotesSheet extends StatefulWidget {
  final _YtItem item;
  final _Lang lang;
  final Future<String> Function() basisBuilder;
  const _AskNotesSheet(
      {required this.item, required this.lang, required this.basisBuilder});

  @override
  State<_AskNotesSheet> createState() => _AskNotesSheetState();
}

class _NoteItem {
  final int ts;
  final String text;
  _NoteItem(this.ts, this.text);
  Map<String, dynamic> toJson() => {'ts': ts, 'text': text};
  static _NoteItem fromJson(Map<String, dynamic> m) =>
      _NoteItem((m['ts'] as num).toInt(), (m['text'] ?? '').toString());
}

class _AskNotesSheetState extends State<_AskNotesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);
  final _noteCtrl = TextEditingController();
  final _askCtrl = TextEditingController();
  String? _answer;
  bool _loading = false;

  List<_NoteItem> _notes = [];
  bool _notesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _tc.dispose();
    _noteCtrl.dispose();
    _askCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final list = await _loadNotesForVideo(widget.item.id);
    if (!mounted) return;
    setState(() {
      _notes = list;
      _notesLoading = false;
    });
  }

  Future<void> _saveNote() async {
    final txt = _noteCtrl.text.trim();
    if (txt.isEmpty) return;
    final it = _NoteItem(DateTime.now().millisecondsSinceEpoch, txt);
    await _appendNoteForVideo(widget.item.id, it);
    _noteCtrl.clear();
    await _loadNotes();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Note saved')));
  }

  Future<void> _deleteNote(int index) async {
    final list = List<_NoteItem>.from(_notes)..removeAt(index);
    await _writeNotesForVideo(widget.item.id, list);
    await _loadNotes();
  }

  Future<void> _ask() async {
    final q = _askCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _answer = null;
      _loading = true;
    });
    final basis = await widget.basisBuilder();
    final prompt = '''
You are answering questions strictly about this YouTube video.
If the answer isn't present in the provided text, say briefly "not available in the video".
Write in ${widget.lang.name}.
[TEXT START]
$basis
[TEXT END]

Question: $q
''';
    String a = '';
    try {
      a = await GPMaiBrain.send(prompt);
    } catch (e) {
      a = 'Error: $e';
    }
    if (!mounted) return;
    setState(() {
      _answer = a.replaceAll(RegExp(r'\[mood:.*?\]', caseSensitive: false), '').trim();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .70,
          child: Column(
            children: [
              TabBar(
                controller: _tc,
                labelColor: _ytRed,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                tabs: const [Tab(text: 'Add note'), Tab(text: 'Ask about')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tc,
                  children: [
                    // Notes
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: [
                          _RoundedField(
                              controller: _noteCtrl, hint: 'Write a note…'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _saveNote,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _ytRed,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  icon: const Icon(Icons.save_alt_rounded),
                                  label: const Text('Save note'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Saved notes',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(.75),
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _notesLoading
                                ? const Center(child: CircularProgressIndicator())
                                : (_notes.isEmpty
                                    ? const Center(
                                        child: Opacity(
                                            opacity: .7,
                                            child: Text('No notes yet.')))
                                    : ListView.separated(
                                        itemCount: _notes.length,
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (_, i) {
                                          final n = _notes[i];
                                          return Card(
                                            child: ListTile(
                                              title: Text(n.text),
                                              subtitle: Text(
                                                DateTime.fromMillisecondsSinceEpoch(
                                                        n.ts)
                                                    .toLocal()
                                                    .toString(),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete_rounded,
                                                    color: Colors.redAccent),
                                                onPressed: () => _deleteNote(i),
                                              ),
                                            ),
                                          );
                                        },
                                      )),
                          ),
                        ],
                      ),
                    ),
                    // Ask
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: [
                          _RoundedField(
                              controller: _askCtrl,
                              hint: 'Ask anything about this video…'),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _loading ? null : _ask,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _electricBlue,
                              foregroundColor: Colors.black,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.send_rounded),
                            label: Text(_loading ? 'Loading…' : 'Ask'),
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: Container(
                              alignment: Alignment.topLeft,
                              child: _loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : (_answer == null
                                      ? const Opacity(
                                          opacity: .7,
                                          child: Text(
                                              'Ask a question to see the answer here.'))
                                      : SelectableText(_answer!)),
                            ),
                          ),
                        ],
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

/// ───────────────────────── Small widgets ─────────────────────────

class _AskAndNoteFab extends StatelessWidget {
  final VoidCallback onTap;
  const _AskAndNoteFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'notes',
          backgroundColor: _electricBlue,
          foregroundColor: Colors.black,
          onPressed: onTap,
          child: const Icon(Icons.chat_bubble_rounded),
        ),
      ],
    );
  }
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _RoundedField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(.16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _ytRed.withOpacity(.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _electricBlue, width: 1.6),
        ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  final String text;
  const _Bullets({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  ', style: TextStyle(fontSize: 16, height: 1.35)),
                Expanded(
                    child: Text(l.replaceAll(RegExp(r'^[•\-]\s*'), ''),
                        style: const TextStyle(height: 1.35))),
              ],
            ),
          ),
      ],
    );
  }
}

class _ShimmerLines extends StatelessWidget {
  final int count;
  const _ShimmerLines({this.count = 8});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: List.generate(
        count,
        (i) => Container(
          height: 12,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(.35),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

class _Lang {
  final String name;
  final String code;
  const _Lang(this.name, this.code);
}

class _LangChip extends StatelessWidget {
  final _Lang value;
  final List<_Lang> options;
  final ValueChanged<_Lang> onChanged;
  const _LangChip(
      {required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Lang>(
      onSelected: onChanged,
      itemBuilder: (_) =>
          options.map((l) => PopupMenuItem(value: l, child: Text(l.name))).toList(),
      child: Chip(
        label: Text(value.name),
        avatar: const Icon(Icons.language_rounded, size: 18),
        backgroundColor: _ytRed.withOpacity(.12),
        shape: StadiumBorder(side: BorderSide(color: _ytRed.withOpacity(.35))),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ChipsChapters extends StatelessWidget {
  final List<_Chapter> chapters;
  final ValueChanged<_Chapter> onTap;
  const _ChipsChapters({required this.chapters, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chapters
          .map((c) => ActionChip(
                onPressed: () => onTap(c),
                backgroundColor: _ytRed.withOpacity(.10),
                shape:
                    StadiumBorder(side: BorderSide(color: _ytRed.withOpacity(.35))),
                label:
                    Text('${_formatTime(c.start)} – ${c.title}', overflow: TextOverflow.ellipsis),
              ))
          .toList(),
    );
  }
}

/// ───────────────────────── Fetch helpers & persistence ─────────────────────────

String? _extractVideoId(String raw) {
  final s = raw.trim();
  final r = RegExp(
      r'(?:v=|\/shorts\/|youtu\.be\/|\/live\/|\/embed\/)([A-Za-z0-9_-]{6,})');
  final m = r.firstMatch(s);
  if (m != null) return m.group(1);
  // Fallback: first YouTube URL inside the text
  final url = _firstYouTubeUrlInText(s);
  if (url != null) {
    final mm = r.firstMatch(url);
    if (mm != null) return mm.group(1);
  }
  // Fallback: if the whole string is an ID
  if (RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(s)) return s;
  return null;
}

String? _firstYouTubeUrlInText(String text) {
  final re = RegExp(
      r'(https?:\/\/(?:www\.)?(?:m\.)?(?:youtube\.com|youtu\.be)[^\s]+)',
      caseSensitive: false);
  final m = re.firstMatch(text);
  return m?.group(1);
}

String _normalizeYouTubeUrl(String raw) {
  final id = _extractVideoId(raw) ?? raw;
  return 'https://www.youtube.com/watch?v=$id';
}

bool _isYouTubeWatchUrl(String u) =>
    u.contains('youtube.com/watch') ||
    u.contains('m.youtube.com/watch') ||
    u.contains('youtu.be/');

class _Segment {
  final double start;
  final double dur;
  final String text;
  _Segment(this.start, this.dur, this.text);
}

class _Chapter {
  double start;
  String title;
  _Chapter(this.start, this.title);

  Map<String, dynamic> toJson() => {'t': start, 'title': title};
  static _Chapter fromJson(Map<String, dynamic> m) =>
      _Chapter((m['t'] as num).toDouble(), (m['title'] ?? '').toString());
}

Future<List<_Segment>> _fetchTranscript(String id, {String lang = 'en'}) async {
  // Strategy:
  // 1) youtubetranscript.com (JSON)
  // 2) youtubetranscript.com with json3
  // 3) YouTube timedtext XML
  try {
    final u1 =
        Uri.parse('https://youtubetranscript.com/?server_vid2=$id&lang=$lang');
    final r1 = await http.get(u1, headers: const {
      'User-Agent': 'curl/8.0',
      'Accept': 'application/json,text/plain,*/*',
    });
    if (r1.statusCode == 200) {
      try {
        final arr = jsonDecode(r1.body) as List;
        return arr.map((e) {
          final m = e as Map<String, dynamic>;
          final start = double.tryParse('${m['start']}') ?? 0;
          final dur = double.tryParse('${m['dur'] ?? m['duration'] ?? 0}') ?? 0;
          final text =
              (m['text'] ?? '').toString().replaceAll('\n', ' ').trim();
          return _Segment(start, dur, text);
        }).toList();
      } catch (_) {/* fall through */}
    }
  } catch (_) {}

  try {
    final u2 = Uri.parse(
        'https://youtubetranscript.com/?server_vid2=$id&lang=$lang&fmt=json3');
    final r2 = await http.get(u2, headers: const {
      'User-Agent': 'curl/8.0',
      'Accept': 'application/json,text/plain,*/*',
    });
    if (r2.statusCode == 200) {
      final arr = jsonDecode(r2.body) as List;
      return arr.map((e) {
        final m = e as Map<String, dynamic>;
        final start = double.tryParse('${m['start']}') ?? 0;
        final dur = double.tryParse('${m['dur'] ?? m['duration'] ?? 0}') ?? 0;
        final text =
            (m['text'] ?? '').toString().replaceAll('\n', ' ').trim();
        return _Segment(start, dur, text);
      }).toList();
    }
  } catch (_) {}

  try {
    final u3 = Uri.parse('https://video.google.com/timedtext?lang=$lang&v=$id');
    final r3 = await http.get(u3, headers: const {
      'User-Agent': 'curl/8.0',
      'Accept': 'text/xml,*/*',
    });
    if (r3.statusCode == 200 && r3.body.isNotEmpty) {
      final doc = xml.XmlDocument.parse(r3.body);
      final out = <_Segment>[];
      for (final n in doc.findAllElements('text')) {
        final start = double.tryParse(n.getAttribute('start') ?? '0') ?? 0;
        final dur = double.tryParse(n.getAttribute('dur') ?? '0') ?? 0;
        final content = n.innerText
            .replaceAll('\n', ' ')
            .replaceAll('&amp;', '&')
            .trim();
        if (content.isNotEmpty) out.add(_Segment(start, dur, content));
      }
      return out;
    }
  } catch (_) {}

  return [];
}

Future<String> _fetchReadablePage(String id) async {
  try {
    final u = 'https://r.jina.ai/http/https://www.youtube.com/watch?v=$id';
    final res = await http.get(Uri.parse(u), headers: const {
      'User-Agent': 'curl/8.0',
      'Accept': 'text/plain; charset=utf-8',
    });
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = utf8.decode(res.bodyBytes, allowMalformed: true).trim();
      if (body.isNotEmpty) {
        const cap = 12000;
        return body.length > cap ? '${body.substring(0, cap)}…' : body;
      }
    }
  } catch (_) {}
  return '';
}

String _segmentsToPlainText(List<_Segment> segs) {
  final buf = StringBuffer();
  for (final s in segs) {
    buf.writeln('${_formatTime(s.start)}  ${s.text}');
  }
  return buf.toString().trim();
}

String _formatTime(double seconds) {
  final s = seconds.round();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '${two(h)}:${two(m)}:${two(ss)}' : '${two(m)}:${two(ss)}';
}

int _parseClockToSeconds(String clock) {
  final parts = clock.trim().split(':').map((e) {
    final x = int.tryParse(e) ?? 0;
    return x;
  }).toList();
  if (parts.length == 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  } else if (parts.length == 2) {
    return parts[0] * 60 + parts[1];
  }
  return int.tryParse(clock) ?? 0;
}

Future<List<_Chapter>> _loadChaptersFromDisk(String id) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/yt_chapters_$id.json');
    if (!await f.exists()) return [];
    final arr = jsonDecode(await f.readAsString()) as List;
    return arr.map((e) => _Chapter.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
}

Future<void> _saveChaptersToDisk(String id, List<_Chapter> list) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/yt_chapters_$id.json');
    await f.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  } catch (_) {}
}

/// ── Highlights generation (from transcript or readable page) ──
Future<List<_Highlight>> _makeHighlights(
    String id, List<_Segment> segs, {required _Lang lang}) async {
  // If we have captions, ask the brain to pick 10–14 concise highlights w/ times.
  if (segs.isNotEmpty) {
    try {
      final buf = StringBuffer();
      for (final s in segs.take(400)) {
        buf.writeln('${_formatTime(s.start)}  ${s.text}');
      }
      final basis = buf.toString();
      final prompt = '''
From these time-stamped lines, extract 10–14 concise highlights (≤18 words).
Return STRICT JSON:
[{"t": 12, "text": "…"}, {"t": 85, "text": "…"}, ...]

Rules:
- "t" is seconds (nearest timestamp).
- Summarize smartly; no emojis; no quotes.
- Language: ${lang.name}

[BASIS]
$basis
[/BASIS]
''';
      final raw = await GPMaiBrain.send(prompt);
      final cleaned = raw.replaceAll(RegExp(r'```json|```', multiLine: true), '').trim();
      final arr = jsonDecode(cleaned) as List;
      final out = arr
          .map((e) => _Highlight(
                (e['t'] is num) ? (e['t'] as num).toDouble() : (double.tryParse('${e['t']}') ?? 0),
                (e['text'] ?? '').toString(),
              ))
          .where((h) => h.text.trim().isNotEmpty)
          .toList();
      out.sort((a, b) => a.t.compareTo(b.t));
      if (out.isNotEmpty) return out;
    } catch (_) {/* fallthrough */}
  }

  // Fallback: page text → evenly spaced pseudo-highlights
  final page = await _fetchReadablePage(id);
  if (page.isNotEmpty) {
    final paras = page
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.length > 40)
        .toList();
    final total = 9 * 60; // fake duration when we don't know; 9min guess
    final count = paras.length.clamp(6, 12);
    final step = (total / count).floor();
    final out = <_Highlight>[];
    for (int i = 0; i < count; i++) {
      out.add(_Highlight((i * step).toDouble(), paras[i]));
    }
    return out;
  }

  return [];
}

/// ── Notes persistence ──
class _NoteFileItem {
  final int ts;
  final String text;
  _NoteFileItem(this.ts, this.text);
  Map<String, dynamic> toJson() => {'ts': ts, 'text': text};
  static _NoteFileItem fromJson(Map<String, dynamic> m) =>
      _NoteFileItem((m['ts'] as num).toInt(), (m['text'] ?? '').toString());
}

Future<File> _notesFile(String id) async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/yt_notes_$id.json');
}

Future<List<_NoteItem>> _loadNotesForVideo(String id) async {
  try {
    final f = await _notesFile(id);
    if (!await f.exists()) return [];
    final arr = jsonDecode(await f.readAsString()) as List;
    return arr
        .map((e) => _NoteItem((e['ts'] as num).toInt(), (e['text'] ?? '').toString()))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> _writeNotesForVideo(String id, List<_NoteItem> list) async {
  try {
    final f = await _notesFile(id);
    await f.writeAsString(jsonEncode(list.map((e) => {'ts': e.ts, 'text': e.text}).toList()));
  } catch (_) {}
}

Future<void> _appendNoteForVideo(String id, _NoteItem it) async {
  final list = await _loadNotesForVideo(id);
  list.add(it);
  await _writeNotesForVideo(id, list);
}
