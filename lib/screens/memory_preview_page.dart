import 'package:flutter/material.dart';

import '../services/memory_session.dart';

class MemoryPreviewPage extends StatefulWidget {
  const MemoryPreviewPage({super.key, this.initialMode});

  final String? initialMode;

  @override
  State<MemoryPreviewPage> createState() => _MemoryPreviewPageState();
}

class _MemoryPreviewPageState extends State<MemoryPreviewPage> {
  bool _loading = true;
  final _questionCtrl = TextEditingController(
    text: 'I started training boxing and I want to continue it seriously',
  );
  Map<String, dynamic>? _chatPreview;
  Map<String, dynamic>? _recallPreview;
  Map<String, dynamic>? _writePreview;
  Map<String, dynamic>? _finalStatus;
  bool _loadingFinalStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      await MemorySession.ensureInitialized();
      final question = _questionCtrl.text.trim();
      final results = await Future.wait([
        MemorySession.chatPreview(question: question),
        MemorySession.recallPreview(question: question),
        MemorySession.writePreview(userText: question),
      ]);
      if (!mounted) return;
      setState(() {
        _chatPreview = Map<String, dynamic>.from(results[0]);
        _recallPreview = Map<String, dynamic>.from(results[1]);
        _writePreview = Map<String, dynamic>.from(results[2]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not build preview: $e')),
      );
    }
  }

  Future<void> _loadFinalStatusOnDemand() async {
    if (_loadingFinalStatus) return;
    setState(() => _loadingFinalStatus = true);
    try {
      final res = await MemorySession.finalStatus();
      if (!mounted) return;
      setState(() => _finalStatus = Map<String, dynamic>.from(res));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Final status load failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingFinalStatus = false);
    }
  }

  List<Map<String, dynamic>> _readList(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  int _num(dynamic value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final chatPreview = _chatPreview ?? const <String, dynamic>{};
    final recall = (_recallPreview?['recall'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final writePreview = _writePreview ?? const <String, dynamic>{};
    final finalStatus = _finalStatus ?? const <String, dynamic>{};
    final entryNodes = _readList(recall['entryNodes']);
    final events = _readList(recall['events']);
    final predictions = _readList(writePreview['predictions']);
    final clusterPreview = _readList((finalStatus['clusterSummary'] as Map?)?['preview']);
    final trigger = (writePreview['trigger'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final extraction = (writePreview['extraction'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final stats = (finalStatus['stats'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Memory preview')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLight
                ? const [Color(0xFFF5FAFF), Color(0xFFEFF3FF)]
                : const [Color(0xFF090F16), Color(0xFF0C1320), Color(0xFF0A1018)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _NoticeCard(
                      title: 'Simulation only',
                      body:
                          'This page predicts what recall and write-time memory routing may do. It is useful for checking shape and wording, but it is not proof that live automatic extraction ran. Use Admin monitor for real pipeline truth.',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _questionCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Preview sentence',
                        helperText: 'Use a strong meaningful sentence to inspect likely memory behavior.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh simulation'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loadingFinalStatus ? null : _loadFinalStatusOnDemand,
                      icon: const Icon(Icons.manage_search_rounded),
                      label: Text(_loadingFinalStatus ? 'Loading final status...' : 'Load deep final status manually'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _MetricCard(label: 'Trigger', value: (trigger['reason'] ?? '—').toString())),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(label: 'Recall mode', value: (recall['mode'] ?? 'none').toString())),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _MetricCard(label: 'Candidates now', value: '${stats['candidates'] ?? 0}')),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricCard(label: 'Durable nodes', value: '${stats['nodes'] ?? 0}')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PreviewCard(
                      title: 'Profile baseline',
                      body: (chatPreview['profileSummary'] ?? '').toString().trim().isEmpty
                          ? 'No compressed summary yet.'
                          : (chatPreview['profileSummary'] ?? '').toString(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _PreviewCard(title: 'Answer with memory', body: (chatPreview['withMemory'] ?? '').toString())),
                        const SizedBox(width: 12),
                        Expanded(child: _PreviewCard(title: 'Answer without memory', body: (chatPreview['withoutMemory'] ?? '').toString())),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _PreviewCard(title: 'Recall note', body: (recall['note'] ?? '').toString()),
                    const SizedBox(height: 14),
                    _PreviewCard(
                      title: 'Packet preview',
                      body: (writePreview['packetPreview'] ?? '').toString().isEmpty
                          ? 'No packet preview.'
                          : (writePreview['packetPreview'] ?? '').toString(),
                    ),
                    const SizedBox(height: 14),
                    _ListCard(
                      title: 'Write simulation summary',
                      rows: [
                        'reinforce existing: ${predictions.where((e) => (e['outcome'] ?? '') == 'reinforce_existing').length}',
                        'candidate only: ${predictions.where((e) => (e['outcome'] ?? '') == 'candidate_only').length}',
                        'promote node: ${predictions.where((e) => (e['outcome'] ?? '') == 'promote_node').length}',
                        'suppressed: ${predictions.where((e) => (e['outcome'] ?? '') == 'suppressed').length}',
                        'increment nodes: ${((extraction['incrementNodes'] as List?)?.length ?? 0)}',
                        'new candidates: ${((extraction['newNodes'] as List?)?.length ?? 0)}',
                        'relation hints: ${((extraction['relationHints'] as List?)?.length ?? 0)}',
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ListCard(
                      title: 'Prediction details',
                      rows: predictions.map((prediction) {
                        final label = (prediction['label'] ?? 'item').toString();
                        final outcome = (prediction['outcome'] ?? '').toString();
                        final extra = [
                          if ((prediction['group'] ?? '').toString().isNotEmpty) prediction['group'].toString(),
                          if ((prediction['strength'] ?? '').toString().isNotEmpty) prediction['strength'].toString(),
                          if (prediction['threshold'] != null) 'threshold ${prediction['threshold']}',
                          if (prediction['sessionCountPreview'] != null) 'session preview ${prediction['sessionCountPreview']}',
                        ].join(' · ');
                        return '$label → $outcome${extra.isEmpty ? '' : ' · $extra'}';
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    _ListCard(
                      title: 'Active clusters snapshot',
                      rows: clusterPreview
                          .map((e) => '${e['clusterId'] ?? 'general'} (${_num(e['count'], 0)})')
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    _ListCard(
                      title: 'Entry nodes',
                      rows: entryNodes
                          .map((node) => '${node['label'] ?? node['nodeId']} · score ${(node['score'] ?? '').toString()}')
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    _ListCard(
                      title: 'Relevant events',
                      rows: events.map((event) {
                        final tier = (event['memoryTier'] ?? '').toString();
                        final date = (event['absoluteDate'] ?? '').toString();
                        final summary = (event['summary'] ?? '').toString();
                        final head = [if (tier.isNotEmpty) tier, if (date.isNotEmpty) date].join(' • ');
                        return summary.isEmpty ? head : '$head: $summary';
                      }).toList(growable: false),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String body;

  const _NoticeCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFFFF7EC) : const Color(0xFF20170D),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(.92) : const Color(0xFF111826),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final String body;

  const _PreviewCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(.9) : const Color(0xFF111826),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(body.isEmpty ? '—' : body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final List<String> rows;

  const _ListCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(.9) : const Color(0xFF111826),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text('—', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $row', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
              ),
            ),
        ],
      ),
    );
  }
}
