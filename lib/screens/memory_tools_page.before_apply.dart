import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/memory_session.dart';
import '../services/memory_status_cache.dart';
import 'memory_graph_page.dart';
import 'memory_preview_page.dart';

class MemoryToolsPage extends StatefulWidget {
  const MemoryToolsPage({super.key});

  @override
  State<MemoryToolsPage> createState() => _MemoryToolsPageState();
}

class _MemoryToolsPageState extends State<MemoryToolsPage> {
  static const Duration _pollInterval = Duration(seconds: 10);

  Timer? _timer;
  bool _loading = true;
  bool _autoRefresh = true;
  bool _showRaw = false;
  String? _error;
  Map<String, dynamic> _status = const <String, dynamic>{};
  Map<String, dynamic> _finalStatus = const <String, dynamic>{};
  final Set<String> _expandedLogIds = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
    _bindTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _bindTimer() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      _load(silent: true);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await MemorySession.ensureInitialized();
      final results = await Future.wait<dynamic>([
        MemorySession.debugStatus(),
        MemorySession.finalStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _status = Map<String, dynamic>.from(results[0] as Map);
        _finalStatus = Map<String, dynamic>.from(results[1] as Map);
        _error = null;
      });
      MemoryStatusCache.set(_status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> get _stats => _map(_status['stats']);
  Map<String, dynamic> get _memoryMeta => _map(_status['memoryMeta']);
  Map<String, dynamic> get _latestPipeline => _map(_status['latestPipeline']);
  Map<String, dynamic> get _clusterSummary => _map(_status['clusterSummary']);
  Map<String, dynamic> get _profile => _map(_status['profile']);

  List<Map<String, dynamic>> get _sessions => _list(_status['activeSessionPreview']);
  List<Map<String, dynamic>> get _candidatePreview => _list(_status['candidatePreview']);
  List<Map<String, dynamic>> get _eventsPreview => _list(_status['recentEventPreview']);
  List<Map<String, dynamic>> get _logs => _list(_status['recentLogs']);
  List<Map<String, dynamic>> get _nodesPreview => _list(_finalStatus['nodesPreview']);
  List<Map<String, dynamic>> get _clusterPreview => _list(_clusterSummary['preview']);

  static Map<String, dynamic> _map(dynamic raw) => raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};

  static List<Map<String, dynamic>> _list(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  int _num(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _string(dynamic value, [String fallback = '']) {
    final text = (value ?? fallback).toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _relativeTime(dynamic value) {
    final ts = _num(value, 0);
    if (ts <= 0) return '—';
    final now = DateTime.now();
    final time = DateTime.fromMillisecondsSinceEpoch(ts);
    final diff = now.difference(time);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(time);
  }

  String _absoluteTime(dynamic value) {
    final ts = _num(value, 0);
    if (ts <= 0) return '—';
    return DateFormat('dd MMM yyyy · hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  String _triggerLabel(String raw) {
    switch (raw.trim()) {
      case 'high_signal_priority':
        return 'High signal detected';
      case 'fresh_session_first_meaningful':
        return 'Fresh session first message';
      case 'initial_meaningful_slice':
        return 'Initial meaningful content';
      case 'slice_overflow':
        return 'Slice size overflow';
      case 'idle_pause':
        return 'Idle pause trigger';
      case 'long_active_chat':
        return 'Long active chat';
      case 'minimum_slice_guard':
        return 'Below minimum — deferred';
      case 'awaiting_trigger':
        return 'Awaiting trigger';
      case 'checkpoint_no_new_slice':
        return 'No new messages since last extraction';
      case 'manual_flush':
        return 'Manual flush';
      default:
        return raw.trim().isEmpty ? 'Idle' : raw.replaceAll('_', ' ');
    }
  }

  String _skipReasonLabel(String raw) {
    switch (raw.trim()) {
      case 'trivial_text':
        return 'Trivial message';
      case 'suppressed':
        return 'Label in suppression list';
      case 'minimum_slice_guard':
        return 'Below minimum slice size';
      case 'awaiting_trigger':
        return 'Waiting for trigger condition';
      default:
        return raw.trim().isEmpty ? 'Skipped' : raw.replaceAll('_', ' ');
    }
  }

  String _connectionStateLabel(String raw) {
    switch (raw.trim()) {
      case 'created':
        return 'Created';
      case 'reinforced':
        return 'Reinforced';
      case 'skip:from_unresolved':
        return 'Source node not found';
      case 'skip:to_unresolved':
        return 'Target node not found';
      case 'skip:both_unresolved':
        return 'Neither node found';
      case 'skip:self_edge':
        return 'Self-referential edge blocked';
      case 'skip:missing_label':
        return 'Empty label';
      case 'skip:to_candidate_not_yet_durable':
        return 'Target is still a candidate';
      case 'skip:from_candidate_not_yet_durable':
        return 'Source is still a candidate';
      case 'skip:both_candidate_not_yet_durable':
        return 'Both endpoints are still candidates';
      case 'skip:from_candidate_to_unresolved':
        return 'Source is a candidate, target unknown';
      case 'skip:from_unresolved_to_candidate':
        return 'Source unknown, target is a candidate';
      default:
        return raw.trim().isEmpty ? 'Unknown' : raw.replaceAll('_', ' ');
    }
  }

  Color _statusColor(String rawStatus) {
    final status = rawStatus.toLowerCase();
    if (status.contains('processed') || status.contains('created')) return const Color(0xFF34D399);
    if (status.contains('deferred') || status.contains('awaiting') || status.contains('minimum')) {
      return const Color(0xFFFBBF24);
    }
    if (status.contains('failed') || status.contains('error')) return const Color(0xFFFB7185);
    return const Color(0xFF60A5FA);
  }

  Color _evidenceRoleColor(String role) {
    switch (role.trim()) {
      case 'primary_proof':
        return const Color(0xFFFBBF24);
      case 'status_update':
        return const Color(0xFF34D399);
      case 'time_anchor':
        return const Color(0xFF60A5FA);
      case 'supporting_proof':
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Color _freshnessColor() {
    final lastProcessedAt = _num(_memoryMeta['memoryLastProcessedAt'], 0);
    if (lastProcessedAt <= 0) return const Color(0xFFFB7185);
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastProcessedAt));
    if (diff.inMinutes < 5) return const Color(0xFF34D399);
    if (diff.inHours < 1) return const Color(0xFFFBBF24);
    return const Color(0xFFFB7185);
  }

  String _jsonPretty(dynamic data) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  List<Map<String, dynamic>> _connectionsForLog(Map<String, dynamic> log) {
    return _list(_map(log['connection'])['createdOrUpdated']);
  }

  List<Map<String, dynamic>> _eventsForLog(Map<String, dynamic> log) {
    final items = _list(log['eventList']);
    if (items.isNotEmpty) return items;
    final single = _map(log['event']);
    return single.isEmpty ? const <Map<String, dynamic>>[] : <Map<String, dynamic>>[single];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory engine monitor'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryPreviewPage())),
            icon: const Icon(Icons.remove_red_eye_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryGraphPage())),
            icon: const Icon(Icons.hub_rounded),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF07111B), Color(0xFF0B1623), Color(0xFF07101A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: SelectableText(_error!, style: const TextStyle(height: 1.5)),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _heroCard(),
                          const SizedBox(height: 14),
                          _actionBar(),
                          const SizedBox(height: 14),
                          _metricGrid(),
                          const SizedBox(height: 14),
                          _sectionCard('Latest extraction', child: _latestPipelineSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Active sessions', child: _activeSessionsSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Recent pipeline logs', child: _recentLogsSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Cluster distribution', child: _clusterSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Candidates', child: _candidateSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Durable nodes', child: _nodeSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Recent events', child: _eventSection()),
                          const SizedBox(height: 14),
                          _sectionCard('Connections overview', child: _connectionPreviewSection()),
                          const SizedBox(height: 14),
                          _rawToggle(),
                          if (_showRaw) ...[
                            const SizedBox(height: 12),
                            _sectionCard('Raw debug status', child: _jsonBox(_status)),
                            const SizedBox(height: 12),
                            _sectionCard('Raw final status', child: _jsonBox(_finalStatus)),
                          ],
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    final latestAt = _relativeTime(_memoryMeta['memoryLastProcessedAt']);
    final activeMode = _string(_status['activeMode'], MemorySession.activeMode);
    final freshness = _freshnessColor();
    final summary = _string(_profile['compressedPrompt']);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.14), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.memory_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Memory Engine Monitor', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              ),
              Container(width: 12, height: 12, decoration: BoxDecoration(color: freshness, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(latestAt, style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallPill('UID', _string(_status['uid'], '—')),
              _smallPill('Mode', activeMode),
              _smallPill('Version', _string(_memoryMeta['memoryVersion'], '—')),
              _smallPill('Schema', '${_memoryMeta['memorySchemaVersion'] ?? '—'}'),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(summary, style: TextStyle(color: Colors.white.withOpacity(0.74), height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Refresh live data'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() => _autoRefresh = !_autoRefresh);
              _bindTimer();
            },
            icon: Icon(_autoRefresh ? Icons.timer_rounded : Icons.timer_off_rounded),
            label: Text(_autoRefresh ? 'Auto refresh on' : 'Auto refresh off'),
          ),
        ),
      ],
    );
  }

  Widget _metricGrid() {
    final cards = [
      _MetricData('Nodes', '${_stats['nodes'] ?? 0}', const Color(0xFFA78BFA)),
      _MetricData('Connections', '${_stats['connections'] ?? 0}', const Color(0xFF38BDF8)),
      _MetricData('Events', '${_stats['events'] ?? 0}', const Color(0xFF34D399)),
      _MetricData('Candidates', '${_stats['candidates'] ?? 0}', const Color(0xFFFBBF24)),
      _MetricData('Sessions', '${_stats['sessions'] ?? 0}', const Color(0xFF60A5FA)),
      _MetricData('Logs', '${_stats['debugLogs'] ?? 0}', const Color(0xFFF472B6)),
      _MetricData('Clusters', '${_stats['clusters'] ?? 0}', const Color(0xFF2DD4BF)),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 154,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _panelBox(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: card.color, shape: BoxShape.circle)),
                    const SizedBox(height: 10),
                    Text(card.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(card.label, style: TextStyle(color: Colors.white.withOpacity(0.68))),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _latestPipelineSection() {
    final status = _string(_latestPipeline['extractionStatus'], _string(_latestPipeline['status'], 'idle'));
    final trigger = _triggerLabel(_string(_latestPipeline['triggerReason']));
    final processedAt = _relativeTime(_latestPipeline['processedAt'] ?? _latestPipeline['lastRunAt']);
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(status.toLowerCase().contains('processed') ? Icons.check_circle_rounded : Icons.schedule_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.isEmpty ? 'Idle' : status[0].toUpperCase() + status.substring(1),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              Text(processedAt, style: TextStyle(color: Colors.white.withOpacity(0.68), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(trigger, style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallPill('Candidates', '${_latestPipeline['candidateCount'] ?? _latestPipeline['candidateCreated'] ?? 0}'),
              _smallPill('Reinforced', '${_latestPipeline['reinforceCount'] ?? _latestPipeline['reinforced'] ?? 0}'),
              _smallPill('Events', '${_latestPipeline['createdEventCount'] ?? _latestPipeline['eventCount'] ?? 0}'),
              _smallPill('Connections', '${_latestPipeline['connectionCount'] ?? 0}'),
              if (_latestPipeline['highSignal'] == true) _smallPill('Signal', 'high', accent: const Color(0xFF34D399)),
              if (_num(_latestPipeline['connectionSkipped']) > 0)
                _smallPill('Conn skipped', '${_latestPipeline['connectionSkipped']}', accent: const Color(0xFFFB7185)),
              if (_num(_latestPipeline['skippedCandidates']) > 0)
                _smallPill('Cand skipped', '${_latestPipeline['skippedCandidates']}', accent: const Color(0xFFFBBF24)),
            ],
          ),
          if (_string(_latestPipeline['extractionError']).isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFB7185).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFB7185).withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFFB7185)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      _string(_latestPipeline['extractionError']),
                      style: TextStyle(color: Colors.white.withOpacity(0.88), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_map(_latestPipeline['primaryEvent']).isNotEmpty) ...[
            const SizedBox(height: 12),
            Builder(builder: (_) {
              final primary = _map(_latestPipeline['primaryEvent']);
              final evidence = _list(primary['evidencePreview']);
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF34D399).withOpacity(0.26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF34D399)),
                        const SizedBox(width: 8),
                        const Text('Primary event', style: TextStyle(fontWeight: FontWeight.w900)),
                        const Spacer(),
                        if (_num(primary['evidenceCount']) > 0)
                          Text('${primary['evidenceCount']} evidence',
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_string(primary['summary'], 'Event recorded'),
                        style: const TextStyle(fontWeight: FontWeight.w800, height: 1.4)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_string(primary['lifecycleAction']).isNotEmpty)
                          _smallPill('Action', _string(primary['lifecycleAction']), accent: const Color(0xFF34D399)),
                        if (_string(primary['eventType']).isNotEmpty)
                          _smallPill('Type', _string(primary['eventType'])),
                        if (_string(primary['status']).isNotEmpty)
                          _smallPill('Status', _string(primary['status'])),
                      ],
                    ),
                    if (evidence.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...evidence.take(2).map((item) {
                        final snippet = _string(item['snippet']);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• $snippet',
                              style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.4)),
                        );
                      }),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _activeSessionsSection() {
    if (_sessions.isEmpty) {
      return _emptyLabel('No active sessions right now.');
    }
    return Column(
      children: _sessions
          .map(
            (session) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: _innerCardBox(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_string(session['id'], 'session'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      ),
                      _chipText(_string(session['sourceTag'], 'chat')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _smallPill('Turns', '${session['turnCount'] ?? 0}'),
                      _smallPill('Messages', '${session['messageCount'] ?? 0}'),
                      _smallPill('Last activity', _relativeTime(session['lastActivityAt'])),
                      _smallPill('Last extraction', _triggerLabel(_string(session['lastExtractionReason'], 'idle'))),
                    ],
                  ),
                  if (_num(session['pendingSliceMessageCount']) > 0 || _num(session['pendingSliceCharCount']) > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.22)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pending (not yet extracted)', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _smallPill('Messages', '${session['pendingSliceMessageCount'] ?? 0}', accent: const Color(0xFFFBBF24)),
                              _smallPill('Chars', '${session['pendingSliceCharCount'] ?? 0}', accent: const Color(0xFFFBBF24)),
                              _smallPill('Reason', _triggerLabel(_string(session['pendingTriggerReason'], 'awaiting_trigger')), accent: const Color(0xFFFBBF24)),
                              _smallPill('Since', _relativeTime(session['pendingSinceAt']), accent: const Color(0xFFFBBF24)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (session['countedTopicKeys'] is List && (session['countedTopicKeys'] as List).isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _labelRow('Topics', ((session['countedTopicKeys'] as List?) ?? const <dynamic>[]).join(', ')),
                  ],
                  if (_string(session['lastEventId']).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _labelRow('Last event', _string(session['lastEventId'])),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _recentLogsSection() {
    if (_logs.isEmpty) {
      return _emptyLabel('No pipeline activity yet. Send a meaningful message to trigger extraction.');
    }
    return Column(
      children: _logs.map(_logCard).toList(),
    );
  }

  Widget _logCard(Map<String, dynamic> log) {
    final id = _string(log['id'], UniqueKey().toString());
    final expanded = _expandedLogIds.contains(id);
    final trigger = _map(log['trigger']);
    final extraction = _map(log['extraction']);
    final promotion = _map(log['promotion']);
    final structure = _map(log['structure']);
    final counts = _map(log['counts']);
    final connections = _connectionsForLog(log);
    final events = _eventsForLog(log);
    final status = _string(extraction['status'], 'observed');
    final createdAt = _relativeTime(log['createdAt']);
    final summaryLine = '${counts['candidateCount'] ?? 0} candidate · ${counts['createdEventCount'] ?? 0} event · ${connections.length} connection';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _innerCardBox(),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey(id),
          initiallyExpanded: expanded,
          onExpansionChanged: (value) {
            setState(() {
              if (value) {
                _expandedLogIds.add(id);
              } else {
                _expandedLogIds.remove(id);
              }
            });
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(_triggerLabel(_string(trigger['reason'], 'idle')), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('$createdAt · $summaryLine', style: TextStyle(color: Colors.white.withOpacity(0.68))),
          ),
          children: [
            _stageBlock(
              icon: Icons.ads_click_rounded,
              title: 'Trigger',
              accent: const Color(0xFF60A5FA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_triggerLabel(_string(trigger['reason'], 'idle'))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (trigger['highSignal'] == true) _smallPill('Signal', 'high', accent: const Color(0xFF34D399)),
                      if (trigger['manual'] == true) _smallPill('Manual', 'true', accent: const Color(0xFFFBBF24)),
                      ..._metricPills(_map(trigger['metrics'])),
                    ],
                  ),
                ],
              ),
            ),
            _stageBlock(
              icon: Icons.inventory_2_rounded,
              title: 'Packet',
              accent: const Color(0xFF38BDF8),
              child: _monospaceBox(_string(log['packetPreview'], 'No packet preview.')),
            ),
            _stageBlock(
              icon: Icons.psychology_alt_rounded,
              title: 'Extraction',
              accent: _statusColor(status),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _smallPill('Status', status, accent: _statusColor(status)),
                  const SizedBox(height: 10),
                  _listGroup('New candidates', _list(extraction['candidates']).map((candidate) {
                    final label = _string(candidate['label']);
                    final role = _string(candidate['roleGuess']);
                    final strength = _string(candidate['strength']);
                    final action = _string(candidate['action']);
                    return '$label  [$role, $strength${action.isNotEmpty ? ', event: $action' : ''}]';
                  }).toList()),
                  const SizedBox(height: 10),
                  _listGroup('Reinforce labels', ((extraction['reinforceLabels'] as List?) ?? const <dynamic>[]).map((e) => e.toString()).toList()),
                  const SizedBox(height: 10),
                  _listGroup('Relation hints', _list(extraction['relationHints']).map((rel) {
                    return '${_string(rel['from'])} --${_string(rel['type'], 'related_to')}--> ${_string(rel['to'])}';
                  }).toList()),
                ],
              ),
            ),
            _stageBlock(
              icon: Icons.trending_up_rounded,
              title: 'Promotion',
              accent: const Color(0xFFA78BFA),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _listGroup('Promoted to nodes', _list(promotion['candidatePromoted']).map((node) {
                    return '${_string(node['label'])}  [${_string(node['group'])}${_string(node['currentState']).isNotEmpty ? ', state=${_string(node['currentState'])}' : ''}]';
                  }).toList()),
                  const SizedBox(height: 10),
                  _listGroup('Reinforced existing', _list(promotion['reinforcedNodes']).map((node) {
                    return '${_string(node['label'])}  [${_string(node['group'])}]';
                  }).toList()),
                  const SizedBox(height: 10),
                  _listGroup('New weak candidates', _list(promotion['candidateCreated']).map((candidate) {
                    return '${_string(candidate['label'])}  [${_string(candidate['groupGuess'])}]';
                  }).toList()),
                  const SizedBox(height: 10),
                  _listGroup('Skipped', _list(promotion['skipped']).map((skip) {
                    return '${_string(skip['label'])}  →  ${_skipReasonLabel(_string(skip['reason']))}';
                  }).toList()),
                ],
              ),
            ),
            _stageBlock(
              icon: Icons.event_note_rounded,
              title: 'Events',
              accent: const Color(0xFF34D399),
              child: events.isEmpty
                  ? _emptyLabel('No events this turn.', compact: true)
                  : Column(
                      children: events.map((event) {
                        final evidence = _list(event['evidencePreview']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_string(event['summary'], 'Event'), style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _smallPill('Type', _string(event['eventType'], 'event')),
                                  if (_string(event['lifecycleAction']).isNotEmpty) _smallPill('Action', _string(event['lifecycleAction'])),
                                  _smallPill('Status', _string(event['status'], 'recorded')),
                                  if (_string(event['importanceClass']).isNotEmpty) _smallPill('Importance', _string(event['importanceClass'])),
                                ],
                              ),
                              if (evidence.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Evidence', style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                ...evidence.take(3).map((item) {
                                  final snippet = _string(item['snippet'], 'proof').trim();
                                  final role = _string(item['role']);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (role.isNotEmpty) ...[
                                          Container(
                                            margin: const EdgeInsets.only(top: 2, right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _evidenceRoleColor(role).withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: _evidenceRoleColor(role).withOpacity(0.35)),
                                            ),
                                            child: Text(role, style: TextStyle(color: _evidenceRoleColor(role), fontSize: 9.6, fontWeight: FontWeight.w900)),
                                          ),
                                        ] else
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2, right: 8),
                                            child: Text('•', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                                          ),
                                        Expanded(
                                          child: Text(snippet, style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.35)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _stageBlock(
              icon: Icons.hub_rounded,
              title: 'Connections',
              accent: const Color(0xFF38BDF8),
              child: connections.isEmpty
                  ? _emptyLabel('No connection activity this turn.', compact: true)
                  : Column(
                      children: connections.map((conn) {
                        final state = _string(conn['state'], _string(conn['type']));
                        final created = state == 'created' || state == 'reinforced';
                        final color = created ? const Color(0xFF34D399) : (state.startsWith('skip:') ? const Color(0xFFFB7185) : const Color(0xFFFBBF24));
                        final relationType = _string(conn['type'], 'related_to');
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.18)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(created ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: color),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${_string(conn['from'])} --$relationType--> ${_string(conn['to'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 4),
                                    Text(_connectionStateLabel(state), style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.3)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (_list(structure['placedNodes']).isNotEmpty)
              _stageBlock(
                icon: Icons.account_tree_rounded,
                title: 'Structure',
                accent: const Color(0xFFF59E0B),
                child: _listGroup('Placed nodes', _list(structure['placedNodes']).map((item) {
                  return '${_string(item['label'])} placed under ${_string(item['parentId'], 'root')}  (cluster: ${_string(item['clusterId'], 'general')})';
                }).toList()),
              ),
            const SizedBox(height: 8),
            Text(
              'Counts: ${counts['reinforceCount'] ?? 0} reinforce · ${counts['candidateCount'] ?? 0} candidate · ${counts['relationHintCount'] ?? 0} relation · ${counts['createdEventCount'] ?? 0} event',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clusterSection() {
    if (_clusterPreview.isEmpty) {
      final distribution = _map(_clusterSummary['distribution']);
      if (distribution.isEmpty) return _emptyLabel('No cluster summary yet.');
    }
    final distribution = _map(_clusterSummary['distribution']);
    if (distribution.isEmpty) return _emptyLabel('No cluster summary yet.');
    final items = distribution.entries.toList()
      ..sort((a, b) => _num(b.value).compareTo(_num(a.value)));
    final maxCount = items.fold<int>(1, (max, entry) => math.max(max, _num(entry.value, 1)));
    return Column(
      children: items.map((entry) {
        final count = _num(entry.value);
        final fraction = (count / maxCount).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                  backgroundColor: Colors.white.withOpacity(0.06),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _candidateSection() {
    if (_candidatePreview.isEmpty) {
      return _emptyLabel('No active candidates right now.');
    }
    return Column(
      children: _candidatePreview.map((candidate) {
        final cleanupAfterAt = _num(candidate['cleanupAfterAt']);
        final promotedToNodeId = _string(candidate['promotedToNodeId']);
        final isCleaningUp = cleanupAfterAt > 0;
        return Opacity(
          opacity: isCleaningUp ? 0.55 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: _innerCardBox(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_string(candidate['label'], 'Candidate'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _smallPill('Role', _string(candidate['groupGuess'], 'interest')),
                    _smallPill('Strength', _string(candidate['strength'], 'medium'), accent: const Color(0xFFFBBF24)),
                    _smallPill('Status', _string(candidate['status'], 'candidate'), accent: _string(candidate['status']) == 'promoted' ? const Color(0xFF34D399) : const Color(0xFFFBBF24)),
                    _smallPill('Sessions', '${candidate['sessionCount'] ?? 0}'),
                    _smallPill('Mentions', '${candidate['mentionCount'] ?? 0}'),
                    if (_string(candidate['clusterHint']).isNotEmpty) _smallPill('Cluster', _string(candidate['clusterHint'])),
                    if (isCleaningUp)
                      _smallPill('State', 'promoted → cleanup', accent: const Color(0xFF34D399)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Expires ${_relativeTime(candidate['expiresAt'])} · first seen ${_relativeTime(candidate['firstSeenAt'])} · last seen ${_relativeTime(candidate['lastSeenAt'])}',
                  style: TextStyle(color: Colors.white.withOpacity(0.66), height: 1.35),
                ),
                if (isCleaningUp && promotedToNodeId.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Promoted to node: $promotedToNodeId',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontFamily: 'monospace')),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _nodeSection() {
    if (_nodesPreview.isEmpty) return _emptyLabel('No durable node preview yet.');
    return Column(
      children: _nodesPreview.take(16).map((node) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: _innerCardBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_string(node['label'], 'Node'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _smallPill('Role', _string(node['group'], _string(node['role'], 'interest'))),
                  _smallPill('State', _string(node['currentState'], _string(node['healthState'], 'active'))),
                  _smallPill('Heat', '${node['heat'] ?? 0}'),
                  _smallPill('Count', '${node['count'] ?? 0}'),
                  if (_string(node['clusterId']).isNotEmpty) _smallPill('Cluster', _string(node['clusterId'])),
                ],
              ),
              if (_string(node['info']).isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(_string(node['info']), style: TextStyle(color: Colors.white.withOpacity(0.76), height: 1.45)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _eventSection() {
    if (_eventsPreview.isEmpty) return _emptyLabel('No recent events yet.');
    return Column(
      children: _eventsPreview.map((event) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: _innerCardBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_string(event['summary'], 'Event'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _smallPill('Type', _string(event['eventType'], 'event')),
                  if (_string(event['lifecycleAction']).isNotEmpty) _smallPill('Action', _string(event['lifecycleAction'])),
                  _smallPill('Status', _string(event['status'], 'recorded')),
                  if (_string(event['importanceClass']).isNotEmpty) _smallPill('Importance', _string(event['importanceClass'])),
                  if (_string(event['memoryTier']).isNotEmpty) _smallPill('Tier', _string(event['memoryTier'])),
                ],
              ),
              if (_string(event['primaryNodeLabel']).isNotEmpty || (event['connectedNodeLabels'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (_string(event['primaryNodeLabel']).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed_rounded, size: 12, color: Color(0xFF34D399)),
                            const SizedBox(width: 6),
                            Text(_string(event['primaryNodeLabel']),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ...((event['connectedNodeLabels'] as List?) ?? const []).whereType<String>().take(4).map(
                          (label) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Text(label,
                                style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    if (((event['connectedNodeLabels'] as List?)?.length ?? 0) > 4)
                      Text('+${((event['connectedNodeLabels'] as List).length) - 4} more',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11.5)),
                  ],
                ),
              ],
              if (_string(event['absoluteDate']).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Date: ${_string(event['absoluteDate'])}',
                    style: TextStyle(color: Colors.white.withOpacity(0.58), fontSize: 12.5)),
              ],
              if ((event['evidencePreview'] is List) && (event['evidencePreview'] as List).isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Evidence',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text('(${event['evidenceCount'] ?? (event['evidencePreview'] as List).length})',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                ...(event['evidencePreview'] as List).take(2).map((raw) {
                  final isMap = raw is Map;
                  final snippet = isMap ? _string(raw['snippet']) : raw.toString();
                  final role = isMap ? _string(raw['role']) : '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (role.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 2, right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _evidenceRoleColor(role).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _evidenceRoleColor(role).withOpacity(0.35)),
                            ),
                            child: Text(role,
                                style: TextStyle(color: _evidenceRoleColor(role), fontSize: 10.5, fontWeight: FontWeight.w900)),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 2, right: 8),
                            child: Text('•', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ),
                        Expanded(
                          child: Text(snippet,
                              style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.4)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 10),
              Text(
                'Updated ${_relativeTime(event['updatedAt'])} · connected nodes ${(event['connectedNodeIds'] as List?)?.length ?? 0}',
                style: TextStyle(color: Colors.white.withOpacity(0.66), height: 1.35),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _connectionPreviewSection() {
    // Prefer the worker's top-level preview (has resolved labels + reason).
    final topLevel = _list(_status['recentConnectionPreview']);
    final List<Map<String, dynamic>> previews;
    if (topLevel.isNotEmpty) {
      previews = topLevel;
    } else {
      // Fallback: flatten recent log entries so older sessions without the new payload still show something.
      final fallback = <Map<String, dynamic>>[];
      for (final log in _logs) {
        fallback.addAll(_connectionsForLog(log));
      }
      previews = fallback;
    }
    if (previews.isEmpty) {
      return _emptyLabel('No connection preview yet. Once the worker writes or skips edges, they will appear here.');
    }
    return Column(
      children: previews.take(12).map((item) {
        // The top-level shape uses fromLabel/toLabel/reason; the log shape uses from/to.
        final fromLabel = _string(item['fromLabel'], _string(item['from']));
        final toLabel = _string(item['toLabel'], _string(item['to']));
        final state = _string(item['state'], 'created');
        final type = _string(item['type'], 'related_to');
        final reason = _string(item['reason']);
        final coCount = _num(item['coCount']);
        final created = state == 'created' || state == 'reinforced';
        final color = created ? const Color(0xFF34D399) : const Color(0xFFFB7185);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.16)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(created ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('$fromLabel  →  $toLabel',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (coCount > 1)
                          Text('×$coCount',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('$type · ${_connectionStateLabel(state)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    if (reason.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(reason,
                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12.5, height: 1.4)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _rawToggle() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showRaw = !_showRaw),
            icon: Icon(_showRaw ? Icons.visibility_off_rounded : Icons.code_rounded),
            label: Text(_showRaw ? 'Hide raw payloads' : 'Show raw payloads'),
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(String title, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _stageBlock({
    required IconData icon,
    required String title,
    required Color accent,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: accent.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _metricPills(Map<String, dynamic> metrics) {
    final pairs = <MapEntry<String, dynamic>>[
      MapEntry('Slice messages', metrics['sliceMessages']),
      MapEntry('Slice chars', metrics['sliceChars']),
      MapEntry('Meaningful user messages', metrics['meaningfulUserMessages']),
      MapEntry('Idle gap', metrics['idleGapMs']),
      MapEntry('Active duration', metrics['activeDurationMs']),
    ].where((entry) => entry.value != null).toList();
    return pairs.map((entry) => _smallPill(entry.key, '${entry.value}')).toList();
  }

  Widget _listGroup(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white.withOpacity(0.78), fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text('(none)', style: TextStyle(color: Colors.white.withOpacity(0.48), fontStyle: FontStyle.italic))
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item', style: TextStyle(color: Colors.white.withOpacity(0.74), height: 1.35)),
              )),
      ],
    );
  }

  Widget _jsonBox(Map<String, dynamic> payload) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF071421),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          _jsonPretty(payload),
          style: const TextStyle(fontSize: 12.5, height: 1.45, fontFamily: 'monospace'),
        ),
      ),
    );
  }

  Widget _monospaceBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF071421),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12.8, height: 1.45),
      ),
    );
  }

  Widget _smallPill(String label, String value, {Color? accent}) {
    final color = accent ?? Colors.white.withOpacity(0.08);
    final borderColor = accent?.withOpacity(0.26) ?? Colors.white.withOpacity(0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent == null ? color : color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 13),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.white.withOpacity(0.64), fontWeight: FontWeight.w700)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _chipText(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _labelRow(String title, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(color: Colors.white.withOpacity(0.76), height: 1.35),
        children: [
          TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _emptyLabel(String text, {bool compact = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: TextStyle(color: Colors.white.withOpacity(0.62), height: 1.4)),
    );
  }

  BoxDecoration _panelBox() {
    return BoxDecoration(
      color: const Color(0xFF07182B).withOpacity(0.92),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 28, offset: const Offset(0, 12)),
      ],
    );
  }

  BoxDecoration _innerCardBox() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.035),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final Color color;

  const _MetricData(this.label, this.value, this.color);
}
