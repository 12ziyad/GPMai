import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../services/gpmai_brain.dart';
import 'pdf_notes_sheet.dart';
import 'pdf_viewer_page.dart';

/// Home page for “PDF summary & Ask”
class PdfSummaryHomePage extends StatefulWidget {
  const PdfSummaryHomePage({super.key});

  @override
  State<PdfSummaryHomePage> createState() => _PdfSummaryHomePageState();
}

class _PdfSummaryHomePageState extends State<PdfSummaryHomePage> {
  PlatformFile? _selected;
  bool _busy = false;

  // multi-select for recents
  Set<String> _selectedIds = {};
  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    await SavedPdfRepo.init();
    if (mounted) setState(() {});
  }

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id);
      });
  void _selectAll() => setState(() => _selectedIds = SavedPdfRepo.items.map((e) => e.id).toSet());
  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    await SavedPdfRepo.removeMany(_selectedIds);
    if (mounted) setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF summary & Ask')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _UploadCard(
            selected: _selected,
            busy: _busy,
            onPick: _pickPdf,
            onClear: () => setState(() => _selected = null),
            onSummarize: _busy || _selected == null ? null : _goSummarize,
          ),
          const SizedBox(height: 16),

          Text('Recents', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          if (SavedPdfRepo.items.isEmpty)
            Text('No summaries yet.', style: TextStyle(color: cs.onSurface.withOpacity(.6)))
          else ...[
            Row(
              children: [
                if (_selecting)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'Delete selected',
                    onPressed: _deleteSelected,
                  ),
                if (_selecting) Text('${_selectedIds.length} selected'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selecting ? () => setState(() => _selectedIds.clear()) : _selectAll,
                  icon: Icon(_selecting ? Icons.clear_all_rounded : Icons.checklist_rounded),
                  label: Text(_selecting ? 'Clear' : 'Select All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...SavedPdfRepo.items.map((it) {
              final checked = _selectedIds.contains(it.id);
              return Card(
                child: ListTile(
                  onLongPress: () => _toggleSelect(it.id),
                  onTap: _selecting
                      ? () => _toggleSelect(it.id)
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PdfSummaryDetailPage(item: it)),
                          );
                          if (mounted) setState(() {});
                        },
                  leading: _selecting
                      ? Checkbox(value: checked, onChanged: (_) => _toggleSelect(it.id))
                      : (it.pinned
                          ? const Icon(Icons.push_pin_rounded)
                          : const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent)),
                  title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_fmtTime(DateTime.fromMillisecondsSinceEpoch(it.ts)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Notes',
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        onPressed: () async {
                          final updated = await showModalBottomSheet<String>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => PdfNotesSheet(
                              initial: it.notes ?? '',
                              summaryForQA: it.summary,
                              initialPage: 0,
                            ),
                          );
                          if (updated != null) {
                            it.notes = updated.trim();
                            await SavedPdfRepo.touch(it.id);
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More',
                        offset: const Offset(0, 12),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(it.pinned ? 'Unpin' : 'Pin'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                        onSelected: (v) async {
                          if (v == 'pin') {
                            await SavedPdfRepo.togglePin(it.id);
                            if (mounted) setState(() {});
                          } else if (v == 'delete') {
                            await SavedPdfRepo.removeMany([it.id]);
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null) return;
    setState(() => _selected = result.files.single);
  }

  Future<void> _goSummarize() async {
    if (_selected == null) return;

    setState(() => _busy = true);
    try {
      final f = _selected!;
      final bytes = f.bytes ?? await File(f.path!).readAsBytes();
      final extracted = await _extractPdfText(bytes);
      final trimmed =
          extracted.length > 12000 ? '${extracted.substring(0, 12000)}…' : extracted;

      // concise summary
      const sys = '''
You receive the extracted text of a PDF. Produce:
1) Key points – 5–8 crisp bullets, ≤18 words each.
2) Summary – 1 compact paragraph.
Keep headings exactly "Key points" and "Summary".
[mood: neutral]
''';

      final prompt = 'Document text:\n$trimmed\n\nMake "Key points" then "Summary".';

      final resp = await GPMaiBrain.send(prompt, systemPrompt: sys);
      final item = SavedPdfItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: f.name,
        pdfBytes: bytes,
        extracted: extracted,
        summary: resp.trim(),
        ts: DateTime.now().millisecondsSinceEpoch,
      );
      await SavedPdfRepo.add(item);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfSummaryDetailPage(item: item)),
      );
      if (!mounted) return;
      setState(() {}); // refresh recents
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _extractPdfText(Uint8List bytes) async {
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      final text = sf.PdfTextExtractor(doc).extractText();
      doc.dispose();
      return text.trim();
    } catch (_) {
      return '';
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $h:$m';
  }
}

/* ────────────────── Upload card ────────────────── */

class _UploadCard extends StatelessWidget {
  final PlatformFile? selected;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback? onSummarize;
  final bool busy;

  const _UploadCard({
    required this.selected,
    required this.onPick,
    required this.onClear,
    required this.onSummarize,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload your PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            InkWell(
              onTap: busy ? null : onPick,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.surfaceVariant.withOpacity(.18),
                  border: Border.all(color: cs.onSurface.withOpacity(.15)),
                ),
                child: Center(
                  child: selected == null
                      ? const Text('Tap to choose .pdf')
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                selected!.name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: busy ? null : onClear,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Remove',
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onSummarize,
                icon: busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.summarize_rounded),
                label: const Text('Summarise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ────────────────── Detail page ────────────────── */

class PdfSummaryDetailPage extends StatefulWidget {
  final SavedPdfItem item;
  const PdfSummaryDetailPage({super.key, required this.item});

  @override
  State<PdfSummaryDetailPage> createState() => _PdfSummaryDetailPageState();
}

class _PdfSummaryDetailPageState extends State<PdfSummaryDetailPage> {
  String _language = 'English';
  bool _busy = false;

  // Editable controllers (combined block)
  final _kpCtrl = TextEditingController();
  final _sumCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final parts = _splitKeyPointsAndSummary(widget.item.summary);
    _kpCtrl.text = parts.$1.trim();
    _sumCtrl.text = parts.$2.trim();
  }

  @override
  void dispose() {
    _kpCtrl.dispose();
    _sumCtrl.dispose();
    super.dispose();
  }

  // Robust splitter: handles "Summary", "summary:", "**Summary**", etc.
  (String, String) _splitKeyPointsAndSummary(String s) {
    s = s.replaceAll('\r', '');
    // Find a line that is just "Summary" with optional markdown/punctuation.
    final summaryHeader = RegExp(
      r'^\s*(?:[#*\-\s]{0,3})?\**\s*summary\s*\**\s*:?\s*$',
      caseSensitive: false,
      multiLine: true,
    );
    final m = summaryHeader.firstMatch(s);
    if (m != null) {
      var kp = s.substring(0, m.start);
      var sy = s.substring(m.end);
      // strip "Key points" header if present
      kp = kp.replaceFirst(
        RegExp(
          r'^\s*(?:[#*\-\s]{0,3})?\**\s*key\s*points\s*\**\s*:?\s*\n',
          caseSensitive: false,
          multiLine: true,
        ),
        '',
      );
      // also strip any leftover "Summary" header in sy
      sy = sy.replaceFirst(summaryHeader, '');
      return (kp.trim(), sy.trim());
    }

    // Fallback: try plain contains
    final i = s.toLowerCase().indexOf('\nsummary');
    if (i > 0) {
      final after = i + 1;
      return (s.substring(0, after).trim(), s.substring(after).trim());
    }

    // Last fallback: split by last blank block
    final parts = s.split(RegExp(r'\n{2,}'));
    if (parts.length >= 2) {
      return (parts.sublist(0, parts.length - 1).join('\n\n').trim(), parts.last.trim());
    }
    return (s.trim(), '');
  }

  void _saveEdits() async {
    widget.item.summary =
        'Key points\n${_kpCtrl.text.trim()}\n\nSummary\n${_sumCtrl.text.trim()}';
    await SavedPdfRepo.touch(widget.item.id);
  }

  Future<void> _regenerateInSelectedLanguage() async {
    setState(() => _busy = true);
    try {
      final text = widget.item.extracted;
      final trimmed = text.length > 12000 ? '${text.substring(0, 12000)}…' : text;
      final plan = 'Language: $_language\n\nDocument text:\n$trimmed\n\n'
          'Make "Key points" then "Summary" in the selected language.';
      const sys = '''
You receive the extracted text of a PDF. Produce:
1) Key points – 5–8 crisp bullets, ≤18 words each.
2) Summary – 1 compact paragraph.
Use ONLY the selected language.
[mood: neutral]
''';
      final resp = await GPMaiBrain.send(plan, systemPrompt: sys);
      final parts = _splitKeyPointsAndSummary(resp.trim());
      _kpCtrl.text = parts.$1.trim();
      _sumCtrl.text = parts.$2.trim();
      _saveEdits();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareSummary(
      BuildContext context, String kp, String sy, String fileName) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy_rounded),
              title: const Text('Copy text'),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: const Text('Export to PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final text = 'Key points\n$kp\n\nSummary\n$sy';

    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Copied')));
      return;
    }

    try {
      final doc = sf.PdfDocument();
      final page = doc.pages.add();
      final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);
      final elem = sf.PdfTextElement(text: text, font: font);
      elem.draw(
        page: page,
        bounds: ui.Rect.fromLTWH(
          0, 0, page.getClientSize().width, page.getClientSize().height),
        format: sf.PdfLayoutFormat(layoutType: sf.PdfLayoutType.paginate),
      );
      final bytes = await doc.save();
      doc.dispose();
      final dir = await getTemporaryDirectory();
      final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = '${dir.path}/$safe.summary.pdf';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path)]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _viewPdf() async {
    final it = widget.item;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: it.name,
          filePath: it.path,
          bytes: it.pdfBytes.isNotEmpty ? it.pdfBytes : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(it.name, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // ---- This PDF (VIEW) ----
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(it.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: _viewPdf,
                    icon: const Icon(Icons.remove_red_eye_outlined),
                    label: const Text('VIEW'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ---- Language (auto-regenerate on change with spinner) ----
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                isExpanded: true,
                items: const [
                  // Indian only
                  DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                  DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                  DropdownMenuItem(value: 'Malayalam', child: Text('Malayalam')),
                  // Others
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Arabic', child: Text('Arabic')),
                  DropdownMenuItem(value: 'Bengali', child: Text('Bengali')),
                  DropdownMenuItem(value: 'French', child: Text('French')),
                  DropdownMenuItem(value: 'German', child: Text('German')),
                  DropdownMenuItem(value: 'Spanish', child: Text('Spanish')),
                  DropdownMenuItem(value: 'Portuguese', child: Text('Portuguese')),
                  DropdownMenuItem(value: 'Russian', child: Text('Russian')),
                  DropdownMenuItem(value: 'Turkish', child: Text('Turkish')),
                  DropdownMenuItem(value: 'Japanese', child: Text('Japanese')),
                  DropdownMenuItem(value: 'Korean', child: Text('Korean')),
                  DropdownMenuItem(value: 'Vietnamese', child: Text('Vietnamese')),
                  DropdownMenuItem(value: 'Indonesian', child: Text('Indonesian')),
                  DropdownMenuItem(value: 'Urdu', child: Text('Urdu')),
                ],
                onChanged: (v) {
                  setState(() => _language = v ?? 'English');
                  _regenerateInSelectedLanguage(); // auto
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openPdfToTextSheet(context, it),
            icon: const Icon(Icons.description_rounded),
            label: const Text('PDF → Text'),
          ),
          const SizedBox(height: 12),

          // ---- Combined: Key points & Summary ----
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Key points & Summary',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (_busy)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    IconButton(
                      tooltip: 'Share / Export',
                      icon: const Icon(Icons.ios_share_rounded),
                      onPressed: () =>
                          _shareSummary(context, _kpCtrl.text, _sumCtrl.text, it.name),
                    ),
                    IconButton(
                      tooltip: 'Regenerate in selected language',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: _busy ? null : _regenerateInSelectedLanguage,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.onSurface.withOpacity(.12)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Key points',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _kpCtrl,
                          maxLines: null,
                          decoration: const InputDecoration.collapsed(
                              hintText: '• point\n• point'),
                          style: const TextStyle(height: 1.35),
                          onChanged: (_) => _saveEdits(),
                        ),
                        const SizedBox(height: 12),
                        const Text('Summary',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _sumCtrl,
                          maxLines: null,
                          decoration: const InputDecoration.collapsed(
                              hintText: 'Write a compact paragraph…'),
                          style: const TextStyle(height: 1.35),
                          onChanged: (_) => _saveEdits(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Two fixed FABs in detail page (center bottom)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fabAsk',
            onPressed: () async {
              await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => PdfNotesSheet(
                  initial: it.notes ?? '',
                  summaryForQA: 'Key points\n${_kpCtrl.text}\n\nSummary\n${_sumCtrl.text}',
                  initialPage: 1, // start on Ask page
                ),
              );
            },
            label: const Text('Ask about PDF'),
            icon: const Icon(Icons.question_mark_rounded),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'fabNotes',
            onPressed: () async {
              final updated = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => PdfNotesSheet(
                  initial: it.notes ?? '',
                  summaryForQA: 'Key points\n${_kpCtrl.text}\n\nSummary\n${_sumCtrl.text}',
                  initialPage: 0, // start on Notes
                ),
              );
              if (updated != null) {
                it.notes = updated.trim();
                await SavedPdfRepo.touch(it.id);
                if (mounted) setState(() {});
              }
            },
            label: const Text('Notes'),
            icon: const Icon(Icons.edit_note_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfToTextSheet(BuildContext context, SavedPdfItem it) async {
    String outline = it.outline ?? '';
    if (outline.isEmpty) {
      setState(() => _busy = true);
      try {
        final text = it.extracted;
        final trimmed = text.length > 12000 ? '${text.substring(0, 12000)}…' : text;
        const sys = '''
You are given raw text extracted from a PDF. Produce a neat, organized outline:
- Title (if present)
- Introduction (3–5 lines)
- Sections: each with a heading and 3–6 bullet points
- Conclusion (2–4 lines)
Use clean Markdown (## Heading, - bullets). Remove page numbers/headers/footers.
Do not invent facts.
[mood: neutral]
''';
        final prompt = 'Text:\n$trimmed\n\nMake the outline now.';
        outline = (await GPMaiBrain.send(prompt, systemPrompt: sys)).trim();
        it.outline = outline;
        await SavedPdfRepo.save(); // persist cached outline
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Build outline failed: $e')));
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: .96,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const Text('PDF → Text',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: outline));
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          },
                        ),
                        IconButton(
                          tooltip: 'Share',
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () async {
                            await Share.share(outline);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(outline, style: const TextStyle(height: 1.35)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ────────────────── Persistent in-memory repo ────────────────── */

class SavedPdfItem {
  final String id;
  final String name;
  Uint8List pdfBytes; // may be empty when loaded from disk
  final int ts;
  String extracted;
  String summary; // "Key points\n- ...\n\nSummary\n..."
  String? notes;
  bool pinned;
  String? outline; // cached organized PDF→Text sheet
  String? path;    // file path on disk

  SavedPdfItem({
    required this.id,
    required this.name,
    required this.pdfBytes,
    required this.extracted,
    required this.summary,
    required this.ts,
    this.notes,
    this.pinned = false,
    this.outline,
    this.path,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ts': ts,
        'extracted': extracted,
        'summary': summary,
        'notes': notes,
        'pinned': pinned,
        'outline': outline,
        'path': path,
      };

  static SavedPdfItem fromJson(Map<String, dynamic> m) => SavedPdfItem(
        id: m['id'] as String,
        name: m['name'] as String,
        pdfBytes: Uint8List(0), // loaded lazily from file
        ts: (m['ts'] as num).toInt(),
        extracted: (m['extracted'] as String?) ?? '',
        summary: (m['summary'] as String?) ?? '',
        notes: m['notes'] as String?,
        pinned: (m['pinned'] as bool?) ?? false,
        outline: m['outline'] as String?,
        path: m['path'] as String?,
      );
}

class SavedPdfRepo {
  static final List<SavedPdfItem> items = [];
  static late Directory _root;
  static late Directory _pdfDir;
  static File get _dbFile => File(p.join(_root.path, 'pdf_summaries.json'));

  static Future<void> init() async {
    _root = await getApplicationDocumentsDirectory();
    _pdfDir = Directory(p.join(_root.path, 'pdfs'));
    if (!await _pdfDir.exists()) {
      await _pdfDir.create(recursive: true);
    }
    if (await _dbFile.exists()) {
      try {
        final txt = await _dbFile.readAsString();
        final arr = (jsonDecode(txt) as List).cast<Map<String, dynamic>>();
        items
          ..clear()
          ..addAll(arr.map(SavedPdfItem.fromJson));
        // sort: pinned first, then latest
        items.sort((a, b) {
          final p1 = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
          if (p1 != 0) return p1;
          return b.ts.compareTo(a.ts);
        });
      } catch (_) {
        // ignore corrupt file
      }
    }
  }

  static Future<void> save() async {
    final arr = items.map((e) => e.toJson()).toList();
    await _dbFile.writeAsString(jsonEncode(arr));
  }

  static Future<void> add(SavedPdfItem it) async {
    // write the PDF to disk
    final path = p.join(_pdfDir.path, '${it.id}.pdf');
    await File(path).writeAsBytes(it.pdfBytes, flush: true);
    it.path = path;

    items.insert(0, it);
    await save();
  }

  static Future<void> touch(String id) async {
    final i = items.indexWhere((e) => e.id == id);
    if (i <= 0) {
      await save();
      return;
    }
    final it = items.removeAt(i);
    items.insert(0, it);
    await save();
  }

  static Future<void> removeMany(Iterable<String> ids) async {
    for (final id in ids) {
      final i = items.indexWhere((e) => e.id == id);
      if (i >= 0) {
        final path = items[i].path;
        if (path != null) {
          try { await File(path).delete(); } catch (_) {}
        }
      }
    }
    items.removeWhere((e) => ids.contains(e.id));
    await save();
  }

  static Future<void> togglePin(String id) async {
    final i = items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    items[i].pinned = !items[i].pinned;
    items.sort((a, b) {
      final p1 = (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0);
      if (p1 != 0) return p1;
      return b.ts.compareTo(a.ts);
    });
    await save();
  }
}
