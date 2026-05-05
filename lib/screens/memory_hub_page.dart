import 'package:flutter/material.dart';
import '../services/memory_session.dart';
import 'memory_graph_page.dart';

class MemoryHubPage extends StatefulWidget {
  const MemoryHubPage({super.key});

  @override
  State<MemoryHubPage> createState() => _MemoryHubPageState();
}

class _MemoryHubPageState extends State<MemoryHubPage> {
  bool _loading = true;
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _focusCtrl = TextEditingController();
  final _projectsCtrl = TextEditingController();
  final _stackCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _preferencesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusCtrl.dispose();
    _projectsCtrl.dispose();
    _stackCtrl.dispose();
    _goalsCtrl.dispose();
    _preferencesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap({bool force = false}) async {
    if (mounted) setState(() => _loading = true);
    try {
      await MemorySession.ensureInitialized(force: force);
      final profile = await MemorySession.loadProfile(force: force);
      _applyProfile(profile);
    } catch (e) {
      if (!mounted) return;
      final msg =
          e.toString().contains('401') || e.toString().contains('Unauthorized')
              ? 'Memory sync needs authentication. Check connection.'
              : 'Could not load memory. Check your connection.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyProfile(MemoryProfile profile) {
    _nameCtrl.text = profile.name;
    _focusCtrl.text = profile.role;
    _projectsCtrl.text = profile.projects;
    _stackCtrl.text = profile.stack;
    _goalsCtrl.text = profile.goals;
    _preferencesCtrl.text = profile.style;
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (mounted) setState(() => _saving = true);
    try {
      final saved = await MemorySession.saveProfile(
        MemoryProfile(
          mode: MemorySession.primaryBackendMode,
          name: _nameCtrl.text.trim(),
          role: _focusCtrl.text.trim(),
          projects: _projectsCtrl.text.trim(),
          stack: _stackCtrl.text.trim(),
          goals: _goalsCtrl.text.trim(),
          style: _preferencesCtrl.text.trim(),
        ),
      );
      _applyProfile(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(
    BuildContext context,
    String label, {
    String? hint,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor:
          isLight ? Colors.white.withOpacity(.96) : const Color(0xFF101826),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary.withOpacity(.78),
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }

  Widget _field(
    BuildContext context,
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: maxLines > 1 ? maxLines : 1,
      maxLines: maxLines,
      decoration: _decoration(context, label, hint: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final meta = MemorySession.memoryMeta;

    final stats = <_StatEntry>[
      _StatEntry('Nodes', '${meta['memoryNodeCount'] ?? 0}', Icons.hub_rounded),
      _StatEntry(
        'Edges',
        '${meta['memoryConnectionCount'] ?? 0}',
        Icons.share_rounded,
      ),
      _StatEntry(
        'Events',
        '${meta['memoryEventCount'] ?? 0}',
        Icons.bolt_rounded,
      ),
      _StatEntry(
        'Sessions',
        '${meta['memorySessionCount'] ?? 0}',
        Icons.history_rounded,
      ),
      if ((meta['memoryCandidateCount'] ?? 0) > 0)
        _StatEntry(
          'Candidates',
          '${meta['memoryCandidateCount']}',
          Icons.pending_rounded,
        ),
      if ((meta['memoryClusterCount'] ?? 0) > 0)
        _StatEntry(
          'Clusters',
          '${meta['memoryClusterCount']}',
          Icons.bubble_chart_rounded,
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: const Text('Memory Center'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _bootstrap(force: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isLight
                    ? const [Color(0xFFF6FAFF), Color(0xFFEEF3FF)]
                    : const [
                      Color(0xFF08101A),
                      Color(0xFF0F1725),
                      Color(0xFF09111A),
                    ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                    onRefresh: () => _bootstrap(force: true),
                    child: ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      children: [
                        _HeroBanner(stats: stats),
                        const SizedBox(height: 18),
                        _OpenGraphButton(
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MemoryGraphPage(),
                                ),
                              ),
                        ),
                        const SizedBox(height: 18),
                        _SectionCard(
                          title: 'Memory Profile',
                          subtitle:
                              'This baseline layer seeds memory nodes before each session. Keep it accurate and current.',
                          child: Column(
                            children: [
                              _field(
                                context,
                                _nameCtrl,
                                'Name',
                                hint: 'How the assistant identifies you',
                              ),
                              const SizedBox(height: 14),
                              _field(
                                context,
                                _focusCtrl,
                                'Current focus',
                                hint: 'Builder, founder, product lead',
                              ),
                              const SizedBox(height: 14),
                              _field(
                                context,
                                _projectsCtrl,
                                'Current projects',
                                hint: 'GPMai, Play Store launch',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                context,
                                _stackCtrl,
                                'Tech stack',
                                hint: 'Flutter, Firebase, Cloudflare Workers',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                context,
                                _goalsCtrl,
                                'Goals',
                                hint: 'Launch, graph cleanup, premium UX',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 14),
                              _field(
                                context,
                                _preferencesCtrl,
                                'Response preferences',
                                hint: 'Practical, serious, clear, no fluff',
                                maxLines: 2,
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: const Icon(Icons.save_rounded),
                                      label: Text(
                                        _saving ? 'Saving…' : 'Save profile',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _saving
                                              ? null
                                              : () => _bootstrap(force: true),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: const Text('Reload'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}

class _StatEntry {
  final String label;
  final String value;
  final IconData icon;
  const _StatEntry(this.label, this.value, this.icon);
}

class _HeroBanner extends StatelessWidget {
  final List<_StatEntry> stats;

  const _HeroBanner({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors:
              isLight
                  ? const [
                    Color(0xFFBEE1FF),
                    Color(0xFFDCD3FF),
                    Color(0xFFFFE7C3),
                  ]
                  : const [
                    Color(0xFF0F2946),
                    Color(0xFF261E45),
                    Color(0xFF40311D),
                  ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? .06 : .22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unified Memory',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Every conversation builds durable nodes, edges, and events — creating a living map of what matters to you.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: stats
                .map((s) => _StatPill(entry: s))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final _StatEntry entry;

  const _StatPill({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            isLight
                ? Colors.white.withOpacity(.78)
                : Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            entry.icon,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '${entry.value}  ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(text: entry.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenGraphButton extends StatelessWidget {
  final VoidCallback onTap;

  const _OpenGraphButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors:
                isLight
                    ? [cs.primary.withOpacity(.12), cs.primary.withOpacity(.06)]
                    : [
                      cs.primary.withOpacity(.22),
                      cs.primary.withOpacity(.10),
                    ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.primary.withOpacity(.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.16),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.primary.withOpacity(.38)),
              ),
              child: Icon(
                Icons.account_tree_rounded,
                color: cs.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Open Brain Graph',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore nodes, edges, clusters and events in your live memory graph.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color:
            isLight ? Colors.white.withOpacity(.95) : const Color(0xFF0F1725),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? .04 : .18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
