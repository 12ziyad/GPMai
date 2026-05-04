import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/gpmai_api_client.dart';

class CitationBuilderPanel extends StatefulWidget {
  final String responseText;
  final String responseId;
  final Color accentColor;

  const CitationBuilderPanel({
    super.key,
    required this.responseText,
    required this.responseId,
    this.accentColor = const Color(0xFF00B8FF),
  });

  @override
  State<CitationBuilderPanel> createState() => _CitationBuilderPanelState();
}

class _CitationBuilderPanelState extends State<CitationBuilderPanel> {
  static const List<String> _formats = ['apa', 'mla', 'chicago', 'harvard'];
  bool _loading = false;
  String _format = 'apa';
  String? _error;
  int? _lastPoints;
  bool _lastCached = false;
  final Map<String, List<Map<String, dynamic>>> _cache = <String, List<Map<String, dynamic>>>{};

  List<Map<String, dynamic>> get _current => _cache[_format] ?? const <Map<String, dynamic>>[];

  Future<void> _generate() async {
    if (_loading || widget.responseText.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await GpmaiApiClient.generateCitations(
        responseText: widget.responseText,
        responseId: widget.responseId,
        format: _format,
      );
      final raw = (res['citations'] as List?) ?? const [];
      final list = raw.whereType<Map>().map((e) => e.map((k, v) => MapEntry(k.toString(), v))).toList(growable: false);
      final gp = (res['_gpmai'] as Map?)?.map((k, v) => MapEntry(k.toString(), v));
      setState(() {
        _cache[_format] = list;
        _lastPoints = (gp?['pointsCost'] as num?)?.toInt();
        _lastCached = res['cached'] == true;
        if (list.isEmpty) {
          _error = 'No citations were returned.';
        }
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyAll() async {
    if (_current.isEmpty) return;
    final text = _current.map((e) => (e['citation'] ?? '').toString().trim()).where((e) => e.isNotEmpty).join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All citations copied')));
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'web':
        return const Color(0xFF38D39F);
      case 'ai':
        return const Color(0xFF6AA8FF);
      default:
        return const Color(0xFFFF7A7A);
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'web':
        return 'Web';
      case 'ai':
        return 'AI';
      default:
        return 'Unverified';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(.04),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Citation Builder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              if (_lastPoints != null)
                Text(
                  _lastCached ? 'Cached • 0 pts' : 'Used: ${_lastPoints ?? 0} pts',
                  style: TextStyle(color: Colors.white.withOpacity(.72), fontWeight: FontWeight.w700, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _formats.map((fmt) {
              final selected = _format == fmt;
              return ChoiceChip(
                selected: selected,
                label: Text(fmt.toUpperCase()),
                onSelected: (_) => setState(() => _format = fmt),
                selectedColor: accent.withOpacity(.18),
                backgroundColor: Colors.white.withOpacity(.05),
                labelStyle: TextStyle(color: selected ? accent : Colors.white70, fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _generate,
                  icon: _loading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_loading ? 'Generating…' : (_current.isEmpty ? 'Generate citations' : 'Regenerate citations')),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: _current.isEmpty ? null : _copyAll,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Copy all'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontWeight: FontWeight.w700)),
          ],
          if (_current.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._current.map((item) {
              final type = (item['type'] ?? 'unverified').toString();
              final color = _typeColor(type);
              final url = (item['url'] ?? '').toString().trim();
              final citation = (item['citation'] ?? '').toString().trim();
              final claim = (item['claim'] ?? '').toString().trim();
              final confidence = (item['confidence'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withOpacity(.12),
                  border: Border.all(color: color.withOpacity(.30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: color.withOpacity(.14)),
                          child: Text(_typeLabel(type), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                        const Spacer(),
                        Text('Confidence $confidence/10', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                    if (claim.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(claim, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35)),
                    ],
                    if (citation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(citation, style: const TextStyle(color: Colors.white70, height: 1.45)),
                    ],
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => _openUrl(url),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open source'),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: citation));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Citation copied')));
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
