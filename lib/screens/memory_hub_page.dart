import 'package:flutter/material.dart';
import '../services/gpmai_memory_api.dart';

import '../services/memory_session.dart';
import 'memory_graph_page.dart';
import 'memory_preview_page.dart';
import 'memory_tools_page.dart';

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

  String _compressedPreview = '';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load memory center: $e')),
      );
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
    _compressedPreview = profile.compressedPrompt;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memory profile saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    // Quota-safe: returning from graph/tools/preview no longer forces a backend reload.
    // Use the explicit refresh button or pull-to-refresh when you really need fresh data.
  }

  InputDecoration _decoration(BuildContext context, String label, {String? hint}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isLight ? Colors.white.withOpacity(.96) : const Color(0xFF101826),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(.78), width: 1.4),
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
    final counts = <String, String>{
      'Nodes': '${meta['memoryNodeCount'] ?? 0}',
      'Links': '${meta['memoryConnectionCount'] ?? 0}',
      'Events': '${meta['memoryEventCount'] ?? 0}',
      'Sessions': '${meta['memorySessionCount'] ?? 0}',
    };

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: const Text('Memory center'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _bootstrap(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLight
                ? const [Color(0xFFF6FAFF), Color(0xFFEEF3FF)]
                : const [Color(0xFF08101A), Color(0xFF0F1725), Color(0xFF09111A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _bootstrap(force: true),
                  child: ListView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    children: [
                      _HeroBanner(counts: counts),
                      const SizedBox(height: 18),
                      _ActionGrid(
                        onGraph: () => _openPage(const MemoryGraphPage()),
                        onPreview: () => _openPage(const MemoryPreviewPage()),
                        onTools: () => _openPage(const MemoryToolsPage()),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Profile core',
                        subtitle:
                            'This is the always-on grounding layer. Keep it real, sharp, and current so the backend can seed clean memory nodes before deeper recall.',
                        child: Column(
                          children: [
                            _field(context, _nameCtrl, 'Name', hint: 'How the assistant should identify you'),
                            const SizedBox(height: 14),
                            _field(context, _focusCtrl, 'Current focus', hint: 'Builder, founder, launch owner, product lead'),
                            const SizedBox(height: 14),
                            _field(context, _projectsCtrl, 'Current projects', hint: 'GPMai, Play Store launch, monetization flow', maxLines: 3),
                            const SizedBox(height: 14),
                            _field(context, _stackCtrl, 'Tech stack', hint: 'Flutter, Firebase, Cloudflare Workers, OpenRouter', maxLines: 3),
                            const SizedBox(height: 14),
                            _field(context, _goalsCtrl, 'Goals', hint: 'Launch, graph cleanup, premium UX', maxLines: 3),
                            const SizedBox(height: 14),
                            _field(context, _preferencesCtrl, 'Response preferences', hint: 'Practical, serious, clear, no fluff', maxLines: 2),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: const Icon(Icons.save_rounded),
                                    label: Text(_saving ? 'Saving...' : 'Save profile'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _saving ? null : () => _bootstrap(force: true),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Reload'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: 'Compressed profile preview',
                        subtitle:
                            'This is the compact baseline context your Worker can inject before recall gets involved.',
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isLight ? const Color(0xFFF6F9FF) : const Color(0xFF0B1220),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _compressedPreview.trim().isEmpty ? 'No compressed preview yet. Save the profile first.' : _compressedPreview,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PipelineNoteCard(
                        bullets: const [
                          'Profile save seeds the always-on baseline and should create clean profile-driven nodes.',
                          'Admin monitoring and real pipeline verification live in Admin monitor. Use real chat to grow the graph.',
                          'The graph should rebuild from fresh synthetic seeding or real chat learning, not stale memory.',
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final Map<String, String> counts;

  const _HeroBanner({required this.counts});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isLight
              ? const [Color(0xFFBEE1FF), Color(0xFFDCD3FF), Color(0xFFFFE7C3)]
              : const [Color(0xFF0F2946), Color(0xFF261E45), Color(0xFF40311D)],
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
            'Brain control center',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Profile is the baseline layer. Graph inspection and admin monitoring help you verify the real automatic engine while chatting normally.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: counts.entries
                .map((entry) => _StatPill(label: entry.key, value: entry.value))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(.78) : Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: '$value  ', style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: label),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final VoidCallback onGraph;
  final VoidCallback onPreview;
  final VoidCallback onTools;

  const _ActionGrid({required this.onGraph, required this.onPreview, required this.onTools});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.account_tree_rounded,
                title: 'Brain graph',
                subtitle: 'Open the live graph, inspect nodes, edges, zoom, and node details.',
                onTap: onGraph,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.preview_rounded,
                title: 'Preview memory',
                subtitle: 'Simulation-only view for recall and write behavior. Use Admin monitor for real extraction truth.',
                onTap: onPreview,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WideActionTile(
          icon: Icons.science_rounded,
          title: 'Admin monitor',
          subtitle: 'Watch the real engine live: sessions, candidates, promotion, events, structure, and connection health.',
          onTap: onTools,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withOpacity(.94) : const Color(0xFF0F1725),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _WideActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _WideActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isLight ? Colors.white.withOpacity(.94) : const Color(0xFF0F1725),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
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

  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? Colors.white.withOpacity(.95) : const Color(0xFF0F1725),
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
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _PipelineNoteCard extends StatelessWidget {
  final List<String> bullets;

  const _PipelineNoteCard({required this.bullets});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isLight ? const Color(0xFFFFF7EC) : const Color(0xFF20170D),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pipeline notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          ...bullets.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('• $text', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}



