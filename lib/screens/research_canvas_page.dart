import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../services/gpmai_brain.dart';
import '../services/provider_branding.dart';
import '../services/research_canvas_store.dart';
import '../widgets/markdown_bubble.dart';
import '../widgets/citation_builder_panel.dart';
import '../widgets/auto_prompt_chips.dart';
import 'chat_page.dart';

class ResearchCanvasPage extends StatefulWidget {
  const ResearchCanvasPage({super.key});

  @override
  State<ResearchCanvasPage> createState() => _ResearchCanvasPageState();
}

class _ResearchCanvasPageState extends State<ResearchCanvasPage> {
  final ResearchCanvasStore _store = ResearchCanvasStore();
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loading = true;
  List<ResearchCanvas> _canvases = const <ResearchCanvas>[];
  String? _tagFilter;
  bool _mapView = false;
  final Set<String> _selectedCanvasIds = <String>{};

  String _cleanCanvasTitle(String? raw) {
    final source = (raw ?? '').trim();
    if (source.isEmpty) return '';
    if (source.contains('<<META>>') && source.contains('<<ENDMETA>>')) {
      final start = source.indexOf('<<META>>');
      final end = source.indexOf('<<ENDMETA>>');
      final before = source.substring(0, start).trim();
      final after = source.substring(end + '<<ENDMETA>>'.length).trim();
      final merged = [before, after].where((e) => e.isNotEmpty).join(' ');
      if (merged.isNotEmpty) return merged.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    if (source.startsWith('<<META>>')) {
      final close = source.indexOf('}');
      if (close != -1 && close + 1 < source.length) {
        return source.substring(close + 1).replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return source.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool get _selectionMode => _selectedCanvasIds.isNotEmpty;
  String get _searchQuery => ResearchCanvasStore.sanitizeTitleText(_searchCtrl.text).toLowerCase();
  bool get _selectedAllStarred {
    final selected = _canvases.where((canvas) => _selectedCanvasIds.contains(canvas.id)).toList(growable: false);
    return selected.isNotEmpty && selected.every((canvas) => canvas.pinned);
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_handleSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_handleSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final all = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _canvases = all;
      _loading = false;
      _selectedCanvasIds.retainAll(all.map((canvas) => canvas.id));
    });
  }

  void _toggleMapView() {
    if (!mounted) return;
    setState(() => _mapView = !_mapView);
  }

  void _toggleCanvasSelection(String canvasId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        _selectedCanvasIds.add(canvasId);
      } else if (_selectedCanvasIds.contains(canvasId)) {
        _selectedCanvasIds.remove(canvasId);
      } else {
        _selectedCanvasIds.add(canvasId);
      }
    });
  }

  void _clearCanvasSelection() {
    if (!mounted) return;
    setState(() => _selectedCanvasIds.clear());
  }

  void _selectAllVisible() {
    if (!mounted) return;
    setState(() {
      _selectedCanvasIds
        ..clear()
        ..addAll(_visibleCanvases.map((canvas) => canvas.id));
    });
  }

  Future<bool> _confirmDeleteCanvases(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11151D),
        title: Text(count == 1 ? 'Delete canvas?' : 'Delete $count canvases?'),
        content: Text(
          count == 1
              ? 'This canvas and all its saved blocks will be removed.'
              : 'These canvases and all their saved blocks will be removed.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteCanvas(ResearchCanvas canvas) async {
    final ok = await _confirmDeleteCanvases(1);
    if (!ok) return;
    await _store.deleteCanvas(canvas.id);
    await _load();
  }

  Future<void> _deleteSelectedCanvases() async {
    if (_selectedCanvasIds.isEmpty) return;
    final ok = await _confirmDeleteCanvases(_selectedCanvasIds.length);
    if (!ok) return;
    final ids = _selectedCanvasIds.toList(growable: false);
    for (final id in ids) {
      await _store.deleteCanvas(id);
    }
    if (mounted) {
      setState(() => _selectedCanvasIds.clear());
    }
    await _load();
  }

  Future<void> _toggleStar(ResearchCanvas canvas) async {
    await _store.togglePinned(canvas.id);
    await _load();
  }

  Future<void> _toggleStarForSelected() async {
    if (_selectedCanvasIds.isEmpty) return;
    final selected = _canvases.where((canvas) => _selectedCanvasIds.contains(canvas.id)).toList(growable: false);
    if (selected.isEmpty) return;
    final shouldStar = selected.any((canvas) => !canvas.pinned);
    for (final canvas in selected) {
      if (canvas.pinned != shouldStar) {
        await _store.togglePinned(canvas.id);
      }
    }
    if (mounted) {
      setState(() => _selectedCanvasIds.clear());
    }
    await _load();
  }

  Future<void> _createCanvas() async {
    final titleCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    String themeKey = 'aurora';
    bool saving = false;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => LayoutBuilder(
            builder: (ctx, constraints) => Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.9),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF111B2B), Color(0xFF181227), Color(0xFF090B11)],
                    ),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('New Research Canvas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 8),
                          const Text('Create a premium workspace for notes, saved answers, and AI-built sections.', style: TextStyle(color: Colors.white70, height: 1.4)),
                          const SizedBox(height: 14),
                          _CanvasField(controller: titleCtrl, label: 'Title', hint: 'GPMai launch strategy'),
                          const SizedBox(height: 12),
                          _CanvasField(controller: tagsCtrl, label: 'Hashtags', hint: '#startup #launch #pricing'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              MapEntry('aurora', 'Aurora'),
                              MapEntry('rose', 'Rose'),
                              MapEntry('mint', 'Mint'),
                              MapEntry('ember', 'Ember'),
                            ].map((entry) {
                              final selected = themeKey == entry.key;
                              return _CanvasChip(
                                label: entry.value,
                                selected: selected,
                                onTap: () => setModal(() => themeKey = entry.key),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(colors: [Color(0xFF12C6FF), Color(0xFF8D63FF), Color(0xFFFF5B93)]),
                              ),
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.maybeOf(context);
                                        final title = _cleanCanvasTitle(titleCtrl.text);
                                        if (title.isEmpty) {
                                          messenger?.showSnackBar(const SnackBar(content: Text('Enter a canvas title.')));
                                          return;
                                        }
                                        setModal(() => saving = true);
                                        try {
                                          await _store.createCanvas(
                                            title: title,
                                            tags: ResearchCanvasStore.parseTags(tagsCtrl.text),
                                            themeKey: themeKey,
                                          );
                                          if (ctx.mounted) Navigator.pop(ctx, true);
                                        } catch (e) {
                                          messenger?.showSnackBar(SnackBar(content: Text('Could not create canvas: $e')));
                                        } finally {
                                          if (ctx.mounted) setModal(() => saving = false);
                                        }
                                      },
                                icon: saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.auto_awesome_mosaic_rounded),
                                label: Text(saving ? 'Creating...' : 'Create Canvas'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (created == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Canvas created ✨')));
      }
    }
  }

  Future<void> _openCanvas(ResearchCanvas canvas) async {
    if (_selectionMode) {
      _toggleCanvasSelection(canvas.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResearchCanvasDetailPage(canvasId: canvas.id)),
    );
    await _load();
  }

  Future<void> _openStarred() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _StarredCanvasesPage()),
    );
    await _load();
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final canvas in _canvases) {
      tags.addAll(canvas.tags);
      for (final block in canvas.blocks) {
        tags.addAll(block.tags);
      }
    }
    final list = tags.toList(growable: false)..sort();
    return list;
  }

  List<ResearchCanvas> get _visibleCanvases {
    Iterable<ResearchCanvas> list = _canvases;
    if (_tagFilter != null) {
      list = list.where((canvas) {
        final tags = <String>{...canvas.tags, ...canvas.blocks.expand((block) => block.tags)};
        return tags.contains(_tagFilter);
      });
    }
    final query = _searchQuery;
    if (query.isNotEmpty) {
      list = list.where((canvas) {
        final haystack = [
          canvas.title,
          canvas.description,
          canvas.tags.join(' '),
          ...canvas.blocks.map((block) => block.title),
          ...canvas.blocks.map((block) => block.content),
          ...canvas.blocks.expand((block) => block.tags),
        ].map(ResearchCanvasStore.sanitizeBodyText).join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }
    return list.toList(growable: false);
  }

  List<ResearchCanvas> get _starredCanvases => _canvases.where((canvas) => canvas.pinned).toList(growable: false);

  Widget _buildSearchField() {
    return TextField(
      controller: _searchCtrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search canvases or #hashtags',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchCtrl.text.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchCtrl.clear();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: const Color(0xFF0F131A),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Colors.white12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: Color(0xFF12C6FF))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedCanvasIds.length} selected' : 'Research Canvas'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _clearCanvasSelection,
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  onPressed: _selectedCanvasIds.isEmpty ? null : _toggleStarForSelected,
                  icon: Icon(_selectedAllStarred ? Icons.star_outline_rounded : Icons.star_rounded),
                  tooltip: _selectedAllStarred ? 'Unstar selected' : 'Star selected',
                ),
                IconButton(
                  onPressed: _visibleCanvases.isEmpty ? null : _selectAllVisible,
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select all',
                ),
                IconButton(
                  onPressed: _clearCanvasSelection,
                  icon: const Icon(Icons.clear_all_rounded),
                  tooltip: 'Clear',
                ),
                IconButton(
                  onPressed: _deleteSelectedCanvases,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete selected',
                ),
              ]
            : [
                IconButton(onPressed: _toggleMapView, icon: Icon(_mapView ? Icons.view_agenda_rounded : Icons.hub_rounded), tooltip: _mapView ? 'List view' : 'Map view'),
                IconButton(onPressed: _createCanvas, icon: const Icon(Icons.add_rounded), tooltip: 'New canvas'),
              ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'research_canvas_starred_fab',
                  onPressed: _openStarred,
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('Starred'),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'research_canvas_new_fab',
                  onPressed: _createCanvas,
                  icon: const Icon(Icons.auto_awesome_mosaic_rounded),
                  label: const Text('New Canvas'),
                ),
              ],
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _mapView
                        ? _CanvasHomeMapView(
                            canvases: _visibleCanvases,
                            onNodeTap: (canvas) => _openCanvas(canvas),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
                              children: [
                                const _CanvasHero(),
                                const SizedBox(height: 16),
                                _buildSearchField(),
                                const SizedBox(height: 16),
                                if (_allTags.isNotEmpty) ...[
                                  SizedBox(
                                    height: 42,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        _CanvasChip(label: 'All', selected: _tagFilter == null, onTap: () => setState(() => _tagFilter = null)),
                                        const SizedBox(width: 8),
                                        ..._allTags.map((tag) => Padding(
                                              padding: const EdgeInsets.only(right: 8),
                                              child: _CanvasChip(label: tag, selected: _tagFilter == tag, onTap: () => setState(() => _tagFilter = tag)),
                                            )),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                ],
                                if (_visibleCanvases.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      color: const Color(0xFF0F131A),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Text(
                                      _searchQuery.isNotEmpty || _tagFilter != null
                                          ? 'No canvases matched your current search or hashtag filter.'
                                          : 'No canvases yet. Create one, save an answer from chat, or start building your own AI workspace here.',
                                      style: const TextStyle(color: Colors.white70, height: 1.4),
                                    ),
                                  )
                                else
                                  ..._visibleCanvases.map((canvas) => Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: _CanvasHomeCard(
                                          canvas: canvas,
                                          selected: _selectedCanvasIds.contains(canvas.id),
                                          onTap: () => _openCanvas(canvas),
                                          onLongPress: () => _toggleCanvasSelection(canvas.id, forceSelect: true),
                                          onStar: () => _toggleStar(canvas),
                                          onDelete: () => _deleteCanvas(canvas),
                                        ),
                                      )),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StarredCanvasesPage extends StatefulWidget {
  const _StarredCanvasesPage();

  @override
  State<_StarredCanvasesPage> createState() => _StarredCanvasesPageState();
}

class _StarredCanvasesPageState extends State<_StarredCanvasesPage> {
  final ResearchCanvasStore _store = ResearchCanvasStore();
  bool _loading = true;
  List<ResearchCanvas> _starredCanvases = const <ResearchCanvas>[];
  final Set<String> _selectedCanvasIds = <String>{};

  bool get _selectionMode => _selectedCanvasIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _store.loadAll();
    if (!mounted) return;
    final starred = all.where((canvas) => canvas.pinned).toList(growable: false);
    setState(() {
      _starredCanvases = starred;
      _loading = false;
      _selectedCanvasIds.retainAll(starred.map((canvas) => canvas.id));
    });
  }

  void _toggleSelection(String canvasId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        _selectedCanvasIds.add(canvasId);
      } else if (_selectedCanvasIds.contains(canvasId)) {
        _selectedCanvasIds.remove(canvasId);
      } else {
        _selectedCanvasIds.add(canvasId);
      }
    });
  }

  void _clearSelection() {
    if (!mounted) return;
    setState(() => _selectedCanvasIds.clear());
  }

  void _selectAll() {
    if (!mounted) return;
    setState(() {
      _selectedCanvasIds
        ..clear()
        ..addAll(_starredCanvases.map((canvas) => canvas.id));
    });
  }

  Future<bool> _confirmDeleteCanvas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11151D),
        title: const Text('Delete canvas?'),
        content: const Text('This canvas and all its saved blocks will be removed.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteCanvas(ResearchCanvas canvas) async {
    final ok = await _confirmDeleteCanvas();
    if (!ok) return;
    await _store.deleteCanvas(canvas.id);
    await _load();
  }

  Future<void> _toggleStar(ResearchCanvas canvas) async {
    await _store.togglePinned(canvas.id);
    await _load();
  }

  Future<void> _removeStarredSelected() async {
    if (_selectedCanvasIds.isEmpty) return;
    final selected = _starredCanvases.where((canvas) => _selectedCanvasIds.contains(canvas.id)).toList(growable: false);
    for (final canvas in selected) {
      if (canvas.pinned) {
        await _store.togglePinned(canvas.id);
      }
    }
    if (mounted) {
      setState(() => _selectedCanvasIds.clear());
    }
    await _load();
  }

  Future<void> _openCanvas(ResearchCanvas canvas) async {
    if (_selectionMode) {
      _toggleSelection(canvas.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResearchCanvasDetailPage(canvasId: canvas.id)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedCanvasIds.length} selected' : 'Starred'),
        leading: _selectionMode ? IconButton(onPressed: _clearSelection, icon: const Icon(Icons.close_rounded)) : null,
        actions: _selectionMode
            ? [
                IconButton(onPressed: _starredCanvases.isEmpty ? null : _selectAll, icon: const Icon(Icons.select_all_rounded), tooltip: 'Select all'),
                IconButton(onPressed: _clearSelection, icon: const Icon(Icons.clear_all_rounded), tooltip: 'Clear'),
                IconButton(onPressed: _removeStarredSelected, icon: const Icon(Icons.star_outline_rounded), tooltip: 'Remove starred'),
              ]
            : null,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _starredCanvases.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: const Color(0xFF0F131A),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'No starred canvases yet. Star a canvas from home and it will appear here.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: const Color(0xFF0F131A),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'Select starred canvases to unstar them together, or open any canvas normally.',
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._starredCanvases.map((canvas) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _CanvasHomeCard(
                              canvas: canvas,
                              selected: _selectedCanvasIds.contains(canvas.id),
                              onTap: () => _openCanvas(canvas),
                              onLongPress: () => _toggleSelection(canvas.id, forceSelect: true),
                              onStar: () => _toggleStar(canvas),
                              onDelete: () => _deleteCanvas(canvas),
                            ),
                          )),
                    ],
                  ),
      ),
    );
  }
}

class ResearchCanvasDetailPage extends StatefulWidget {
  final String canvasId;
  const ResearchCanvasDetailPage({super.key, required this.canvasId});

  @override
  State<ResearchCanvasDetailPage> createState() => _ResearchCanvasDetailPageState();
}

class _ResearchCanvasDetailPageState extends State<ResearchCanvasDetailPage> {
  final ResearchCanvasStore _store = ResearchCanvasStore();
  final ScrollController _scrollController = ScrollController();
  ResearchCanvas? _canvas;
  bool _loading = true;
  bool _mapView = false;
  bool _working = false;
  final Map<String, GlobalKey> _blockKeys = <String, GlobalKey>{};
  final Set<String> _selectedBlockIds = <String>{};
  final TransformationController _mapController = TransformationController();
  final Map<String, Offset> _nodePositions = <String, Offset>{};
  bool _mapStateLoaded = false;
  bool _mapCenterApplied = false;
  String? _highlightedBlockId;

  bool get _selectionMode => _selectedBlockIds.isNotEmpty;

  String _cleanCanvasBody(String? raw) => ResearchCanvasStore.sanitizeBodyText(raw);

  void _toggleBlockSelection(String blockId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        _selectedBlockIds.add(blockId);
      } else if (_selectedBlockIds.contains(blockId)) {
        _selectedBlockIds.remove(blockId);
      } else {
        _selectedBlockIds.add(blockId);
      }
    });
  }

  void _clearBlockSelection() => setState(() => _selectedBlockIds.clear());

  @override
  void dispose() {
    _scrollController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final canvas = await _store.getById(widget.canvasId);
    if (!mounted) return;
    setState(() {
      _canvas = canvas;
      _loading = false;
      _selectedBlockIds.retainAll((canvas?.blocks ?? const <ResearchCanvasBlock>[]).map((block) => block.id));
      for (final block in canvas?.blocks ?? const <ResearchCanvasBlock>[]) {
        _blockKeys.putIfAbsent(block.id, () => GlobalKey());
      }
    });
    await _ensureMapStateLoaded();
  }

  String get _mapTransformKey => 'research_canvas_map_transform_${widget.canvasId}';
  String get _mapNodeKey => 'research_canvas_map_nodes_${widget.canvasId}';

  Future<void> _ensureMapStateLoaded() async {
    if (_mapStateLoaded) return;
    final canvas = _canvas;
    if (canvas == null) return;
    final prefs = await SharedPreferences.getInstance();
    final rawNodes = prefs.getString(_mapNodeKey);
    final loadedNodes = <String, Offset>{};
    if (rawNodes != null && rawNodes.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNodes) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is Map) {
            final dx = (value['dx'] as num?)?.toDouble();
            final dy = (value['dy'] as num?)?.toDouble();
            if (dx != null && dy != null) loadedNodes[entry.key] = Offset(dx, dy);
          }
        }
      } catch (_) {}
    }
    final rawTransform = prefs.getStringList(_mapTransformKey);
    final nextPositions = _buildDefaultNodePositions(canvas, loaded: loadedNodes);
    if (mounted) {
      setState(() {
        _nodePositions
          ..clear()
          ..addAll(nextPositions);
        _mapStateLoaded = true;
      });
    }
    if (rawTransform != null && rawTransform.length == 16) {
      final parsed = rawTransform.map((e) => double.tryParse(e) ?? 0).toList(growable: false);
      _mapController.value = Matrix4.fromList(parsed);
      _mapCenterApplied = true;
    }
  }

  Map<String, Offset> _buildDefaultNodePositions(ResearchCanvas canvas, {Map<String, Offset> loaded = const <String, Offset>{}}) {
    const boardCenter = Offset(800, 560);
    final next = <String, Offset>{};
    final blocks = canvas.blocks.take(36).toList(growable: false);
    const ringCapacity = 6;
    const baseRadius = 240.0;
    const ringGap = 170.0;
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (loaded.containsKey(block.id)) {
        next[block.id] = loaded[block.id]!;
        continue;
      }
      final ring = index ~/ ringCapacity;
      final slot = index % ringCapacity;
      final itemsInRing = math.min(ringCapacity, blocks.length - ring * ringCapacity);
      final angle = -math.pi / 2 + ((math.pi * 2 * slot) / math.max(1, itemsInRing));
      final radius = baseRadius + (ring * ringGap);
      next[block.id] = Offset(
        boardCenter.dx + math.cos(angle) * radius,
        boardCenter.dy + math.sin(angle) * radius,
      );
    }
    return next;
  }

  Future<void> _persistMapState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_mapTransformKey, _mapController.value.storage.map((e) => e.toString()).toList(growable: false));
    await prefs.setString(
      _mapNodeKey,
      jsonEncode(_nodePositions.map((key, value) => MapEntry(key, <String, double>{'dx': value.dx, 'dy': value.dy}))),
    );
  }

  void _applyMapCenter(Size viewport) {
    if (_mapCenterApplied || viewport.width <= 0 || viewport.height <= 0) return;
    const boardCenter = Offset(800, 560);
    final dx = viewport.width / 2 - boardCenter.dx;
    final dy = viewport.height / 2 - boardCenter.dy;
    _mapController.value = Matrix4.identity()..translate(dx, dy);
    _mapCenterApplied = true;
  }

  Future<void> _toggleMapView() async {
    final next = !_mapView;
    if (!next) {
      await _persistMapState();
      if (!mounted) return;
      setState(() => _mapView = false);
      return;
    }
    await _ensureMapStateLoaded();
    if (!mounted) return;
    setState(() => _mapView = true);
  }

  void _updateNodePosition(String blockId, Offset next) {
    setState(() => _nodePositions[blockId] = next);
  }

  void _replaceNodePositions(Map<String, Offset> next) {
    setState(() {
      _nodePositions
        ..clear()
        ..addAll(next);
    });
  }

  void _highlightBlock(String blockId) {
    if (!mounted) return;
    setState(() => _highlightedBlockId = blockId);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _highlightedBlockId == blockId) {
        setState(() => _highlightedBlockId = null);
      }
    });
  }

  Future<void> _addManualNote() async {
    if (_canvas == null) return;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F131A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New note', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 18),
                  _CanvasField(controller: titleCtrl, label: 'Title', hint: 'Quick note'),
                  const SizedBox(height: 12),
                  _CanvasField(controller: bodyCtrl, label: 'Body', hint: 'Write your note...', maxLines: 5),
                  const SizedBox(height: 12),
                  _CanvasField(controller: tagsCtrl, label: 'Hashtags', hint: '#idea #priority'),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _store.addBlock(
      _canvas!.id,
      ResearchCanvasBlock(
        id: 'block_${DateTime.now().microsecondsSinceEpoch}',
        type: 'note',
        title: titleCtrl.text.trim().isEmpty ? 'Quick note' : titleCtrl.text.trim(),
        content: bodyCtrl.text.trim(),
        sourceLabel: 'Manual note',
        modelLabel: 'You',
        createdAt: DateTime.now(),
        tags: ResearchCanvasStore.parseTags(tagsCtrl.text),
      ),
    );
    await _load();
  }

  Future<void> _askAiToAddSection() async {
    if (_canvas == null || _working) return;
    final ctrl = TextEditingController();
    final request = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F131A),
        title: const Text('Ask AI to add a section', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CanvasField(controller: ctrl, label: 'Instruction', hint: 'Add a competitor analysis and keep it practical.', maxLines: 5),
              const SizedBox(height: 12),
              AutoPromptChips(
                controller: ctrl,
                screenContext: 'canvas',
                onSend: (transformedText, chipType, chipLabel) async {
                  if (ctx.mounted) Navigator.pop(ctx, transformedText.trim());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Generate')),
        ],
      ),
    );
    if (request == null || request.trim().isEmpty) return;
    setState(() => _working = true);
    try {
      final contextText = _canvas!.blocks.take(6).map((b) {
        final q = (b.question ?? '').trim();
        return '- ${b.title}\n${q.isEmpty ? '' : 'Question: $q\n'}${b.content}';
      }).join('\n\n');
      final result = await GPMaiBrain.sendRich(
        prompt: 'Canvas title: ${_canvas!.title}\nExisting context:\n$contextText\n\nUser request: $request',
        systemPrompt: '''You are helping inside a premium research canvas.
Write one concise but useful new section directly for the canvas.
Keep it clean, readable, and helpful.
Do not mention that you are an AI.
Return only the section content.
''',
        maxOutputTokens: 700,
        temperature: .55,
        sourceTag: 'research_canvas',
      );
      await _store.addBlock(
        _canvas!.id,
        ResearchCanvasBlock(
          id: 'block_${DateTime.now().microsecondsSinceEpoch}',
          type: 'ai_section',
          title: request.length > 48 ? '${request.substring(0, 48)}â€¦' : request,
          question: request,
          content: result.text.trim(),
          sourceLabel: 'AI section',
          modelLabel: result.usedUiModel.isEmpty ? 'AI' : result.usedUiModel,
          createdAt: DateTime.now(),
          tags: _canvas!.tags,
        ),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New AI section added âœ¨')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _renameCanvas() async {
    if (_canvas == null) return;
    final ctrl = TextEditingController(text: _canvas!.title);
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F131A),
        title: const Text('Rename canvas', style: TextStyle(color: Colors.white)),
        content: _CanvasField(controller: ctrl, label: 'Title', hint: 'Canvas title'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (next == null || next.trim().isEmpty) return;
    await _store.renameCanvas(_canvas!.id, next.trim());
    await _load();
  }

  Future<void> _exportMarkdown() async {
    if (_canvas == null) return;
    final buffer = StringBuffer('# ${_canvas!.title}\n\n');
    if (_canvas!.tags.isNotEmpty) buffer.writeln(_canvas!.tags.join(' ') + '\n');
    for (final block in _canvas!.blocks) {
      buffer.writeln('## ${block.title}');
      if ((block.question ?? '').trim().isNotEmpty) {
        buffer.writeln('**Question:** ${block.question!}\n');
      }
      buffer.writeln(block.content);
      buffer.writeln('\n_Source: ${block.sourceLabel} â€¢ ${block.modelLabel} â€¢ ${_fmtDate(block.createdAt)}_\n');
      if (block.tags.isNotEmpty) buffer.writeln('${block.tags.join(' ')}\n');
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_canvas!.title.replaceAll(' ', '_').toLowerCase()}_canvas.md');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], text: _canvas!.title);
  }

  Future<void> _exportPdf() async {
    if (_canvas == null) return;
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(_canvas!.title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (_canvas!.tags.isNotEmpty) pw.Text(_canvas!.tags.join(' ')),
          pw.SizedBox(height: 16),
          ..._canvas!.blocks.map((block) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(block.title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  if ((block.question ?? '').trim().isNotEmpty) pw.Text('Question: ${block.question!}'),
                  pw.SizedBox(height: 6),
                  pw.Text(block.content),
                  pw.SizedBox(height: 6),
                  pw.Text('${block.sourceLabel} â€¢ ${block.modelLabel} â€¢ ${_fmtDate(block.createdAt)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(height: 14),
                ],
              )),
        ],
      ),
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_canvas!.title.replaceAll(' ', '_').toLowerCase()}_canvas.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: _canvas!.title);
  }

  Future<bool> _confirmDeleteBlocks(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF11151D),
        title: Text(count == 1 ? 'Delete block?' : 'Delete $count blocks?'),
        content: Text(
          count == 1
              ? 'This block will be removed from the canvas.'
              : 'These blocks will be removed from the canvas.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteBlock(ResearchCanvasBlock block) async {
    if (_canvas == null) return;
    final ok = await _confirmDeleteBlocks(1);
    if (!ok) return;
    await _store.deleteBlock(_canvas!.id, block.id);
    await _load();
  }

  Future<void> _deleteSelectedBlocks() async {
    if (_canvas == null || _selectedBlockIds.isEmpty) return;
    final ok = await _confirmDeleteBlocks(_selectedBlockIds.length);
    if (!ok) return;
    final ids = _selectedBlockIds.toList(growable: false);
    for (final id in ids) {
      await _store.deleteBlock(_canvas!.id, id);
    }
    if (mounted) _clearBlockSelection();
    await _load();
  }

  Future<void> _editNoteBlock(ResearchCanvasBlock block) async {
    if (_canvas == null) return;
    final titleCtrl = TextEditingController(text: block.title);
    final bodyCtrl = TextEditingController(text: block.content);
    final tagsCtrl = TextEditingController(text: block.tags.join(' '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F131A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit block', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 18),
                  _CanvasField(controller: titleCtrl, label: 'Title', hint: 'Block title'),
                  const SizedBox(height: 12),
                  _CanvasField(controller: bodyCtrl, label: 'Content', hint: 'Write content', maxLines: 5),
                  const SizedBox(height: 12),
                  _CanvasField(controller: tagsCtrl, label: 'Hashtags', hint: '#idea #note'),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _store.updateBlock(
      _canvas!.id,
      block.copyWith(
        title: titleCtrl.text.trim().isEmpty ? block.title : titleCtrl.text.trim(),
        content: bodyCtrl.text.trim(),
        tags: ResearchCanvasStore.parseTags(tagsCtrl.text),
      ),
    );
    await _load();
  }


  bool _canNavigateToSource(ResearchCanvasBlock block) {
    final extra = block.extra;
    if (block.type == 'image' || block.type == 'video' || block.type == 'audio') {
      return (block.mediaUrl ?? block.thumbnailUrl)?.trim().isNotEmpty == true;
    }
    return extra['chatId'] != null || extra['threadId'] != null || extra['sourceRoute'] != null || extra['sourcePath'] != null || extra['sourceUrl'] != null;
  }

  Future<void> _openBlockSource(ResearchCanvasBlock block) async {
    final extra = block.extra;
    final chatId = extra['chatId']?.toString();
    final chatName = extra['chatName']?.toString();
    final userId = extra['userId']?.toString();
    final uri = extra['sourceUrl']?.toString();
    if (chatId != null && chatName != null && userId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatPage(userId: userId, chatId: chatId, chatName: chatName),
        ),
      );
      return;
    }
    if (uri != null && uri.trim().isNotEmpty) {
      await launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
      return;
    }
    if ((block.mediaUrl ?? block.thumbnailUrl)?.trim().isNotEmpty == true && mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: _CanvasMediaPreview(block: block, accent: _CanvasThemeData.fromKey(_canvas?.themeKey ?? 'aurora').accent, expanded: true),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source chat is unavailable for this block.')));
  }

  Future<void> _jumpToBlock(String blockId) async {
    _blockKeys.putIfAbsent(blockId, () => GlobalKey());
    if (_mapView && mounted) {
      await _persistMapState();
      setState(() => _mapView = false);
    }
    for (var i = 0; i < 14; i++) {
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _blockKeys[blockId]?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: .08,
        );
        _highlightBlock(blockId);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 36));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090B11),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final canvas = _canvas;
    if (canvas == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF090B11),
        body: Center(child: Text('Canvas not found', style: TextStyle(color: Colors.white70))),
      );
    }
    final theme = _CanvasThemeData.fromKey(canvas.themeKey);
    return Scaffold(
      backgroundColor: const Color(0xFF090B11),
      appBar: AppBar(
        title: Text(_selectionMode ? '${_selectedBlockIds.length} selected' : canvas.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: _selectionMode
            ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clearBlockSelection)
            : null,
        actions: _selectionMode
            ? [
                IconButton(onPressed: canvas.blocks.isEmpty ? null : () => setState(() => _selectedBlockIds
                  ..clear()
                  ..addAll(canvas.blocks.map((e) => e.id))), icon: const Icon(Icons.select_all_rounded), tooltip: 'Select all'),
                IconButton(onPressed: _clearBlockSelection, icon: const Icon(Icons.deselect_rounded), tooltip: 'Clear'),
                IconButton(onPressed: _deleteSelectedBlocks, icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete selected'),
              ]
            : [
                IconButton(onPressed: _toggleMapView, icon: Icon(_mapView ? Icons.view_agenda_rounded : Icons.hub_rounded), tooltip: _mapView ? 'List view' : 'Map view'),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'rename') await _renameCanvas();
                    if (value == 'markdown') await _exportMarkdown();
                    if (value == 'pdf') await _exportPdf();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'markdown', child: Text('Export Markdown')),
                    PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                  ],
                ),
              ],
      ),
      floatingActionButton: _mapView || _selectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'askAi',
                  onPressed: _working ? null : _askAiToAddSection,
                  icon: _working ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_working ? 'Writing...' : 'Ask AI to add'),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'addNote',
                  onPressed: _addManualNote,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Add note'),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            _CanvasDetailHero(canvas: canvas, theme: theme, mapView: _mapView),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _mapView
                    ? _CanvasMapView(canvas: canvas, controller: _mapController, nodePositions: _nodePositions, onNodeTap: _jumpToBlock, onNodeMoved: _updateNodePosition, onRestorePositions: _replaceNodePositions, onViewportReady: _applyMapCenter, onMapChanged: _persistMapState)
                    : ListView(
                        key: const ValueKey('list'),
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
                        children: [
                          for (final block in canvas.blocks)
                            Padding(
                              key: _blockKeys.putIfAbsent(block.id, () => GlobalKey()),
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _CanvasBlockCard(
                                block: block,
                                theme: theme,
                                selected: _selectedBlockIds.contains(block.id),
                                highlighted: _highlightedBlockId == block.id,
                                onTap: _selectionMode ? () => _toggleBlockSelection(block.id) : null,
                                onLongPress: () => _toggleBlockSelection(block.id, forceSelect: true),
                                onDelete: () => _deleteBlock(block),
                                onEdit: () => _editNoteBlock(block),
                                onNavigate: _canNavigateToSource(block) ? () => _openBlockSource(block) : null,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasHero extends StatelessWidget {
  const _CanvasHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF142134), Color(0xFF201730), Color(0xFF090B11)],
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.auto_awesome_mosaic_rounded, color: Color(0xFF12C6FF), size: 30),
              SizedBox(width: 12),
              Expanded(child: Text('Research Canvas', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white))),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Your premium AI workspace for saved answers, manual notes, Debate Room outcomes, and AI-built sections that keep growing over time.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CanvasHomeCard extends StatelessWidget {
  final ResearchCanvas canvas;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onStar;
  final VoidCallback onDelete;
  final bool selected;

  const _CanvasHomeCard({
    required this.canvas,
    required this.onTap,
    required this.onStar,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _CanvasThemeData.fromKey(canvas.themeKey);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.cardGradient),
            border: Border.all(color: selected ? theme.accent : theme.border, width: selected ? 2.2 : 1),
            boxShadow: selected ? [BoxShadow(color: theme.accent.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 10))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: theme.accent.withOpacity(.14),
                      border: Border.all(color: theme.border),
                    ),
                    child: Icon(selected ? Icons.check_circle_rounded : Icons.auto_awesome_mosaic_rounded, color: theme.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(canvas.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${canvas.blocks.length} blocks • updated ${_fmtDate(canvas.updatedAt)}', style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  if (canvas.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.star_rounded, color: theme.accent),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'star') onStar();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'star', child: Text(canvas.pinned ? 'Unstar' : 'Star')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...canvas.tags.take(6).map((tag) => _TagPill(tag: tag)),
                  if (canvas.pinned) const _TagPill(tag: 'Starred'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CanvasHomeMapView extends StatefulWidget {
  final List<ResearchCanvas> canvases;
  final ValueChanged<ResearchCanvas> onNodeTap;

  const _CanvasHomeMapView({required this.canvases, required this.onNodeTap});

  @override
  State<_CanvasHomeMapView> createState() => _CanvasHomeMapViewState();
}

class _CanvasHomeMapViewState extends State<_CanvasHomeMapView> {
  static const Size _boardSize = Size(1640, 1160);
  static const Offset _rootCenter = Offset(820, 580);
  final TransformationController _controller = TransformationController();
  final Map<String, Offset> _nodePositions = <String, Offset>{};
  final List<_GraphSnapshot> _undoStack = <_GraphSnapshot>[];
  final List<_GraphSnapshot> _redoStack = <_GraphSnapshot>[];
  bool _loaded = false;
  bool _centerApplied = false;
  String? _draggingId;
  String? _dragStartId;
  Offset? _dragOriginPosition;

  String get _transformKey => 'research_canvas_home_map_transform_v2';
  String get _nodeKey => 'research_canvas_home_map_nodes_v2';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void didUpdateWidget(covariant _CanvasHomeMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvases.length != widget.canvases.length) {
      _rebuildMissingPositions();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = <String, Offset>{};
    final rawNodes = prefs.getString(_nodeKey);
    if (rawNodes != null && rawNodes.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNodes) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final value = entry.value;
          if (value is Map) {
            final dx = (value['dx'] as num?)?.toDouble();
            final dy = (value['dy'] as num?)?.toDouble();
            if (dx != null && dy != null) loaded[entry.key] = Offset(dx, dy);
          }
        }
      } catch (_) {}
    }
    final next = _buildDefaultPositions(widget.canvases, loaded: loaded);
    final rawTransform = prefs.getStringList(_transformKey);
    if (!mounted) return;
    setState(() {
      _nodePositions
        ..clear()
        ..addAll(next);
      _loaded = true;
    });
    if (rawTransform != null && rawTransform.length == 16) {
      final parsed = rawTransform.map((e) => double.tryParse(e) ?? 0).toList(growable: false);
      _controller.value = Matrix4.fromList(parsed);
      _centerApplied = true;
    }
  }

  Map<String, Offset> _buildDefaultPositions(List<ResearchCanvas> canvases, {Map<String, Offset> loaded = const <String, Offset>{}}) {
    final next = <String, Offset>{};
    const ringCapacity = 6;
    const baseRadius = 280.0;
    const ringGap = 180.0;
    for (var index = 0; index < canvases.length; index++) {
      final canvas = canvases[index];
      if (loaded.containsKey(canvas.id)) {
        next[canvas.id] = loaded[canvas.id]!;
        continue;
      }
      final ring = index ~/ ringCapacity;
      final slot = index % ringCapacity;
      final itemsInRing = math.min(ringCapacity, canvases.length - ring * ringCapacity);
      final angle = -math.pi / 2 + ((math.pi * 2 * slot) / math.max(1, itemsInRing));
      final radius = baseRadius + (ring * ringGap);
      next[canvas.id] = Offset(
        _rootCenter.dx + math.cos(angle) * radius,
        _rootCenter.dy + math.sin(angle) * radius,
      );
    }
    return next;
  }

  void _rebuildMissingPositions() {
    final rebuilt = _buildDefaultPositions(widget.canvases, loaded: _nodePositions);
    if (!mounted) return;
    setState(() {
      _nodePositions
        ..clear()
        ..addAll(rebuilt);
    });
  }

  void _pushSnapshot() {
    _undoStack.add(_GraphSnapshot(
      positions: Map<String, Offset>.from(_nodePositions),
      transform: List<double>.from(_controller.value.storage),
    ));
    if (_undoStack.length > 36) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_transformKey, _controller.value.storage.map((e) => e.toString()).toList(growable: false));
    await prefs.setString(_nodeKey, jsonEncode(_nodePositions.map((key, value) => MapEntry(key, <String, double>{'dx': value.dx, 'dy': value.dy}))));
  }

  void _recenter(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    final dx = viewport.width / 2 - _rootCenter.dx;
    final dy = viewport.height / 2 - _rootCenter.dy;
    _controller.value = Matrix4.identity()..translate(dx, dy);
    _centerApplied = true;
  }

  void _applyInitialCenter(Size viewport) {
    if (_centerApplied) return;
    _recenter(viewport);
  }

  void _restoreSnapshot(_GraphSnapshot snapshot) {
    setState(() {
      _nodePositions
        ..clear()
        ..addAll(snapshot.positions);
      _controller.value = Matrix4.fromList(snapshot.transform);
    });
    _persistState();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_GraphSnapshot(positions: Map<String, Offset>.from(_nodePositions), transform: List<double>.from(_controller.value.storage)));
    _restoreSnapshot(_undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_GraphSnapshot(positions: Map<String, Offset>.from(_nodePositions), transform: List<double>.from(_controller.value.storage)));
    _restoreSnapshot(_redoStack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.canvases.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Center(child: Text('No canvases to map yet', style: TextStyle(color: Colors.white54))),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyInitialCenter(Size(constraints.maxWidth, constraints.maxHeight)));
        return Stack(
          children: [
            InteractiveViewer(
              transformationController: _controller,
              minScale: .62,
              maxScale: 2.4,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(260),
              onInteractionEnd: (_) => _persistState(),
              child: SizedBox(
                width: _boardSize.width,
                height: _boardSize.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CustomPaint(
                      size: _boardSize,
                      painter: _MapLinksPainter(
                        center: _rootCenter,
                        nodes: widget.canvases.map((canvas) => _nodePositions[canvas.id] ?? _rootCenter).toList(growable: false),
                        color: const Color(0x3312C6FF),
                      ),
                    ),
                    Positioned(
                      left: _rootCenter.dx - 106,
                      top: _rootCenter.dy - 38,
                      child: const _MapNode(label: 'Research Canvas', color: Color(0xFF12C6FF), big: true),
                    ),
                    ...widget.canvases.map((canvas) {
                      final theme = _CanvasThemeData.fromKey(canvas.themeKey);
                      final position = _nodePositions[canvas.id] ?? _rootCenter;
                      return Positioned(
                        key: ValueKey('home_map_${canvas.id}'),
                        left: position.dx - 86,
                        top: position.dy - 34,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onNodeTap(canvas),
                          onLongPressStart: (_) {
                            _pushSnapshot();
                            setState(() {
                              _draggingId = canvas.id;
                              _dragStartId = canvas.id;
                              _dragOriginPosition = position;
                            });
                          },
                          onLongPressMoveUpdate: (details) {
                            if (_dragStartId != canvas.id || _dragOriginPosition == null) return;
                            final origin = _dragOriginPosition!;
                            setState(() {
                              _nodePositions[canvas.id] = Offset(
                                (origin.dx + details.offsetFromOrigin.dx).clamp(130, _boardSize.width - 130),
                                (origin.dy + details.offsetFromOrigin.dy).clamp(130, _boardSize.height - 130),
                              );
                            });
                          },
                          onLongPressEnd: (_) {
                            setState(() {
                              _draggingId = null;
                              _dragStartId = null;
                              _dragOriginPosition = null;
                            });
                            _persistState();
                          },
                          child: _MapNode(
                            label: canvas.title,
                            color: theme.accent,
                            selected: _draggingId == canvas.id,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: IgnorePointer(
                ignoring: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xAA0C0F15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text('Hold and drag to move nodes • Tap node to open', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MiniMapAction(icon: Icons.undo_rounded, onTap: _undo, enabled: _undoStack.isNotEmpty),
                  const SizedBox(height: 8),
                  _MiniMapAction(icon: Icons.redo_rounded, onTap: _redo, enabled: _redoStack.isNotEmpty),
                  const SizedBox(height: 8),
                  _MiniMapAction(icon: Icons.center_focus_strong_rounded, onTap: () {
                    _pushSnapshot();
                    _recenter(Size(constraints.maxWidth, constraints.maxHeight));
                    _persistState();
                    setState(() {});
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CanvasDetailHero extends StatelessWidget {
  final ResearchCanvas canvas;
  final _CanvasThemeData theme;
  final bool mapView;

  const _CanvasDetailHero({required this.canvas, required this.theme, required this.mapView});

  @override
  Widget build(BuildContext context) {
    final chips = <String>['${canvas.blocks.length} blocks', ...canvas.tags.take(3)];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: theme.heroGradient),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(canvas.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.12)),
                const SizedBox(height: 8),
                Text(
                  ResearchCanvasStore.sanitizeBodyText(canvas.description).isEmpty
                      ? 'Premium research board for notes, saved answers, and AI sections.'
                      : ResearchCanvasStore.sanitizeBodyText(canvas.description),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips.map((tag) => _CanvasChip(label: tag, selected: false, onTap: () {})).toList(growable: false),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [Color(0xFF12C6FF), Color(0xFF8D63FF)]),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Text(mapView ? 'List' : 'Map', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasMapView extends StatefulWidget {
  final ResearchCanvas canvas;
  final TransformationController controller;
  final Map<String, Offset> nodePositions;
  final ValueChanged<String> onNodeTap;
  final void Function(String, Offset) onNodeMoved;
  final ValueChanged<Map<String, Offset>> onRestorePositions;
  final ValueChanged<Size> onViewportReady;
  final Future<void> Function() onMapChanged;

  const _CanvasMapView({
    required this.canvas,
    required this.controller,
    required this.nodePositions,
    required this.onNodeTap,
    required this.onNodeMoved,
    required this.onRestorePositions,
    required this.onViewportReady,
    required this.onMapChanged,
  });

  @override
  State<_CanvasMapView> createState() => _CanvasMapViewState();
}

class _CanvasMapViewState extends State<_CanvasMapView> {
  String? _draggingId;
  String? _dragStartId;
  Offset? _dragOriginPosition;
  final List<_GraphSnapshot> _undoStack = <_GraphSnapshot>[];
  final List<_GraphSnapshot> _redoStack = <_GraphSnapshot>[];

  static const Size _boardSize = Size(1600, 1120);
  static const Offset _rootCenter = Offset(800, 560);

  void _pushSnapshot() {
    _undoStack.add(_GraphSnapshot(
      positions: Map<String, Offset>.from(widget.nodePositions),
      transform: List<double>.from(widget.controller.value.storage),
    ));
    if (_undoStack.length > 36) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restoreSnapshot(_GraphSnapshot snapshot) {
    widget.onRestorePositions(snapshot.positions);
    widget.controller.value = Matrix4.fromList(snapshot.transform);
    widget.onMapChanged();
    setState(() {});
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_GraphSnapshot(
      positions: Map<String, Offset>.from(widget.nodePositions),
      transform: List<double>.from(widget.controller.value.storage),
    ));
    _restoreSnapshot(_undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_GraphSnapshot(
      positions: Map<String, Offset>.from(widget.nodePositions),
      transform: List<double>.from(widget.controller.value.storage),
    ));
    _restoreSnapshot(_redoStack.removeLast());
  }

  void _recenter(Size viewport) {
    if (viewport.width <= 0 || viewport.height <= 0) return;
    final dx = viewport.width / 2 - _rootCenter.dx;
    final dy = viewport.height / 2 - _rootCenter.dy;
    widget.controller.value = Matrix4.identity()..translate(dx, dy);
    widget.onMapChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.canvas.blocks.take(36).toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onViewportReady(MediaQuery.of(context).size));
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          InteractiveViewer(
            transformationController: widget.controller,
            minScale: .62,
            maxScale: 2.6,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(280),
            onInteractionEnd: (_) => widget.onMapChanged(),
            child: SizedBox(
              width: _boardSize.width,
              height: _boardSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: _boardSize,
                    painter: _MapLinksPainter(
                      center: _rootCenter,
                      nodes: blocks.map((block) => widget.nodePositions[block.id] ?? _rootCenter).toList(growable: false),
                      color: _CanvasThemeData.fromKey(widget.canvas.themeKey).accent.withOpacity(.30),
                    ),
                  ),
                  Positioned(
                    left: _rootCenter.dx - 96,
                    top: _rootCenter.dy - 36,
                    child: _MapNode(label: widget.canvas.title, color: _CanvasThemeData.fromKey(widget.canvas.themeKey).accent, big: true),
                  ),
                  ...blocks.map((block) {
                    final position = widget.nodePositions[block.id] ?? _rootCenter;
                    return Positioned(
                      key: ValueKey('map_${block.id}'),
                      left: position.dx - 86,
                      top: position.dy - 34,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onNodeTap(block.id),
                        onLongPressStart: (_) {
                          _pushSnapshot();
                          setState(() {
                            _draggingId = block.id;
                            _dragStartId = block.id;
                            _dragOriginPosition = position;
                          });
                        },
                        onLongPressMoveUpdate: (details) {
                          if (_dragStartId != block.id || _dragOriginPosition == null) return;
                          final origin = _dragOriginPosition!;
                          widget.onNodeMoved(
                            block.id,
                            Offset(
                              (origin.dx + details.offsetFromOrigin.dx).clamp(120, _boardSize.width - 120),
                              (origin.dy + details.offsetFromOrigin.dy).clamp(120, _boardSize.height - 120),
                            ),
                          );
                        },
                        onLongPressEnd: (_) {
                          setState(() {
                            _draggingId = null;
                            _dragStartId = null;
                            _dragOriginPosition = null;
                          });
                          widget.onMapChanged();
                        },
                        child: _MapNode(
                          label: block.title,
                          color: _colorForBlock(block),
                          selected: _draggingId == block.id,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          Positioned(
            left: 14,
            top: 14,
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xAA0C0F15),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text('Hold and drag to move nodes • Tap node to open', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                _MiniMapAction(icon: Icons.undo_rounded, onTap: _undo, enabled: _undoStack.isNotEmpty),
                const SizedBox(height: 8),
                _MiniMapAction(icon: Icons.redo_rounded, onTap: _redo, enabled: _redoStack.isNotEmpty),
                const SizedBox(height: 8),
                _MiniMapAction(icon: Icons.center_focus_strong_rounded, onTap: () {
                  _pushSnapshot();
                  _recenter(Size(constraints.maxWidth, constraints.maxHeight));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForBlock(ResearchCanvasBlock block) {
    switch (block.type) {
      case 'debate':
        return const Color(0xFF8D63FF);
      case 'image':
        return const Color(0xFFFF5B93);
      case 'audio':
        return const Color(0xFF29D17D);
      case 'video':
        return const Color(0xFFFF8A3D);
      case 'note':
        return const Color(0xFF12C6FF);
      default:
        return const Color(0xFF4B8EFF);
    }
  }
}

class _GraphSnapshot {
  final Map<String, Offset> positions;
  final List<double> transform;

  const _GraphSnapshot({required this.positions, required this.transform});
}

class _MiniMapAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _MiniMapAction({required this.icon, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : .4,
      child: Material(
        color: const Color(0xCC0C0F15),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _MapLinksPainter extends CustomPainter {
  final Offset center;
  final List<Offset> nodes;
  final Color color;

  const _MapLinksPainter({required this.center, required this.nodes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    for (final node in nodes) {
      canvas.drawLine(center, node, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapLinksPainter oldDelegate) => oldDelegate.center != center || oldDelegate.nodes != nodes || oldDelegate.color != color;
}

class _MapNode extends StatelessWidget {
  final String label;
  final Color color;
  final bool big;
  final bool selected;
  final VoidCallback? onTap;

  const _MapNode({required this.label, required this.color, this.onTap, this.big = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(big ? 24 : 18),
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(maxWidth: big ? 210 : 160, minWidth: big ? 150 : 108, minHeight: big ? 62 : 54),
          padding: EdgeInsets.symmetric(horizontal: big ? 18 : 14, vertical: big ? 14 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(big ? 24 : 18),
            gradient: LinearGradient(colors: [color.withOpacity(.42), const Color(0xFF10141D)]),
            border: Border.all(color: selected ? color : color.withOpacity(.85), width: selected ? 2.3 : 1.4),
            boxShadow: [BoxShadow(color: color.withOpacity(selected ? .34 : .18), blurRadius: selected ? 26 : 18, offset: const Offset(0, 8))],
          ),
          child: Text(
            ResearchCanvasStore.sanitizeTitleText(label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 16 : 14, color: Colors.white, height: 1.15),
          ),
        ),
      ),
    );
  }
}

class _CanvasBlockCard extends StatelessWidget {
  final ResearchCanvasBlock block;
  final _CanvasThemeData theme;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onNavigate;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool highlighted;

  const _CanvasBlockCard({required this.block, required this.theme, required this.onDelete, this.onEdit, this.onNavigate, this.onTap, this.onLongPress, this.selected = false, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final sourceBrand = _brandForBlock(block);
    final meta = [block.sourceLabel, block.modelLabel, _fmtDate(block.createdAt)]
        .map(ResearchCanvasStore.sanitizeTitleText)
        .where((e) => e.isNotEmpty)
        .join(' • ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [sourceBrand.tertiary.withOpacity(.82), const Color(0xFF0E1219)]),
            border: Border.all(color: (selected || highlighted) ? theme.accent : sourceBrand.border(Brightness.dark), width: (selected || highlighted) ? 2.2 : 1),
            boxShadow: (selected || highlighted) ? [BoxShadow(color: theme.accent.withOpacity(.24), blurRadius: 22, offset: const Offset(0, 10))] : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 4, height: 180, margin: const EdgeInsets.only(right: 14), decoration: BoxDecoration(color: sourceBrand.accent, borderRadius: BorderRadius.circular(999))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: sourceBrand.iconFill(Brightness.dark),
                            border: Border.all(color: sourceBrand.border(Brightness.dark)),
                          ),
                          child: Icon(_iconForBlock(block.type), color: sourceBrand.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ResearchCanvasStore.sanitizeTitleText(block.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                              const SizedBox(height: 4),
                              Text(meta, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') onEdit?.call();
                            if (v == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                    if ((block.question ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withOpacity(.04),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Original question', style: TextStyle(color: sourceBrand.accent, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(ResearchCanvasStore.sanitizeBodyText(block.question), style: const TextStyle(color: Colors.white, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (block.type == 'image' || block.type == 'video' || block.type == 'audio')
                      _CanvasMediaPreview(block: block, accent: sourceBrand.accent)
                    else
                      MarkdownBubble(text: ResearchCanvasStore.sanitizeBodyText(block.content), textColor: Colors.white, linkColor: sourceBrand.accent),
                    if (block.type == 'debate' && block.extra['transcript'] is List) ...[
                      const SizedBox(height: 12),
                      ExpansionTile(
                        collapsedIconColor: Colors.white70,
                        iconColor: Colors.white,
                        title: const Text('Expand debate rounds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        childrenPadding: const EdgeInsets.only(bottom: 10),
                        children: (block.extra['transcript'] as List)
                            .map((e) => Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${(e as Map)['speaker'] ?? ''}: ${(e)['content'] ?? ''}',
                                      style: const TextStyle(color: Colors.white70, height: 1.4),
                                    ),
                                  ),
                                ))
                            .toList(growable: false),
                      ),
                    ],
                    if (block.type == 'ai_section' && ResearchCanvasStore.sanitizeBodyText(block.content).trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      CitationBuilderPanel(
                        responseText: ResearchCanvasStore.sanitizeBodyText(block.content),
                        responseId: 'canvas_${block.id}',
                        accentColor: sourceBrand.accent,
                      ),
                    ],
                    if (block.tags.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: block.tags.map((tag) => _TagPill(tag: tag)).toList(growable: false)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ProviderBranding _brandForBlock(ResearchCanvasBlock block) {
    switch (block.type) {
      case 'debate':
        return const ProviderBranding(key: 'debate', label: 'Debate', accent: Color(0xFF8D63FF), secondary: Color(0xFF4D2CA5), tertiary: Color(0xFF1A122B));
      case 'image':
        return const ProviderBranding(key: 'image', label: 'Image', accent: Color(0xFFFF5B93), secondary: Color(0xFF842A52), tertiary: Color(0xFF24101A));
      case 'audio':
        return const ProviderBranding(key: 'audio', label: 'Audio', accent: Color(0xFF29D17D), secondary: Color(0xFF13673F), tertiary: Color(0xFF0E1E16));
      case 'video':
        return const ProviderBranding(key: 'video', label: 'Video', accent: Color(0xFFFF8A3D), secondary: Color(0xFF8B4519), tertiary: Color(0xFF25150C));
      default:
        return ProviderBranding.resolve(provider: block.modelLabel, displayName: block.title);
    }
  }

  IconData _iconForBlock(String type) {
    switch (type) {
      case 'debate':
        return Icons.forum_rounded;
      case 'note':
        return Icons.edit_note_rounded;
      case 'ai_section':
        return Icons.auto_awesome_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'audio':
        return Icons.graphic_eq_rounded;
      case 'video':
        return Icons.videocam_rounded;
      default:
        return Icons.notes_rounded;
    }
  }
}

class _CanvasMediaPreview extends StatefulWidget {
  final ResearchCanvasBlock block;
  final Color accent;
  final bool expanded;

  const _CanvasMediaPreview({required this.block, required this.accent, this.expanded = false});

  @override
  State<_CanvasMediaPreview> createState() => _CanvasMediaPreviewState();
}

class _CanvasMediaPreviewState extends State<_CanvasMediaPreview> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  bool _videoReady = false;
  bool _playing = false;

  List<String> _candidateMediaUrls() {
    final out = <String>[];

    void add(dynamic value) {
      if (value == null) return;
      if (value is List) {
        for (final entry in value) {
          add(entry);
        }
        return;
      }
      final text = value.toString().trim();
      if (text.isEmpty || out.contains(text)) return;
      out.add(text);
    }

    add(widget.block.mediaUrl);
    add(widget.block.thumbnailUrl);
    final extra = widget.block.extra;
    add(extra['canvasMediaUrl']);
    add(extra['canvasThumbnailUrl']);
    add(extra['mediaUrl']);
    add(extra['thumbnailUrl']);
    add(extra['videoUrl']);
    add(extra['audioUrl']);
    add(extra['imageUrl']);
    add(extra['posterUrl']);
    add(extra['thumbUrl']);
    add(extra['previewImageUrl']);
    add(extra['downloadUrl']);
    add(extra['outputUrl']);
    add(extra['fileUrl']);
    add(extra['playbackUrl']);
    add(extra['previewUrl']);
    add(extra['sourceUrl']);
    add(extra['localFilePath']);
    add(extra['mediaCandidates']);
    add(extra['playableCandidates']);
    add(extra['videoCandidates']);
    add(extra['audioCandidates']);
    add(extra['imageCandidates']);
    add(extra['allUrls']);
    return out;
  }

  bool _looksLikeType(String url, String type) {
    final lower = url.toLowerCase();
    final bare = lower.split('#').first.split('?').first;
    final hints = Uri.tryParse(url)?.queryParametersAll.values.expand((e) => e).join(' ').toLowerCase() ?? '';
    switch (type) {
      case 'video':
        return bare.endsWith('.mp4') ||
            bare.endsWith('.mov') ||
            bare.endsWith('.webm') ||
            bare.endsWith('.mkv') ||
            bare.endsWith('.m4v') ||
            lower.contains('video/mp4') ||
            lower.contains('video%2f') ||
            lower.contains('response-content-type=video') ||
            lower.contains('content-type=video') ||
            lower.contains('mime=video') ||
            lower.contains('/video/') ||
            hints.contains('video');
      case 'audio':
        return bare.endsWith('.mp3') ||
            bare.endsWith('.wav') ||
            bare.endsWith('.m4a') ||
            bare.endsWith('.aac') ||
            bare.endsWith('.ogg') ||
            bare.endsWith('.flac') ||
            lower.contains('audio/') ||
            lower.contains('audio%2f') ||
            lower.contains('response-content-type=audio') ||
            lower.contains('content-type=audio') ||
            lower.contains('mime=audio') ||
            hints.contains('audio');
      case 'image':
        return bare.endsWith('.png') ||
            bare.endsWith('.jpg') ||
            bare.endsWith('.jpeg') ||
            bare.endsWith('.webp') ||
            bare.endsWith('.gif') ||
            lower.contains('image/') ||
            lower.contains('image%2f') ||
            lower.contains('response-content-type=image') ||
            lower.contains('content-type=image') ||
            lower.contains('mime=image') ||
            hints.contains('image');
      default:
        return false;
    }
  }

  bool _isLikelyThumbnail(String url) {
    final lower = url.toLowerCase();
    return lower.contains('thumb') ||
        lower.contains('thumbnail') ||
        lower.contains('poster') ||
        lower.contains('preview-image') ||
        lower.contains('preview_image');
  }

  String? _resolvedMediaUrl() {
    final candidates = _candidateMediaUrls();
    if (candidates.isEmpty) return null;

    for (final candidate in candidates) {
      if (_looksLikeType(candidate, widget.block.type)) return candidate;
    }

    if (widget.block.type == 'video') {
      for (final candidate in candidates) {
        if (!_looksLikeType(candidate, 'image') && !_isLikelyThumbnail(candidate)) {
          return candidate;
        }
      }
    }

    if (widget.block.type == 'audio') {
      for (final candidate in candidates) {
        if (!_looksLikeType(candidate, 'image') && !_looksLikeType(candidate, 'video')) {
          return candidate;
        }
      }
    }

    return candidates.first;
  }

  List<String> _videoCandidateUrls() {
    final candidates = _candidateMediaUrls();
    final exact = <String>[];
    final fallback = <String>[];

    for (final candidate in candidates) {
      if (_looksLikeType(candidate, 'video')) {
        if (!exact.contains(candidate)) exact.add(candidate);
      } else if (!_looksLikeType(candidate, 'image') && !_isLikelyThumbnail(candidate)) {
        if (!fallback.contains(candidate)) fallback.add(candidate);
      }
    }

    final resolved = _resolvedMediaUrl();
    if (resolved != null && resolved.trim().isNotEmpty) {
      fallback.insert(0, resolved.trim());
    }

    return [...exact, ...fallback].where((candidate) => candidate.trim().isNotEmpty).toSet().toList(growable: false);
  }

  String? _resolvedImagePreviewUrl() {
    final candidates = _candidateMediaUrls();
    for (final candidate in candidates) {
      if (_looksLikeType(candidate, 'image') || _isLikelyThumbnail(candidate)) return candidate;
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  Future<void> _initVideoController() async {
    if (widget.block.type != 'video') return;
    final candidates = _videoCandidateUrls();
    if (candidates.isEmpty) return;
    for (final url in candidates) {
      final clean = url.trim();
      if (clean.isEmpty) continue;
      VideoPlayerController? controller;
      try {
        controller = ResearchCanvasStore.looksLikeLocalPath(clean)
            ? VideoPlayerController.file(File(clean.replaceFirst('file://', '')))
            : VideoPlayerController.networkUrl(Uri.parse(clean));
        await controller.initialize();
        await controller.setLooping(true);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        await _videoController?.dispose();
        setState(() {
          _videoController = controller;
          _videoReady = true;
        });
        return;
      } catch (_) {
        await controller?.dispose();
      }
    }
    if (mounted) {
      setState(() => _videoReady = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.block.type == 'video') {
      _initVideoController();
    }
    if (widget.block.type == 'audio') {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _CanvasMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id || oldWidget.block.mediaUrl != widget.block.mediaUrl || oldWidget.block.thumbnailUrl != widget.block.thumbnailUrl) {
      if (widget.block.type == 'video') {
        _videoReady = false;
        _initVideoController();
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    final url = _resolvedMediaUrl();
    if (_audioPlayer == null || url == null || url.trim().isEmpty) return;
    if (_playing) {
      await _audioPlayer!.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    final clean = url.trim();
    if (ResearchCanvasStore.looksLikeLocalPath(clean)) {
      await _audioPlayer!.play(DeviceFileSource(clean.replaceFirst('file://', '')));
    } else {
      await _audioPlayer!.play(UrlSource(clean));
    }
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _resolvedMediaUrl();
    final contentText = ResearchCanvasStore.sanitizeBodyText(widget.block.content);
    final localLabel = ResearchCanvasStore.localPathLabel(mediaUrl);
    if (widget.block.type == 'audio') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(.05),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: _toggleAudio,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.accent.withOpacity(.18), border: Border.all(color: widget.accent.withOpacity(.7))),
                child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.accent),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(localLabel.isEmpty ? 'Audio saved in canvas' : localLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                if (contentText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(contentText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                ],
              ]),
            ),
          ],
        ),
      );
    }
    if (mediaUrl == null || mediaUrl.trim().isEmpty) {
      return Container(
        height: 170,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.white.withOpacity(.05), border: Border.all(color: Colors.white12)),
        child: const Center(child: Text('Preview unavailable', style: TextStyle(color: Colors.white54))),
      );
    }
    final clean = mediaUrl.trim();
    if (widget.block.type == 'video') {
      if (_videoReady && _videoController != null) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              final controller = _videoController!;
              await showDialog<void>(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio == 0 ? 16 / 9 : _videoController!.value.aspectRatio,
                child: Stack(
                  children: [
                    Positioned.fill(child: VideoPlayer(_videoController!)),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: FloatingActionButton.small(
                        heroTag: null,
                        backgroundColor: Colors.black54,
                        onPressed: () {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                          if (mounted) setState(() {});
                        },
                        child: Icon(_videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      final preview = _resolvedImagePreviewUrl();
      if (preview != null && preview.trim().isNotEmpty && (_looksLikeType(preview, 'image') || _isLikelyThumbnail(preview))) {
        final previewWidget = ResearchCanvasStore.looksLikeLocalPath(preview)
            ? Image.file(File(preview.replaceFirst('file://', '')), height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _mediaFallback(localLabel, contentText))
            : Image.network(preview, height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _mediaFallback(localLabel, contentText));
        return Stack(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: previewWidget),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.black38,
                ),
                child: const Center(
                  child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 54),
                ),
              ),
            ),
          ],
        );
      }
      return Container(
        height: 210,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.white.withOpacity(.05), border: Border.all(color: Colors.white12)),
        child: Center(child: Text(localLabel.isEmpty ? 'Loading video preview...' : localLabel, style: const TextStyle(color: Colors.white54))),
      );
    }
    final imageUrl = _resolvedImagePreviewUrl() ?? clean;
    final imageWidget = ResearchCanvasStore.looksLikeLocalPath(imageUrl)
        ? Image.file(File(imageUrl.replaceFirst('file://', '')), height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _mediaFallback(localLabel, contentText))
        : Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _mediaFallback(localLabel, contentText));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ResearchCanvasStore.looksLikeLocalPath(imageUrl)
                    ? Image.file(File(imageUrl.replaceFirst('file://', '')), fit: BoxFit.contain)
                    : Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
          );
        },
        child: ClipRRect(borderRadius: BorderRadius.circular(18), child: imageWidget),
      ),
    );
  }

  Widget _mediaFallback(String localLabel, String contentText) => Container(
        height: 170,
        color: Colors.white.withOpacity(.05),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localLabel.isEmpty ? 'Preview unavailable' : localLabel, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            if (contentText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(contentText, style: const TextStyle(color: Colors.white54)),
            ],
          ],
        ),
      );
}


class _CanvasField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;

  const _CanvasField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF12C6FF)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
class _CanvasChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CanvasChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected ? const LinearGradient(colors: [Color(0xFF12C6FF), Color(0xFF8D63FF)]) : null,
          color: selected ? null : Colors.white.withOpacity(.06),
          border: Border.all(color: selected ? Colors.transparent : Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String tag;
  const _TagPill({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(.06),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(tag, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _CanvasThemeData {
  final Color accent;
  final List<Color> heroGradient;
  final List<Color> cardGradient;
  final Color border;

  const _CanvasThemeData({required this.accent, required this.heroGradient, required this.cardGradient, required this.border});

  factory _CanvasThemeData.fromKey(String key) {
    switch (key) {
      case 'rose':
        return const _CanvasThemeData(
          accent: Color(0xFFFF5B93),
          heroGradient: [Color(0xFF251124), Color(0xFF34112B), Color(0xFF090B11)],
          cardGradient: [Color(0xFF24111D), Color(0xFF17111E), Color(0xFF0C0E14)],
          border: Color(0x66FF5B93),
        );
      case 'mint':
        return const _CanvasThemeData(
          accent: Color(0xFF29D17D),
          heroGradient: [Color(0xFF11211A), Color(0xFF12261E), Color(0xFF090B11)],
          cardGradient: [Color(0xFF111E19), Color(0xFF121A18), Color(0xFF0C0E14)],
          border: Color(0x6629D17D),
        );
      case 'ember':
        return const _CanvasThemeData(
          accent: Color(0xFFFF8A3D),
          heroGradient: [Color(0xFF25160E), Color(0xFF2D1312), Color(0xFF090B11)],
          cardGradient: [Color(0xFF24160E), Color(0xFF1D1411), Color(0xFF0C0E14)],
          border: Color(0x66FF8A3D),
        );
      case 'aurora':
      default:
        return const _CanvasThemeData(
          accent: Color(0xFF12C6FF),
          heroGradient: [Color(0xFF111C2C), Color(0xFF1A1429), Color(0xFF090B11)],
          cardGradient: [Color(0xFF111821), Color(0xFF15141F), Color(0xFF0C0E14)],
          border: Color(0x6612C6FF),
        );
    }
  }
}

String _fmtDate(DateTime dt) {
  final month = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][dt.month - 1];
  return '${dt.day} $month';
}





