// lib/spaces/image_answer_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../brain_channel.dart';            // primary brain (Dart)
import '../services/gpmai_brain.dart';     // fallback text brain (router)
import '../services/image_qa_recents_store.dart';

class ImageAnswerPage extends StatefulWidget {
  const ImageAnswerPage({
    super.key,
    required this.itemId,
    required this.image,
    this.firstPrompt,
    this.autoAskOnOpen = false,
  });

  final String itemId;
  final Uint8List image;
  final String? firstPrompt;
  final bool autoAskOnOpen;

  @override
  State<ImageAnswerPage> createState() => _ImageAnswerPageState();
}

class _ImageAnswerPageState extends State<ImageAnswerPage> {
  /// Mixed global list + a search bar in the picker
  static const List<String> _allLangs = [
    'English','Spanish','French','German','Portuguese','Italian','Dutch','Turkish',
    'Russian','Ukrainian','Polish','Czech','Slovak','Hungarian','Romanian','Greek',
    'Swedish','Norwegian','Danish','Finnish',
    'Arabic','Hebrew','Persian (Farsi)','Swahili',
    'Indonesian','Malay','Vietnamese','Thai','Filipino',
    'Chinese (Simplified)','Chinese (Traditional)','Japanese','Korean',
    // India – kept, but mixed into the list
    'Hindi','Tamil','Malayalam','Telugu','Kannada','Bengali','Urdu',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<ImageQAMessage> _messages = <ImageQAMessage>[];

  // Translation mode
  String? _activeTranslateLang;            // null = original view
  List<ImageQAMessage>? _originalBackup;   // kept in RAM only

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _messages = await ImageQARecentsStore.loadChat(widget.itemId);
    setState(() {});
    // Only auto-ask if this is a brand new session (no prior messages)
    if (widget.firstPrompt != null &&
        widget.autoAskOnOpen &&
        _messages.isEmpty) {
      _input.text = widget.firstPrompt!;
      await _send(vision: true);
    }
  }

  Future<void> _persist() =>
      ImageQARecentsStore.replaceChat(widget.itemId, _messages);

  Future<void> _send({bool vision = true}) async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() => _busy = true);

    // 1) add your message
    final userMsg = ImageQAMessage(role: 'user', text: text);
    _messages.add(userMsg);
    _input.clear();
    await _persist();
    _jumpToEnd();

    // 1a) translate user bubble in place if translate mode is ON
    if (_activeTranslateLang != null) {
      final t = await _translateText(text, _activeTranslateLang!);
      final idx = _messages.indexOf(userMsg);
      if (idx != -1) _messages[idx] = ImageQAMessage(role: 'user', text: t);
      setState(() {});
    }

    // 2) get AI answer
    String reply = '';
    try {
      if (vision) {
        reply = await BrainChannel.visionFirst(
          question: text,
          imageBase64Jpeg: base64Encode(widget.image),
          a11y: '',
          ocr: '',
        );
      } else {
        reply = await BrainChannel.textOnly(
          system: 'Translate/answer briefly when possible.',
          user: text,
          tag: 'ImageQA_Text',
        );
      }
    } catch (_) {
      reply = await GPMaiBrain.send(text);
    }
    if (reply.trim().isEmpty) reply = '[No response]';

    // 3) add AI bubble
    var aiMsg = ImageQAMessage(role: 'ai', text: reply);
    if (_activeTranslateLang != null) {
      // translate the AI bubble before inserting so the swap is seamless
      final t = await _translateText(reply, _activeTranslateLang!);
      aiMsg = ImageQAMessage(role: 'ai', text: t);
    }
    _messages.add(aiMsg);
    await _persist();

    setState(() => _busy = false);
    _jumpToEnd();
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /* -------------------- PDF + Share -------------------- */
  Future<void> _exportPdfAndShare() async {
    try {
      final doc = pw.Document();
      final img = pw.MemoryImage(widget.image);

      doc.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          build: (_) => [
            pw.Text('Image Q&A', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Image(img, height: 220, fit: pw.BoxFit.cover),
            pw.SizedBox(height: 14),
            for (final m in _messages) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: m.role == 'user' ? PdfColors.blue100 : PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(m.role == 'user' ? 'You' : 'GPMai',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(m.text),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          ],
        ),
      );

      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/image_qa_recents');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/${widget.itemId}.pdf');
      await file.writeAsBytes(await doc.save(), flush: true);

      await Share.shareXFiles([XFile(file.path)], text: 'Image Q&A'); // share picker
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF error: $e')));
    }
  }

  /* -------------------- Language picker + translate-in-place -------------------- */

  Future<void> _openLanguagePicker() async {
    String query = '';
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = _allLangs
                .where((l) => l.toLowerCase().contains(query.toLowerCase()))
                .toList(growable: false);

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              minChildSize: 0.35,
              maxChildSize: 0.9,
              builder: (_, controller) => SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search languages…',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (t) => setModalState(() => query = t),
                      ),
                    ),
                    if (_activeTranslateLang != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            avatar: const Icon(Icons.undo_rounded, size: 18),
                            label: const Text('Show original (no translate)'),
                            onPressed: () => Navigator.pop(ctx, '__ORIGINAL__'),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final l = filtered[i];
                          return ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Theme.of(context).dividerColor.withOpacity(.4),
                              ),
                            ),
                            title: Text(l),
                            trailing: const Icon(Icons.translate_rounded),
                            onTap: () => Navigator.pop(ctx, l),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || chosen == null) return;

    if (chosen == '__ORIGINAL__') {
      // restore original view (RAM only) – do not persist translations
      if (_originalBackup != null) {
        setState(() {
          _messages = _originalBackup!
              .map((m) => ImageQAMessage(role: m.role, text: m.text))
              .toList();
          _activeTranslateLang = null;
        });
      }
      return;
    }

    await _applyTranslateInPlace(chosen);
  }

  Future<void> _applyTranslateInPlace(String lang) async {
    if (_busy) return;
    setState(() => _busy = true);

    // Always translate from the original (not layered on top of previous translation)
    _originalBackup = _originalBackup ??
        _messages.map((m) => ImageQAMessage(role: m.role, text: m.text)).toList();

    // Build a full translated copy first (avoids jank/scroll bugs)
    final translated = <ImageQAMessage>[];
    for (final m in _originalBackup!) {
      final t = await _translateText(m.text, lang);
      translated.add(ImageQAMessage(role: m.role, text: t));
    }

    // Swap once
    setState(() {
      _messages = translated;
      _activeTranslateLang = lang;
      _busy = false;
    });
    // Do NOT persist translated bubbles; storage keeps originals only.
  }

  Future<String> _translateText(String text, String lang) async {
    if (text.trim().isEmpty) return text;

    // chunk long messages
    final chunks = _chunkText(text, 1500);
    final out = <String>[];

    for (final part in chunks) {
      final prompt =
          'Translate the following to $lang. Preserve line breaks and bullet points. '
          'Return only the translation without extra commentary.\n\n$part';

      try {
        var piece = await BrainChannel.textOnly(
          system: 'You are a precise translator.',
          user: prompt,
          tag: 'TranslateBubble',
        );
        if (piece.trim().isEmpty || piece == '[No response]') {
          piece = await GPMaiBrain.send(
            prompt,
            systemPrompt:
                'You are a precise translator. Output only the translation.',
          );
        }
        out.add(piece.trim());
      } catch (_) {
        final piece = await GPMaiBrain.send(
          prompt,
          systemPrompt:
              'You are a precise translator. Output only the translation.',
        );
        out.add(piece.trim());
      }
    }

    return out.join('\n').trim();
  }

  List<String> _chunkText(String s, int maxLen) {
    if (s.length <= maxLen) return [s];
    final out = <String>[];
    var i = 0;
    while (i < s.length) {
      var end = (i + maxLen < s.length) ? i + maxLen : s.length;
      final cut = s.lastIndexOf('\n', end);
      if (cut > i + 200) end = cut;
      out.add(s.substring(i, end));
      i = end;
    }
    return out;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // tiny blue loading dot for busy state
    Widget _busyDot() => SizedBox(
          width: 16,
          height: 16,
          child: _busy
              ? CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                )
              : const SizedBox.shrink(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Q&A'),
        actions: [
          // PDF placed far-left among the actions (closer to title)
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _busy ? null : _exportPdfAndShare,
          ),
          const SizedBox(width: 6),
          // Translate next
          IconButton(
            tooltip: _activeTranslateLang == null
                ? 'Translate (choose language)'
                : 'Change language (${_activeTranslateLang!})',
            icon: const Icon(Icons.translate_rounded),
            onPressed: _busy ? null : _openLanguagePicker,
          ),
          const SizedBox(width: 12),
          // small blue dot while model is busy
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _busyDot(),
          ),
          // extra buffer so the floating orb never covers icons
          const SizedBox(width: 40),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(widget.image, fit: BoxFit.cover),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isYou = m.role == 'user';
                return Align(
                  alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 520),
                    decoration: BoxDecoration(
                      color: isYou ? cs.primaryContainer : cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m.text),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type your question…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _send(vision: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _send(vision: true),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(_busy ? 'Thinking…' : 'Ask'),
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
