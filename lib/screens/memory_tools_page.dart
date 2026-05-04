import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/memory_session.dart';
import 'memory_graph_page.dart';
import 'memory_preview_page.dart';
import '../services/memory_status_cache.dart';

class MemoryToolsPage extends StatefulWidget {
  const MemoryToolsPage({super.key});

  @override
  State<MemoryToolsPage> createState() => _MemoryToolsPageState();
}

class _MemoryToolsPageState extends State<MemoryToolsPage> {
  static const Duration _pollInterval = Duration(seconds: 90);
  static const Duration _manualRefreshCooldown = Duration(seconds: 30);

  Timer? _timer;
  bool _loading = true;
  bool _autoRefresh = false;
  bool _showRaw = false;
  bool _loadingDeepStatus = false;
  bool _deepStatusLoaded = false;
  DateTime? _lastManualRefreshAt;
  String? _error;
  Map<String, dynamic> _debug = const <String, dynamic>{};
  Map<String, dynamic> _finalStatus = const <String, dynamic>{};

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
      final results = await Future.wait([
        MemorySession.debugStatus(),
      ]);
      if (!mounted) return;
      MemoryStatusCache.set(Map<String, dynamic>.from(results[0]));
      setState(() {
        _debug = Map<String, dynamic>.from(results[0]);
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  bool get _manualRefreshBlocked {
    final last = _lastManualRefreshAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _manualRefreshCooldown;
  }

  int get _manualRefreshRemainingSeconds {
    final last = _lastManualRefreshAt;
    if (last == null) return 0;
    final remaining = _manualRefreshCooldown - DateTime.now().difference(last);
    return remaining.inSeconds.clamp(0, _manualRefreshCooldown.inSeconds);
  }

  Future<void> _manualRefresh() async {
    if (_manualRefreshBlocked) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Give Firestore a break bro. Refresh again in ${_manualRefreshRemainingSeconds}s.')),
      );
      return;
    }
    _lastManualRefreshAt = DateTime.now();
    await _load();
  }

  Future<void> _loadDeepFinalStatus() async {
    if (_loadingDeepStatus) return;
    setState(() => _loadingDeepStatus = true);
    try {
      await MemorySession.ensureInitialized();
      final res = await MemorySession.finalStatus();
      if (!mounted) return;
      setState(() {
        _finalStatus = Map<String, dynamic>.from(res);
        _deepStatusLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deep status load failed: $e')));
    } finally {
      if (mounted) setState(() => _loadingDeepStatus = false);
    }
  }

  Map<String, dynamic> get _debugStats => Map<String, dynamic>.from(_debug['stats'] ?? const <String, dynamic>{});
  Map<String, dynamic> get _finalStats => Map<String, dynamic>.from(_finalStatus['stats'] ?? const <String, dynamic>{});
  Map<String, dynamic> get _latestPipeline => Map<String, dynamic>.from(_debug['latestPipeline'] ?? _finalStatus['latestPipeline'] ?? const <String, dynamic>{});
  Map<String, dynamic> get _clusterSummary => Map<String, dynamic>.from(_debug['clusterSummary'] ?? _finalStatus['clusterSummary'] ?? const <String, dynamic>{});
  Map<String, dynamic> get _memoryMeta => Map<String, dynamic>.from(_debug['memoryMeta'] ?? _finalStatus['memoryMeta'] ?? const <String, dynamic>{});
  Map<String, dynamic> get _profile => Map<String, dynamic>.from(_debug['profile'] ?? _finalStatus['profile'] ?? const <String, dynamic>{});

  List<Map<String, dynamic>> get _sessions => _readList(_debug['activeSessionPreview']);
  List<Map<String, dynamic>> get _candidatePreview {
    final list = _readList(_debug['candidatePreview']);
    return list.isEmpty ? _readList(_finalStatus['candidatesPreview']) : list;
  }

  List<Map<String, dynamic>> get _nodesPreview {
    final list = _readList(_debug['nodesPreview']);
    return list.isEmpty ? _readList(_finalStatus['nodesPreview']) : list;
  }
  List<Map<String, dynamic>> get _eventsPreview {
    final list = _readList(_debug['recentEventPreview']);
    return list.isEmpty ? _readList(_finalStatus['recentEvents']) : list;
  }

  List<Map<String, dynamic>> get _logs {
    final list = _readList(_debug['recentLogs']);
    return list.isEmpty ? _readList(_finalStatus['recentLogs']) : list;
  }

  List<Map<String, dynamic>> get _clusterPreview => _readList(_clusterSummary['preview']);

  static List<Map<String, dynamic>> _readList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  int _num(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  String _fmtTime(dynamic value) {
    final ts = _num(value, 0);
    if (ts <= 0) return 'â€”';
    return DateFormat('dd MMM Â· hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Map<String, dynamic> get _quotaSummary {
    final fromDebug = Map<String, dynamic>.from(_debug['quota'] ?? _debug['quotaSummary'] ?? const <String, dynamic>{});
    if (fromDebug.isNotEmpty) return fromDebug;
    return Map<String, dynamic>.from(_finalStatus['quota'] ?? _finalStatus['quotaSummary'] ?? const <String, dynamic>{});
  }

  bool get _quotaSafeMode => _bool(_debug['quotaSafeMode'] ?? _finalStatus['quotaSafeMode'] ?? _quotaSummary['quotaSafeMode']);
  bool get _pass2Deferred => _bool(_debug['pass2Deferred'] ?? _finalStatus['pass2Deferred'] ?? _quotaSummary['pass2Deferred']);
  bool get _debugBudgetExceeded => _bool(_debug['debugBudgetExceeded'] ?? _finalStatus['debugBudgetExceeded'] ?? _quotaSummary['debugBudgetExceeded']);

  bool _bool(dynamic value) {
    if (value is bool) return value;
    final s = '$value'.toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  String _text(dynamic value, [String fallback = 'â€”']) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  String _pass2StatusLabel() {
    final raw = _text(_debug['pass2Status'] ?? _finalStatus['pass2Status'] ?? _quotaSummary['pass2Status'], '');
    if (raw.isNotEmpty) return raw;
    if (_pass2Deferred) return 'deferred';
    if (_debugBudgetExceeded) return 'debug budget hit';
    return 'not shown';
  }

  String _compactSummaryStatus(Map<String, dynamic> log) {
    return _text(log['status'] ?? log['resultStatus'] ?? log['decision'] ?? log['stage'], 'summary');
  }

  List<Map<String, dynamic>> _candidateEvidence(Map<String, dynamic> candidate) {
    return _readList(candidate['evidence'] ?? candidate['evidencePreview'] ?? candidate['recentEvidence']).take(4).toList(growable: false);
  }

  String _pipelineHeadline() {
    final status = (_latestPipeline['status'] ?? 'idle').toString();
    final trigger = (_latestPipeline['triggerReason'] ?? '').toString();
    if (status == 'idle' && trigger.isEmpty) return 'Waiting for a meaningful automatic extraction attempt.';
    if (status.toLowerCase().contains('error')) return 'Latest attempt failed and needs backend attention.';
    if (trigger.isNotEmpty) return 'Latest pipeline state: $status Â· trigger: $trigger';
    return 'Latest pipeline state: $status';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin memory monitor'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryPreviewPage())),
            icon: const Icon(Icons.preview_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryGraphPage())),
            icon: const Icon(Icons.hub_rounded),
          ),
          IconButton(onPressed: _manualRefresh, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF09101A), Color(0xFF0D1624), Color(0xFF081019)],
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
                        child: SelectableText(_error!, style: theme.textTheme.bodyMedium),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _heroCard(),
                        const SizedBox(height: 14),
                        _actionBar(),
                        const SizedBox(height: 14),
                        _metricGrid(),
                        const SizedBox(height: 14),
                        _sectionCard('Current pipeline truth', child: _pipelineSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Cluster distribution', child: _clusterSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Active sessions', child: _sessionSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Candidates', child: _candidateSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Durable nodes', child: _nodeSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Recent events', child: _eventSection()),
                        const SizedBox(height: 14),
                        _sectionCard('Recent pipeline logs', child: _logsSection()),
                        const SizedBox(height: 14),
                        _rawToggle(),
                        if (_showRaw) ...[
                          const SizedBox(height: 12),
                          _sectionCard('Raw debug payload', child: _jsonBox(_debug)),
                          const SizedBox(height: 12),
                          if (_deepStatusLoaded) _sectionCard('Raw final-status payload', child: _jsonBox(_finalStatus)),
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _heroCard() {
    final profileSummary = (_profile['compressedPrompt'] ?? '').toString().trim();
    final latestRun = _fmtTime(_latestPipeline['lastRunAt']);
    final status = (_latestPipeline['status'] ?? 'idle').toString();
    final trigger = (_latestPipeline['triggerReason'] ?? '').toString();
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
                decoration: BoxDecoration(color: const Color(0xFF7C3AED).withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.memory_rounded),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Automatic extraction truth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              Switch.adaptive(
                value: _autoRefresh,
                onChanged: (value) {
                  setState(() => _autoRefresh = value);
                  _bindTimer();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Auto extraction only. This screen is read-only and exists to show whether the real backend pipeline extracted, waited, or failed.',
            style: TextStyle(color: Colors.white.withOpacity(0.74), height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _smallPill('Pipeline', status.isEmpty ? 'idle' : status),
              _smallPill('Trigger', trigger.isEmpty ? 'â€”' : trigger),
              _smallPill('Last run', latestRun),
              _smallPill('Schema', '${_memoryMeta['memorySchemaVersion'] ?? 'â€”'}'),
              _smallPill('Quota', _quotaSafeMode ? 'safe' : 'normal'),
              _smallPill('Pass 2', _pass2StatusLabel()),
              if (_debugBudgetExceeded) _smallPill('Debug', 'budget hit'),
            ],
          ),
          if (profileSummary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(profileSummary, style: TextStyle(color: Colors.white.withOpacity(0.68), height: 1.45)),
          ],
        ],
      ),
    );
  }

  Widget _actionBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _manualRefresh,
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Refresh light'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MemoryGraphPage())),
                icon: const Icon(Icons.account_tree_rounded),
                label: const Text('Open graph'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _loadingDeepStatus ? null : _loadDeepFinalStatus,
          icon: Icon(_deepStatusLoaded ? Icons.fact_check_rounded : Icons.manage_search_rounded),
          label: Text(_loadingDeepStatus
              ? 'Loading deep status...'
              : _deepStatusLoaded
                  ? 'Deep final status loaded'
                  : 'Load deep final status manually'),
        ),
      ],
    );
  }

  Widget _metricGrid() {
    final cards = [
      _MetricData('Sessions', '${_debugStats['sessions'] ?? 0}', const Color(0xFF60A5FA)),
      _MetricData('Candidates', '${_debugStats['candidates'] ?? _finalStats['candidates'] ?? 0}', const Color(0xFFF59E0B)),
      _MetricData('Nodes', '${_finalStats['nodes'] ?? _debugStats['nodes'] ?? 0}', const Color(0xFF8B5CF6)),
      _MetricData('Events', '${_finalStats['events'] ?? _debugStats['events'] ?? 0}', const Color(0xFF34D399)),
      _MetricData('Edges', '${_finalStats['connections'] ?? _debugStats['connections'] ?? 0}', const Color(0xFF38BDF8)),
      _MetricData('Clusters', '${_finalStats['clusters'] ?? _debugStats['clusters'] ?? 0}', const Color(0xFFF472B6)),
    ];
    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: _panelBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
              ),
              Text(item.label, style: TextStyle(color: Colors.white.withOpacity(0.66), fontWeight: FontWeight.w700)),
              Text(item.value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        );
      },
    );
  }

  Widget _pipelineSection() {
    final pipeline = _latestPipeline;
    final session = _sessions.isEmpty ? const <String, dynamic>{} : _sessions.first;
    final trigger = (session['pendingTriggerReason'] ?? pipeline['triggerReason'] ?? 'â€”').toString();
    final checks = [
      _PipelineCheck('Latest summary', pipeline['hasLog'] == true || _logs.isNotEmpty, _pipelineHeadline()),
      _PipelineCheck('Current wait/trigger reason', trigger != 'â€”' || (pipeline['status'] ?? '') != '', trigger == 'â€”' ? 'No explicit pending reason surfaced yet.' : trigger),
      _PipelineCheck('Pending slice', _num(session['pendingSliceMessageCount']) > 0 || _num(session['pendingSliceCharCount']) > 0, 'messages ${session['pendingSliceMessageCount'] ?? 0} Â· chars ${session['pendingSliceCharCount'] ?? 0}'),
      _PipelineCheck('Candidates', _candidatePreview.isNotEmpty || _num(pipeline['candidateCreated']) > 0, 'Created now: ${pipeline['candidateCreated'] ?? 0} Â· active backlog: ${_candidatePreview.length}'),
      _PipelineCheck('Promotion / reinforce', _num(pipeline['promoted']) > 0 || _num(pipeline['reinforced']) > 0, 'Promoted: ${pipeline['promoted'] ?? 0} Â· reinforced: ${pipeline['reinforced'] ?? 0}'),
      _PipelineCheck('Events', _eventsPreview.isNotEmpty || _num(pipeline['eventCount']) > 0, 'Recent event writes: ${pipeline['eventCount'] ?? 0}'),
      _PipelineCheck('Checkpoint movement', _num(session['lastProcessedAt']) > 0, 'Last processed: ${_fmtTime(session['lastProcessedAt'])}'),
    ];
    return Column(
      children: checks
          .map(
            (check) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    check.ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: check.ok ? const Color(0xFF34D399) : const Color(0xFFF59E0B),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(check.label, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(check.message, style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _clusterSection() {
    if (_clusterPreview.isEmpty) {
      return Text('No cluster distribution yet. Once durable nodes exist, broad semantic homes will appear here.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    final maxCount = _clusterPreview.map((e) => _num(e['count'], 1)).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: _clusterPreview.map((cluster) {
        final count = _num(cluster['count'], 0);
        final progress = maxCount <= 0 ? 0.0 : count / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text((cluster['clusterId'] ?? 'general').toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('$count node${count == 1 ? '' : 's'}', style: TextStyle(color: Colors.white.withOpacity(0.64), fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                  backgroundColor: Colors.white.withOpacity(0.08),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sessionSection() {
    if (_sessions.isEmpty) {
      return Text('No active session preview yet. Start a meaningful chat turn and refresh.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    return Column(
      children: _sessions.map((session) {
        final pendingReason = (session['pendingTriggerReason'] ?? 'â€”').toString();
        final lastReason = (session['lastExtractionReason'] ?? 'â€”').toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((session['threadKey'] ?? session['id'] ?? 'session').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallPill('Started', _fmtTime(session['startedAt'])),
                  _smallPill('Last active', _fmtTime(session['lastActivityAt'])),
                  _smallPill('Turns', '${session['turnCount'] ?? 0}'),
                  _smallPill('Pending msgs', '${session['pendingSliceMessageCount'] ?? 0}'),
                  _smallPill('Pending chars', '${session['pendingSliceCharCount'] ?? 0}'),
                  _smallPill('Pending reason', pendingReason.isEmpty ? 'â€”' : pendingReason),
                  _smallPill('Last extraction', lastReason.isEmpty ? 'â€”' : lastReason),
                  _smallPill('Next eligible', _fmtTime(session['nextEligibleExtractAt'])),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _candidateSection() {
    if (_candidatePreview.isEmpty) {
      return Text('No active candidates right now. Strong one-session topics may promote directly, while weaker durable topics wait here first.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    return Column(
      children: _candidatePreview.map((candidate) {
        final evidence = _candidateEvidence(candidate);
        final status = _text(candidate['status'], 'candidate');
        final strength = _text(candidate['strength'], 'â€”');
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 14, backgroundColor: Color(0xFFF59E0B), child: Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_text(candidate['label'], 'candidate'), style: const TextStyle(fontWeight: FontWeight.w900))),
                  _smallPill('Candidate', status),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallPill('Strength', strength),
                  _smallPill('Mentions', '${candidate['mentionCount'] ?? 0}'),
                  _smallPill('Sessions', '${candidate['sessionCount'] ?? 0}'),
                  _smallPill('Expires', _fmtTime(candidate['expiresAt'])),
                ],
              ),
              if (evidence.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Evidence', style: TextStyle(color: Colors.white.withOpacity(0.66), fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                ...evidence.map((item) => _evidenceRow(item)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _evidenceRow(Map<String, dynamic> item) {
    final type = _text(item['type'] ?? item['evidenceType'], 'evidence');
    final summary = _text(item['summary'] ?? item['text'] ?? item['reason'], 'â€”');
    final when = _fmtTime(item['createdAt'] ?? item['ts']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.fiber_manual_record_rounded, size: 8, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$type Â· $summary${when == 'â€”' ? '' : ' Â· $when'}', style: TextStyle(color: Colors.white.withOpacity(0.72), height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _nodeSection() {
    if (_nodesPreview.isEmpty) {
      return Text('No durable nodes yet. Promotion across sessions or direct durable fast-lane signals will show up here.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    return Column(
      children: _nodesPreview.map((node) {
        final state = _text(node['currentState'] ?? node['state'] ?? node['healthState'], 'â€”');
        final latestSlice = _text(node['latestSliceSummary'] ?? node['lastSliceSummary'], '');
        final latestEvent = _text(node['lastEventSummary'] ?? node['latestEventSummary'], '');
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(radius: 14, backgroundColor: Color(0xFF8B5CF6), child: Icon(Icons.hub_rounded, size: 16, color: Colors.white)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_text(node['label'], 'node'), style: const TextStyle(fontWeight: FontWeight.w900))),
                  _smallPill('Node', state),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallPill('Cluster', _text(node['clusterId'] ?? node['cluster'], 'general')),
                  _smallPill('Mentions', '${node['mentionCount'] ?? node['count'] ?? 0}'),
                  _smallPill('Slices', '${node['sliceCount'] ?? node['slicesCount'] ?? 0}'),
                  _smallPill('Events', '${node['eventCount'] ?? node['eventsCount'] ?? 0}'),
                  _smallPill('Updates', '${node['meaningfulUpdateCount'] ?? node['updateCount'] ?? 0}'),
                ],
              ),
              if (latestSlice.isNotEmpty) ...[
                const SizedBox(height: 10),
                _summaryBox('Latest slice', latestSlice),
              ],
              if (latestEvent.isNotEmpty) ...[
                const SizedBox(height: 8),
                _summaryBox('Latest event', latestEvent),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryBox(String label, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white.withOpacity(0.76), height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }

  Widget _eventSection() {
    if (_eventsPreview.isEmpty) {
      return Text('No recent events yet. Lifecycle updates like started / stopped / resumed will appear here.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    return Column(
      children: _eventsPreview.map((event) {
        final lifecycle = (event['lifecycleAction'] ?? '').toString();
        final importance = (event['memoryTier'] ?? event['importanceClass'] ?? '').toString();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(radius: 14, backgroundColor: Color(0xFF34D399), child: Icon(Icons.bolt_rounded, size: 16, color: Colors.white)),
          title: Text((event['summary'] ?? 'event').toString(), style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(
            '${event['eventType'] ?? ''}${lifecycle.isEmpty ? '' : ' Â· $lifecycle'}${importance.isEmpty ? '' : ' Â· $importance'}',
            style: TextStyle(color: Colors.white.withOpacity(0.68)),
          ),
          trailing: Text(_fmtTime(event['updatedAt']), style: TextStyle(color: Colors.white.withOpacity(0.58), fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _logsSection() {
    if (_logs.isEmpty) {
      return Text('No recent compact summaries yet. Send a fresh meaningful turn and refresh again.', style: TextStyle(color: Colors.white.withOpacity(0.7)));
    }
    return Column(
      children: _logs.take(8).map((log) {
        final trigger = Map<String, dynamic>.from(log['trigger'] ?? const <String, dynamic>{});
        final counts = Map<String, dynamic>.from(log['counts'] ?? log['summary'] ?? const <String, dynamic>{});
        final stages = _readList(log['stages']).isNotEmpty ? _readList(log['stages']) : _readList(log['importantStages']);
        final pass2Deferred = _bool(log['pass2Deferred'] ?? log['quotaSafeModePass2Deferred']);
        final checkpointAdvanced = _bool(log['checkpointAdvanced']);
        final optionalSuppressed = _bool(log['optionalDebugSuppressed'] ?? log['debugBudgetExceeded']);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(_fmtTime(log['createdAt'] ?? log['updatedAt']), style: const TextStyle(fontWeight: FontWeight.w900))),
                  _smallPill('Summary', _compactSummaryStatus(log)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallPill('Trigger', _text(trigger['reason'] ?? log['triggerReason'], 'â€”')),
                  _smallPill('Candidates', '${counts['candidateCount'] ?? counts['candidates'] ?? 0}'),
                  _smallPill('Nodes', '${counts['nodeCount'] ?? counts['nodes'] ?? counts['createdNodeCount'] ?? 0}'),
                  _smallPill('Slices', '${counts['sliceCount'] ?? counts['slices'] ?? 0}'),
                  _smallPill('Events', '${counts['eventCount'] ?? counts['createdEventCount'] ?? 0}'),
                  _smallPill('Checkpoint', checkpointAdvanced ? 'advanced' : 'â€”'),
                  if (pass2Deferred) _smallPill('Pass 2', 'deferred'),
                  if (optionalSuppressed) _smallPill('Debug', 'suppressed'),
                ],
              ),
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  stages.take(8).map((stage) => _text(stage['stage'] ?? stage['name'] ?? stage)).join(' â†’ '),
                  style: TextStyle(color: Colors.white.withOpacity(0.62), height: 1.35, fontSize: 12),
                ),
              ],
              if (_text(log['packetPreview'], '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_text(log['packetPreview'], ''), style: TextStyle(color: Colors.white.withOpacity(0.68), height: 1.4)),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _rawToggle() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => setState(() => _showRaw = !_showRaw),
        icon: Icon(_showRaw ? Icons.visibility_off_rounded : Icons.code_rounded),
        label: Text(_showRaw ? 'Hide raw payloads' : 'Show raw payloads'),
      ),
    );
  }

  Widget _jsonBox(Map<String, dynamic> value) {
    final pretty = const JsonEncoder.withIndent('  ').convert(value);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF08111C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SelectableText(pretty, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.4, height: 1.45)),
    );
  }

  Widget _sectionCard(String title, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _smallPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.white.withOpacity(0.62), fontWeight: FontWeight.w700)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelBox() => BoxDecoration(
        color: const Color(0xFF111826).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      );
}

class _MetricData {
  final String label;
  final String value;
  final Color color;

  const _MetricData(this.label, this.value, this.color);
}

class _PipelineCheck {
  final String label;
  final bool ok;
  final String message;

  const _PipelineCheck(this.label, this.ok, this.message);
}

