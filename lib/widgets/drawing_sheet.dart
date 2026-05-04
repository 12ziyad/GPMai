import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/painting.dart' show paintImage;
import 'package:path_provider/path_provider.dart';

typedef SaveSketch = void Function(Uint8List pngBytes);
typedef AskSketch = void Function(Uint8List pngBytes, String question);

class DrawingSheet extends StatefulWidget {
  const DrawingSheet({
    super.key,
    required this.chatId,
    required this.onSave,
    this.onAsk,
  });

  final String chatId;
  final SaveSketch onSave;
  final AskSketch? onAsk;

  @override
  State<DrawingSheet> createState() => _DrawingSheetState();
}

/* ====================== model ====================== */

class _Stroke {
  final Path path;
  final Paint paint;
  _Stroke(this.path, this.paint);
}

/* ====================== painter ====================== */

class _SketchPainter extends CustomPainter {
  final ui.Image? bgImage; // only when showing restored page (not while drawing)
  final Color bgColor;
  final List<_Stroke> strokes;
  _SketchPainter(this.bgImage, this.bgColor, this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = bgColor);

    if (bgImage != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: bgImage!,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      );
    }
    for (final s in strokes) {
      canvas.drawPath(s.path, s.paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter oldDelegate) => true;
}

/* ====================== page ====================== */

class _DrawingSheetState extends State<DrawingSheet> {
  final _rbKey = GlobalKey();

  // Per-page data
  final List<List<_Stroke>> _pages = [[]];
  final List<List<_Stroke>> _redos = [[]];
  final List<ui.Image?> _bgImages = [null];

  // Controls whether the restored snapshot is painted (hide after first stroke)
  final List<bool> _showBg = [true];

  int _pageIndex = 0;

  List<_Stroke> get _strokes => _pages[_pageIndex];
  List<_Stroke> get _redo => _redos[_pageIndex];

  static const Color _boardColor = Color(0xFF2B313A);

  bool _eraser = false;
  double _strokeWidth = 5.0;
  Color _penColor = const Color(0xFFFF3B30);
  Path? _currentPath;
  bool _isPanning = false;

  final TextEditingController _titleCtrl = TextEditingController();
  Timer? _titleSaveTimer;

  Directory? _wbDir;

  @override
  void initState() {
    super.initState();
    _initStorage().then((_) async {
      await Future.wait([_loadPagesIfAny(), _loadTitleIfAny()]);
      if (mounted) setState(() {});
    });
    _titleCtrl.addListener(_debouncedSaveTitle);
  }

  @override
  void dispose() {
    unawaited(_saveCurrentPagePng());
    _titleCtrl.dispose();
    _titleSaveTimer?.cancel();
    super.dispose();
  }

  /* ================= Storage ================= */

  Future<void> _initStorage() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/whiteboards/${widget.chatId}');
    if (!(await dir.exists())) {
      await dir.create(recursive: true);
    }
    _wbDir = dir;
  }

  String _pagePngPath(int i0) => '${_wbDir!.path}/page-${i0 + 1}.png';
  String get _titlePath => '${_wbDir?.path}/title.txt';

  Future<void> _loadTitleIfAny() async {
    if (_wbDir == null) return;
    final f = File(_titlePath);
    if (await f.exists()) {
      _titleCtrl.text = await f.readAsString();
    }
  }

  void _debouncedSaveTitle() {
    _titleSaveTimer?.cancel();
    _titleSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (_wbDir == null) return;
      await File(_titlePath).writeAsString(_titleCtrl.text, flush: true);
    });
  }

  Future<void> _loadPagesIfAny() async {
    if (_wbDir == null) return;
    final pages = <ui.Image?>[];
    for (int i = 1;; i++) {
      final f = File('${_wbDir!.path}/page-$i.png');
      if (!await f.exists()) break;
      pages.add(await _decodeImage(await f.readAsBytes()));
    }
    if (pages.isEmpty) {
      setState(() {
        _pages..clear()..add([]);
        _redos..clear()..add([]);
        _bgImages..clear()..add(null);
        _showBg..clear()..add(true);
        _pageIndex = 0;
      });
      return;
    }
    setState(() {
      _pages..clear()..addAll(List.generate(pages.length, (_) => <_Stroke>[]));
      _redos..clear()..addAll(List.generate(pages.length, (_) => <_Stroke>[]));
      _bgImages..clear()..addAll(pages);
      _showBg..clear()..addAll(List<bool>.filled(pages.length, true)); // restored shown initially
      _pageIndex = 0;
    });
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => c.complete(img));
    return c.future;
  }

  /* ================= Drawing ================= */

  Paint _makePaint() => Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = _strokeWidth
    ..blendMode = BlendMode.srcOver
    ..color = _eraser ? _boardColor : _penColor;

  void _onPanStart(DragStartDetails d) {
    final lp = d.localPosition;
    setState(() {
      _isPanning = true;
      _showBg[_pageIndex] = false; // hide snapshot under live strokes
      _currentPath = Path()..moveTo(lp.dx, lp.dy);
      _strokes.add(_Stroke(_currentPath!, _makePaint()));
      _redo.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final lp = d.localPosition;
    setState(() => _currentPath?.lineTo(lp.dx, lp.dy));
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() {
      _currentPath = null;
      _isPanning = false;
    });
    unawaited(_saveCurrentPagePng());
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redo.add(_strokes.removeLast()));
    unawaited(_saveCurrentPagePng());
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    setState(() => _strokes.add(_redo.removeLast()));
    unawaited(_saveCurrentPagePng());
  }

  Future<void> _clear() async {
    setState(() {
      _strokes.clear();
      _redo.clear();
      _bgImages[_pageIndex] = null;
      _showBg[_pageIndex] = false;
    });
    try {
      if (_wbDir != null) {
        final f = File(_pagePngPath(_pageIndex));
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  void _newPage() {
    setState(() {
      _pages.insert(_pageIndex + 1, []);
      _redos.insert(_pageIndex + 1, []);
      _bgImages.insert(_pageIndex + 1, null);
      _showBg.insert(_pageIndex + 1, true);
      _pageIndex++;
    });
    unawaited(_saveCurrentPagePng());
  }

  void _prevPage() {
    if (_pageIndex == 0) return;
    setState(() => _pageIndex--);
  }

  void _nextPage() {
    if (_pageIndex >= _pages.length - 1) return;
    setState(() => _pageIndex++);
  }

  /// Deterministic off-screen render (never cropped) → PNG.
  Future<Uint8List> _renderOffscreenPng() async {
    final Size size = _rbKey.currentContext?.size ?? const Size(900, 1200);
    final double dpr = MediaQuery.of(context).devicePixelRatio;
    final double scale = (dpr * 1.5).clamp(2.5, 3.0) as double;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _boardColor);

    // Always include restored content in the export
    final bg = _bgImages[_pageIndex];
    if (bg != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: bg,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
      );
    }

    for (final s in _strokes) {
      canvas.drawPath(s.path, s.paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (size.width * scale).round(),
      (size.height * scale).round(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _saveCurrentPagePng() async {
    if (_wbDir == null) return;
    try {
      final png = await _renderOffscreenPng();
      final f = File(_pagePngPath(_pageIndex));
      await f.writeAsBytes(png, flush: true);
    } catch (_) {}
  }

  Future<void> _onSavePressed() async {
    final png = await _renderOffscreenPng();
    widget.onSave(png); // ChatPage saves this as a bubble in the chat
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onAskPressed() async {
    final q = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final c = TextEditingController();
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ask about this sketch',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: c,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Your question…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        icon: const Icon(Icons.arrow_upward_rounded),
                        label: const Text('Send to chat'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (q == null || q.isEmpty) return;

    final png = await _renderOffscreenPng();
    if (widget.onAsk != null) widget.onAsk!(png, q);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onManualSave() async {
    await _saveCurrentPagePng();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Sketch saved')));
  }

  /* ================= UI helpers ================= */

  void _openColorPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<Color>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final swatches = <Color>[
          const Color(0xFF00B8FF),
          const Color(0xFFFF3B30),
          const Color(0xFF50E3C2),
          const Color(0xFFFFD166),
          Colors.white,
          const Color(0xFFB084F0),
          const Color(0xFF7ED957),
          const Color(0xFFFF7AA2),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final c in swatches)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _penColor = c;
                        _eraser = false;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white24,
                          width: (_penColor == c && !_eraser) ? 4 : 1,
                        ),
                      ),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: const Text('Eraser'),
                  onPressed: () {
                    setState(() => _eraser = true);
                    Navigator.pop(context);
                  },
                  backgroundColor: cs.primary.withOpacity(.12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tool({
    required IconData icon,
    required String tip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? cs.primary.withOpacity(.18) : Colors.black.withOpacity(.10),
            border: Border.all(color: active ? cs.primary : Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: active ? cs.primary : Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _thicknessDot(double w, bool selected) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Pen size ${w.toInt()}',
      child: InkWell(
        onTap: () => setState(() => _strokeWidth = w),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cs.primary.withOpacity(.14) : Colors.black.withOpacity(.10),
            border: Border.all(color: selected ? cs.primary : Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            width: w + 6,
            height: w + 6,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Writing Facilities'),
        leading: IconButton(
          tooltip: 'Back to chat',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          Tooltip(
            message: 'Save',
            child: IconButton(onPressed: _onManualSave, icon: const Icon(Icons.save_alt_rounded)),
          ),
          Tooltip(
            message: 'Clear current page',
            child: IconButton(onPressed: _clear, icon: const Icon(Icons.delete_sweep_rounded)),
          ),
          TextButton(onPressed: _onSavePressed, child: const Text('Done')),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'askSketch',
        onPressed: _onAskPressed,
        backgroundColor: cs.primary,
        foregroundColor: Colors.black,
        elevation: 1,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Ask'),
      ),

      body: Column(
        children: [
          // Title + Color
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _titleCtrl,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Heading',
                      hintText: 'Write a title for this page (optional)',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Choose color',
                  child: ElevatedButton.icon(
                    onPressed: _openColorPicker,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      backgroundColor: Colors.black.withOpacity(.10),
                      foregroundColor: cs.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: cs.primary.withOpacity(.38)),
                      ),
                    ),
                    icon: const Icon(Icons.color_lens_rounded),
                    label: const Text('Color'),
                  ),
                ),
              ],
            ),
          ),

          // Tool row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _tool(
                    icon: Icons.edit_rounded,
                    tip: 'Pencil',
                    active: !_eraser,
                    onTap: () => setState(() => _eraser = false),
                  ),
                  const SizedBox(width: 8),
                  _tool(
                    icon: Icons.auto_fix_high_rounded,
                    tip: 'Eraser',
                    active: _eraser,
                    onTap: () => setState(() => _eraser = true),
                  ),
                  const SizedBox(width: 8),
                  _tool(icon: Icons.undo_rounded, tip: 'Undo', onTap: _undo),
                  const SizedBox(width: 8),
                  _tool(icon: Icons.redo_rounded, tip: 'Redo', onTap: _redoAction),
                  const SizedBox(width: 12),
                  _thicknessDot(3, _strokeWidth <= 3),
                  const SizedBox(width: 8),
                  _thicknessDot(6, _strokeWidth > 3 && _strokeWidth <= 6),
                  const SizedBox(width: 8),
                  _thicknessDot(9, _strokeWidth > 6),
                ],
              ),
            ),
          ),

          // Page row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            child: Row(
              children: [
                Tooltip(
                  message: 'Previous page',
                  child: IconButton(
                    onPressed: _pageIndex == 0 ? null : _prevPage,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                ),
                Text('Page ${_pageIndex + 1}/${_pages.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Tooltip(
                  message: 'Next page',
                  child: IconButton(
                    onPressed: _pageIndex >= _pages.length - 1 ? null : _nextPage,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'New page',
                  child: ElevatedButton.icon(
                    onPressed: _newPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
                ),
              ],
            ),
          ),

          // Board
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _boardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: RepaintBoundary(
                      key: _rbKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          // Only show bg while user hasn’t drawn yet on this page
                          painter: _SketchPainter(
                            _showBg[_pageIndex] ? _bgImages[_pageIndex] : null,
                            _boardColor,
                            _strokes,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
