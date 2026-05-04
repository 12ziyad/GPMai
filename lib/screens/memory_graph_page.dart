import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/memory_graph_models.dart';
import '../services/gpmai_memory_api.dart';

class MemoryGraphPage extends StatefulWidget {
  final GpmaiMemoryApi api;

  const MemoryGraphPage({super.key, GpmaiMemoryApi? api}) : api = api ?? const GpmaiMemoryApi();

  @override
  State<MemoryGraphPage> createState() => _MemoryGraphPageState();
}

class _MemoryGraphPageState extends State<MemoryGraphPage> {
  static MemoryGraphResponse? _cachedGraph;
  static int _cachedGraphAt = 0;
  static const Duration _graphCacheTtl = Duration(seconds: 60);
  static const Duration _manualRefreshCooldown = Duration(seconds: 20);

  MemoryGraphResponse? _graph;
  bool _loading = true;
  bool _legendOpen = false;
  String? _error;
  MemoryNodeVm? _selected;
  int _lastManualRefreshAt = 0;
  final TransformationController _controller = TransformationController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cached = _cachedGraph;
    if (!force && cached != null && (now - _cachedGraphAt) < _graphCacheTtl.inMilliseconds) {
      setState(() {
        _graph = cached;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitGraph());
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final graph = await widget.api.graph();
      _cachedGraph = graph;
      _cachedGraphAt = DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() => _graph = graph);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitGraph());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manualRefresh() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastManualRefreshAt;
    if (elapsed < _manualRefreshCooldown.inMilliseconds) {
      final remaining = ((_manualRefreshCooldown.inMilliseconds - elapsed) / 1000).ceil();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Graph refresh is cooling down for $remaining sec to protect Firestore quota.')),
      );
      return;
    }
    _lastManualRefreshAt = now;
    await _load(force: true);
  }

  void _fitGraph() {
    final graph = _graph;
    if (graph == null || graph.nodes.isEmpty || !mounted) return;
    final layout = _computeLayout(graph.nodes);
    if (layout.positions.isEmpty) return;
    final xs = layout.positions.values.map((e) => e.dx).toList();
    final ys = layout.positions.values.map((e) => e.dy).toList();
    final minX = xs.reduce(math.min) - 200;
    final maxX = xs.reduce(math.max) + 200;
    final minY = ys.reduce(math.min) - 200;
    final maxY = ys.reduce(math.max) + 200;
    final graphW = maxX - minX;
    final graphH = maxY - minY;
    final viewport = MediaQuery.of(context).size;
    final targetW = viewport.width - 40;
    final targetH = viewport.height - 220;
    final scale = [targetW / graphW, targetH / graphH, 1.0].reduce(math.min).clamp(0.34, 0.92);
    final dx = (targetW - graphW * scale) / 2 - minX * scale;
    final dy = (targetH - graphH * scale) / 2 - minY * scale;
    _controller.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04101B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF04101B),
        elevation: 0,
        title: const Text('Brain graph'),
        actions: [
          IconButton(onPressed: _manualRefresh, icon: const Icon(Icons.refresh_rounded)),
          IconButton(onPressed: _fitGraph, icon: const Icon(Icons.center_focus_strong_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _graph == null || _graph!.nodes.isEmpty
                  ? _emptyView()
                  : _graphView(),
    );
  }

  Widget _graphView() {
    final graph = _graph!;
    final layout = _computeLayout(graph.nodes);
    final clusters = layout.clusters.values.toList()
      ..sort((a, b) => b.nodeCount.compareTo(a.nodeCount));
    final stats = graph.stats;

    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: 0.16,
            maxScale: 4.8,
            boundaryMargin: const EdgeInsets.all(2400),
            child: SizedBox(
              width: 2800,
              height: 2100,
              child: CustomPaint(
                painter: _BrainBackdropPainter(layout: layout, selectedNodeId: _selected?.id),
                foregroundPainter: _GraphEdgePainter(
                  layout: layout,
                  edges: graph.connections,
                  selectedNodeId: _selected?.id,
                ),
                child: _GraphNodeLayer(
                  layout: layout,
                  selectedNodeId: _selected?.id,
                  onTapNode: (node) => setState(() => _selected = node),
                ),
              ),
            ),
          ),
        ),
        Positioned(left: 16, right: 16, top: 12, child: _topPanel(stats, clusters)),
        Positioned(
          right: 16,
          top: 116,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _legendOpen ? _legendCard() : _legendToggleButton(),
          ),
        ),
        if (_selected != null)
          Positioned(left: 16, right: 16, bottom: 16, child: _inspectorCard(_selected!)),
      ],
    );
  }

  Widget _topPanel(Map<String, dynamic> stats, List<_ClusterRegion> clusters) {
    final topClusters = clusters.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF081827).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.24), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _statChip('Nodes', '${stats['nodes'] ?? _graph?.nodes.length ?? 0}'),
              _statChip('Edges', '${_graph?.connections.length ?? 0}'),
              _statChip('Events', '${stats['events'] ?? _graph?.events.length ?? 0}'),
              _statChip('Clusters', '${stats['clusters'] ?? topClusters.length}'),
              if (_graph?.quotaSafeMode == true) _statChip('Quota', 'safe'),
              if (_graph?.limited == true) _statChip('Limited', 'yes'),
              if (_graph?.pass2Deferred == true) _statChip('Pass 2', 'deferred'),
              if (_selected != null) _statChip('Selected', _selected!.label),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: topClusters
                  .map((cluster) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _clusterChip(cluster),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _clusterChip(_ClusterRegion cluster) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cluster.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cluster.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: cluster.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            cluster.label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            '${cluster.nodeCount}',
            style: TextStyle(color: Colors.white.withOpacity(0.68), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _legendToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _legendOpen = true),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF09192C).withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info_outline_rounded, size: 18),
              SizedBox(width: 8),
              Text('Graph guide', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendCard() {
    Widget item(Color color, String title, String subtitle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF09192C).withOpacity(0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Graph guide', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5))),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                onPressed: () => setState(() => _legendOpen = false),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          item(const Color(0xFF60A5FA), 'Cluster aura', 'Soft background region showing semantic home, not a hard box.'),
          item(const Color(0xFF9F7AEA), 'Project / system node', 'Important project-style concepts get stronger visual weight.'),
          item(const Color(0xFF38BDF8), 'Skill / learning node', 'Blue accents show learning and capability topics.'),
          item(const Color(0xFFF59E0B), 'Goal / drive node', 'Warm nodes show motivation, goals, and forward drive.'),
          item(const Color(0xFF94A3B8), 'Historical / weak edge', 'Fainter edge styles mean context/fallback or lower current priority.'),
        ],
      ),
    );
  }

  Widget _inspectorCard(MemoryNodeVm node) {
    final style = _nodeStyle(node);
    final graph = _graph;
    final nodeSlices = graph == null
        ? const <MemorySliceVm>[]
        : graph.recentSlices.where((slice) => _sliceBelongsToNode(slice, node)).take(4).toList(growable: false);
    final nodeEvents = graph == null
        ? const <MemoryEventVm>[]
        : graph.events.where((event) => _eventBelongsToNode(event, node)).take(4).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF09192C).withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(node.label, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              ),
              IconButton(onPressed: () => setState(() => _selected = null), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Role', _normalizeRole(node.group)),
              _pill('Cluster', node.cluster),
              _pill('Heat', '${node.heat}'),
              _pill('Mentions', '${node.count}'),
              _pill('Events', '${node.eventCount}'),
              _pill('Slices', '${node.sliceCount}'),
              _pill('Updates', '${node.meaningfulUpdateCount}'),
              _pill('State', node.currentState),
            ],
          ),
          const SizedBox(height: 14),
          _meter('Heat', node.heat / 100.0, style.accent),
          const SizedBox(height: 10),
          _meter('Activity', ((node.count.clamp(1, 12)) / 12.0).toDouble(), style.secondary),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _truthBadge('Node', Icons.hub_rounded, const Color(0xFFA78BFA)),
              if (node.sliceCount > 0) _truthBadge('Slice ×${node.sliceCount}', Icons.notes_rounded, const Color(0xFF38BDF8)),
              if (node.eventCount > 0) _truthBadge('Event ×${node.eventCount}', Icons.bolt_rounded, const Color(0xFF34D399)),
              if ((node.lifecycleAction ?? '').trim().isNotEmpty)
                _truthBadge(node.lifecycleAction!, Icons.flag_rounded, const Color(0xFFF59E0B)),
            ],
          ),
          if ((node.latestSliceSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _miniSection('Latest slice', node.latestSliceSummary!),
          ],
          if (nodeSlices.isNotEmpty) ...[
            const SizedBox(height: 10),
            _sliceListSection('Recent slices', nodeSlices),
          ],
          if ((node.lastEventSummary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _miniSection('Latest event', node.lastEventSummary!),
          ],
          if (nodeEvents.isNotEmpty) ...[
            const SizedBox(height: 10),
            _eventListSection('Recent events', nodeEvents),
          ],
          if ((node.info ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(node.info!, style: TextStyle(color: Colors.white.withOpacity(0.78), height: 1.5)),
          ],
        ],
      ),
    );
  }

  bool _sliceBelongsToNode(MemorySliceVm slice, MemoryNodeVm node) {
    final sliceNodeId = slice.nodeId.trim();
    final sliceLabel = slice.nodeLabel.trim().toLowerCase();
    return sliceNodeId == node.id || (sliceLabel.isNotEmpty && sliceLabel == node.label.trim().toLowerCase());
  }

  bool _eventBelongsToNode(MemoryEventVm event, MemoryNodeVm node) {
    final eventNodeId = event.primaryNodeId.trim();
    final eventLabel = event.primaryNodeLabel.trim().toLowerCase();
    return eventNodeId == node.id || (eventLabel.isNotEmpty && eventLabel == node.label.trim().toLowerCase());
  }

  Widget _truthBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.5, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _sliceListSection(String title, List<MemorySliceVm> slices) {
    return _miniListSection(
      title,
      slices.map((slice) {
        final text = slice.narrativeSummary.trim().isNotEmpty ? slice.narrativeSummary : slice.summaryDraft;
        final kind = slice.kind.trim().isEmpty ? 'slice' : slice.kind.trim();
        return _miniListItem(kind, text);
      }).toList(growable: false),
    );
  }

  Widget _eventListSection(String title, List<MemoryEventVm> events) {
    return _miniListSection(
      title,
      events.map((event) {
        final label = event.lifecycleAction.trim().isNotEmpty
            ? event.lifecycleAction
            : (event.eventType.trim().isNotEmpty ? event.eventType : 'event');
        final text = event.summary.trim().isNotEmpty ? event.summary : event.primaryNodeLabel;
        return _miniListItem(label, text);
      }).toList(growable: false),
    );
  }

  Widget _miniListSection(String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.66), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _miniListItem(String label, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Color(0xFF38BDF8), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white.withOpacity(0.82), height: 1.34),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: body.trim().isEmpty ? '—' : body.trim()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSection(String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.66), fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: Colors.white.withOpacity(0.82), height: 1.42)),
        ],
      ),
    );
  }

  Widget _meter(String label, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.68), fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            backgroundColor: Colors.white.withOpacity(0.07),
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: const Color(0xFF07182B), borderRadius: BorderRadius.circular(26)),
        child: const Text(
          'No graph nodes yet.\nStart chatting and let the learning engine create durable nodes first.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, height: 1.5),
        ),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFF07182B), borderRadius: BorderRadius.circular(24)),
        child: SelectableText(_error!, style: const TextStyle(fontSize: 15, height: 1.45)),
      ),
    );
  }
}

class _GraphNodeLayer extends StatelessWidget {
  final _GraphLayout layout;
  final String? selectedNodeId;
  final ValueChanged<MemoryNodeVm> onTapNode;

  const _GraphNodeLayer({
    required this.layout,
    required this.selectedNodeId,
    required this.onTapNode,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final node in layout.nodes)
          Positioned(
            left: layout.positions[node.id]!.dx - (_nodeRenderWidth(node) / 2),
            top: layout.positions[node.id]!.dy - (_nodeRenderHeight(node) / 2),
            child: GestureDetector(
              onTap: () => onTapNode(node),
              child: _NodeChip(node: node, selected: selectedNodeId == node.id),
            ),
          ),
      ],
    );
  }
}

class _GraphLayout {
  final List<MemoryNodeVm> nodes;
  final Map<String, Offset> positions;
  final Map<String, _ClusterRegion> clusters;

  const _GraphLayout({required this.nodes, required this.positions, required this.clusters});
}

_GraphLayout _computeLayout(List<MemoryNodeVm> nodes) {
  final safeNodes = nodes.toList();
  final positions = <String, Offset>{};
  final clusterMap = <String, _ClusterRegion>{};
  MemoryNodeVm? root;
  for (final node in safeNodes) {
    if (node.isRoot) {
      root = node;
      break;
    }
  }

  const rootCenter = Offset(1400, 1220);
  if (root != null) positions[root.id] = rootCenter;

  final clusterBuckets = <String, List<MemoryNodeVm>>{};
  for (final node in safeNodes.where((n) => !n.isRoot)) {
    final clusterId = node.cluster.trim().isEmpty ? 'general' : node.cluster.trim();
    clusterBuckets.putIfAbsent(clusterId, () => []).add(node);
  }

  final clusterEntries = clusterBuckets.entries.toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  final total = math.max(clusterEntries.length, 1);
  final singleCluster = total == 1;
  final ringX = singleCluster ? 0.0 : 880.0;
  final ringY = singleCluster ? 0.0 : 610.0;

  for (var i = 0; i < clusterEntries.length; i++) {
    final entry = clusterEntries[i];
    final angle = total == 1 ? -math.pi / 2 : (math.pi * 2 / total) * i - math.pi / 2;
    final center = singleCluster
        ? const Offset(1400, 820)
        : Offset(rootCenter.dx + math.cos(angle) * ringX, rootCenter.dy - 120 + math.sin(angle) * ringY);
    final regionColor = _clusterColor(entry.key);
    final baseRadius = singleCluster ? 360.0 : 250.0;
    final radius = baseRadius + (entry.value.length.clamp(0, 14) * 18.0);
    final region = _ClusterRegion(
      id: entry.key,
      label: entry.key,
      color: regionColor,
      center: center,
      radius: radius,
      nodeCount: entry.value.length,
    );
    clusterMap[entry.key] = region;

    final roleBuckets = <String, List<MemoryNodeVm>>{};
    for (final node in entry.value) {
      roleBuckets.putIfAbsent(_normalizeRole(node.group), () => []).add(node);
    }
    final roleEntries = roleBuckets.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final roleTotal = math.max(roleEntries.length, 1);
    final roleOrbit = singleCluster ? 185.0 : 150.0;

    for (var r = 0; r < roleEntries.length; r++) {
      final roleEntry = roleEntries[r];
      final roleAngle = roleTotal == 1 ? -math.pi / 2 : (math.pi * 2 / roleTotal) * r - math.pi / 2;
      final pocketCenter = roleTotal == 1
          ? center
          : Offset(center.dx + math.cos(roleAngle) * roleOrbit, center.dy + math.sin(roleAngle) * (roleOrbit - 18));
      final items = roleEntry.value;
      final count = math.max(items.length, 1);
      for (var n = 0; n < items.length; n++) {
        final node = items[n];
        final ringIndex = n ~/ 4;
        final localRing = 78.0 + ringIndex * 76.0;
        final localAngle = count == 1
            ? (-math.pi / 2) + (r.isEven ? 0.18 : -0.18)
            : (math.pi * 2 / count) * n + (r.isEven ? 0.24 : -0.22);
        positions[node.id] = Offset(
          pocketCenter.dx + math.cos(localAngle) * localRing,
          pocketCenter.dy + math.sin(localAngle) * (localRing * 0.92),
        );
      }
    }
  }

  _relaxPositions(safeNodes, positions, root?.id);
  return _GraphLayout(nodes: safeNodes, positions: positions, clusters: clusterMap);
}

void _relaxPositions(List<MemoryNodeVm> nodes, Map<String, Offset> positions, String? rootId) {
  for (var iteration = 0; iteration < 120; iteration++) {
    var moved = false;
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      if (!positions.containsKey(a.id)) continue;
      for (var j = i + 1; j < nodes.length; j++) {
        final b = nodes[j];
        if (!positions.containsKey(b.id)) continue;
        final aPos = positions[a.id]!;
        final bPos = positions[b.id]!;
        final delta = bPos - aPos;
        final distance = delta.distance;
        final minDistance = (_nodeRenderWidth(a) + _nodeRenderWidth(b)) * 0.34;
        if (distance <= 0 || distance >= minDistance) continue;
        final push = (minDistance - distance) / 2;
        final direction = delta / (distance == 0 ? 1.0 : distance.toDouble());
        final aShift = Offset(-direction.dx * push, -direction.dy * push);
        final bShift = Offset(direction.dx * push, direction.dy * push);
        if (a.id != rootId) positions[a.id] = aPos + aShift;
        if (b.id != rootId) positions[b.id] = bPos + bShift;
        moved = true;
      }
    }
    if (!moved) break;
  }
}

String _normalizeRole(String raw) {
  final value = raw.trim().toLowerCase();
  switch (value) {
    case 'identity':
    case 'role':
      return 'identity';
    case 'project':
      return 'project';
    case 'goal':
      return 'goal';
    case 'skill':
      return 'skill';
    case 'habit':
      return 'habit';
    case 'preference':
      return 'preference';
    case 'reserve':
    case 'personal':
      return 'reserve';
    default:
      return 'interest';
  }
}

Color _clusterColor(String raw) {
  final value = raw.trim().toLowerCase();
  if (value.contains('sport')) return const Color(0xFF38BDF8);
  if (value.contains('health')) return const Color(0xFFFB7185);
  if (value.contains('software') || value.contains('work') || value.contains('project')) return const Color(0xFF8B5CF6);
  if (value.contains('learn')) return const Color(0xFF14B8A6);
  if (value.contains('finance')) return const Color(0xFFF59E0B);
  if (value.contains('relationship')) return const Color(0xFFF472B6);
  return const Color(0xFF60A5FA);
}

double _nodeRenderSize(MemoryNodeVm node) => node.isRoot ? 126.0 : _nodeRenderHeight(node);

double _nodeRenderWidth(MemoryNodeVm node) {
  if (node.isRoot) return 132.0;
  final labelFactor = (node.label.trim().length * 4.8).clamp(0.0, 72.0);
  final base = 94.0 + labelFactor + (node.info?.isNotEmpty == true ? 10.0 : 0.0);
  return base.clamp(96.0, 172.0).toDouble();
}

double _nodeRenderHeight(MemoryNodeVm node) {
  if (node.isRoot) return 132.0;
  return (node.label.length > 26 ? 78.0 : 68.0).toDouble();
}

class _NodeStyle {
  final Color accent;
  final Color secondary;
  final List<Color> fill;
  final Color text;

  const _NodeStyle({required this.accent, required this.secondary, required this.fill, required this.text});
}

_NodeStyle _nodeStyle(MemoryNodeVm node) {
  if (node.isRoot) {
    return const _NodeStyle(
      accent: Color(0xFFF8FAFC),
      secondary: Color(0xFFCBD5E1),
      fill: [Color(0xFF0F172A), Color(0xFF1E293B)],
      text: Colors.white,
    );
  }
  switch (_normalizeRole(node.group)) {
    case 'project':
      return const _NodeStyle(
        accent: Color(0xFFA78BFA),
        secondary: Color(0xFF7C3AED),
        fill: [Color(0xFF251A4D), Color(0xFF161A38)],
        text: Colors.white,
      );
    case 'skill':
      return const _NodeStyle(
        accent: Color(0xFF38BDF8),
        secondary: Color(0xFF0EA5E9),
        fill: [Color(0xFF08283B), Color(0xFF0A1726)],
        text: Colors.white,
      );
    case 'goal':
      return const _NodeStyle(
        accent: Color(0xFFFBBF24),
        secondary: Color(0xFFF59E0B),
        fill: [Color(0xFF3B2A0B), Color(0xFF211707)],
        text: Colors.white,
      );
    case 'habit':
      return const _NodeStyle(
        accent: Color(0xFF2DD4BF),
        secondary: Color(0xFF14B8A6),
        fill: [Color(0xFF0B3130), Color(0xFF0B1B1D)],
        text: Colors.white,
      );
    case 'preference':
      return const _NodeStyle(
        accent: Color(0xFFF472B6),
        secondary: Color(0xFFEC4899),
        fill: [Color(0xFF3B1227), Color(0xFF1F0E1A)],
        text: Colors.white,
      );
    case 'identity':
      return const _NodeStyle(
        accent: Color(0xFFE2E8F0),
        secondary: Color(0xFF94A3B8),
        fill: [Color(0xFF111827), Color(0xFF0A101A)],
        text: Colors.white,
      );
    case 'reserve':
      return const _NodeStyle(
        accent: Color(0xFFC4B5FD),
        secondary: Color(0xFFA78BFA),
        fill: [Color(0xFF262640), Color(0xFF141722)],
        text: Colors.white,
      );
    default:
      return const _NodeStyle(
        accent: Color(0xFF93C5FD),
        secondary: Color(0xFF60A5FA),
        fill: [Color(0xFF132335), Color(0xFF0B1320)],
        text: Colors.white,
      );
  }
}

class _NodeChip extends StatelessWidget {
  final MemoryNodeVm node;
  final bool selected;

  const _NodeChip({required this.node, required this.selected});

  @override
  Widget build(BuildContext context) {
    final style = _nodeStyle(node);
    final width = _nodeRenderWidth(node);
    final height = _nodeRenderHeight(node);
    final tag = node.isRoot ? 'core' : _normalizeRole(node.group);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width + 8,
      height: height + 8,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(node.isRoot ? 999 : 24),
        boxShadow: [
          BoxShadow(
            color: style.accent.withOpacity(selected ? 0.26 : 0.12),
            blurRadius: selected ? 24 : 14,
            spreadRadius: selected ? 1.4 : 0.1,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: style.fill),
          borderRadius: BorderRadius.circular(node.isRoot ? 999 : 22),
          border: Border.all(color: style.accent.withOpacity(selected ? 0.95 : 0.42), width: selected ? 2.1 : 1.1),
        ),
        child: Stack(
          children: [
            if (!node.isRoot)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: style.accent.withOpacity(0.96),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                ),
              ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, node.isRoot ? 12 : 12, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      node.label,
                      textAlign: TextAlign.center,
                      maxLines: node.isRoot ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: node.isRoot ? 13.8 : 12.0,
                        fontWeight: FontWeight.w900,
                        color: style.text,
                        height: 1.14,
                      ),
                    ),
                    if (!node.isRoot) ...[
                      const SizedBox(height: 7),
                      _miniBadge(tag, style.secondary, maxWidth: 86),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color, {double maxWidth = 52}) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.34)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color.withOpacity(0.96), fontWeight: FontWeight.w800, fontSize: 10.2),
        ),
      ),
    );
  }
}

class _ClusterRegion {
  final String id;
  final String label;
  final Color color;
  final Offset center;
  final double radius;
  final int nodeCount;

  const _ClusterRegion({
    required this.id,
    required this.label,
    required this.color,
    required this.center,
    required this.radius,
    required this.nodeCount,
  });
}

class _BrainBackdropPainter extends CustomPainter {
  final _GraphLayout layout;
  final String? selectedNodeId;

  const _BrainBackdropPainter({required this.layout, required this.selectedNodeId});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF04101A), Color(0xFF08192A), Color(0xFF05111E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    const step = 120.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final cluster in layout.clusters.values) {
      final aura = Paint()
        ..shader = ui.Gradient.radial(
          cluster.center,
          cluster.radius,
          [cluster.color.withOpacity(0.18), cluster.color.withOpacity(0.06), Colors.transparent],
          const [0.0, 0.58, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
      canvas.drawCircle(cluster.center, cluster.radius, aura);

      final ring = Paint()
        ..color = cluster.color.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(cluster.center, cluster.radius * 0.84, ring);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: cluster.label,
          style: TextStyle(
            color: cluster.color.withOpacity(0.92),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(cluster.center.dx - labelPainter.width / 2, cluster.center.dy - cluster.radius - 18));
    }
  }

  @override
  bool shouldRepaint(covariant _BrainBackdropPainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.selectedNodeId != selectedNodeId;
  }
}

class _GraphEdgePainter extends CustomPainter {
  final _GraphLayout layout;
  final List<MemoryEdgeVm> edges;
  final String? selectedNodeId;

  const _GraphEdgePainter({
    required this.layout,
    required this.edges,
    required this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final from = layout.positions[edge.fromNodeId];
      final to = layout.positions[edge.toNodeId];
      if (from == null || to == null) continue;
      final style = _edgeStyle(edge.type);
      final selectedTouch = selectedNodeId != null && (edge.fromNodeId == selectedNodeId || edge.toNodeId == selectedNodeId);
      final paint = Paint()
        ..color = style.color.withOpacity(selectedTouch ? math.max(0.88, style.opacity) : style.opacity)
        ..strokeWidth = selectedTouch ? style.width + 0.8 : style.width
        ..style = PaintingStyle.stroke;
      final midpoint = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final curveLift = style.curveLift + (selectedTouch ? 10 : 0);
      final control = Offset(midpoint.dx, midpoint.dy - curveLift);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

      if (style.dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
      if (style.directional) _drawArrow(canvas, control, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) {
    return oldDelegate.layout != layout || oldDelegate.edges != edges || oldDelegate.selectedNodeId != selectedNodeId;
  }
}

class _EdgeStyle {
  final Color color;
  final double width;
  final double opacity;
  final double curveLift;
  final bool dashed;
  final bool directional;

  const _EdgeStyle({
    required this.color,
    required this.width,
    required this.opacity,
    required this.curveLift,
    required this.dashed,
    required this.directional,
  });
}

_EdgeStyle _edgeStyle(String rawType) {
  final type = rawType.trim().toLowerCase();
  switch (type) {
    case 'part_of':
      return const _EdgeStyle(color: Color(0xFFA78BFA), width: 2.4, opacity: 0.82, curveLift: 26, dashed: false, directional: true);
    case 'depends_on':
      return const _EdgeStyle(color: Color(0xFF38BDF8), width: 2.6, opacity: 0.84, curveLift: 24, dashed: false, directional: true);
    case 'uses':
      return const _EdgeStyle(color: Color(0xFF60A5FA), width: 2.2, opacity: 0.78, curveLift: 18, dashed: false, directional: true);
    case 'drives':
      return const _EdgeStyle(color: Color(0xFFF59E0B), width: 2.4, opacity: 0.82, curveLift: 32, dashed: false, directional: true);
    case 'supports':
      return const _EdgeStyle(color: Color(0xFF2DD4BF), width: 2.0, opacity: 0.74, curveLift: 18, dashed: false, directional: true);
    case 'improves':
      return const _EdgeStyle(color: Color(0xFF34D399), width: 1.9, opacity: 0.7, curveLift: 16, dashed: false, directional: true);
    case 'related_to':
    default:
      return const _EdgeStyle(color: Color(0xFF94A3B8), width: 1.5, opacity: 0.48, curveLift: 14, dashed: true, directional: false);
  }
}

void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
  final metrics = path.computeMetrics();
  for (final metric in metrics) {
    double distance = 0;
    const dash = 9.0;
    const gap = 6.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance += dash + gap;
    }
  }
}

void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
  final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
  const arrowSize = 8.0;
  final path = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(to.dx - arrowSize * math.cos(angle - math.pi / 6), to.dy - arrowSize * math.sin(angle - math.pi / 6))
    ..moveTo(to.dx, to.dy)
    ..lineTo(to.dx - arrowSize * math.cos(angle + math.pi / 6), to.dy - arrowSize * math.sin(angle + math.pi / 6));
  canvas.drawPath(path, paint);
}
