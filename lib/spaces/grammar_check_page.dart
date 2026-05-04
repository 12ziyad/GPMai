// lib/spaces/grammar_check_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../brain_channel.dart' show BrainChannel;

class GrammarCheckPage extends StatefulWidget {
  const GrammarCheckPage({super.key});

  @override
  State<GrammarCheckPage> createState() => _GrammarCheckPageState();
}

class _GrammarCheckPageState extends State<GrammarCheckPage> {
  final _textCtrl = TextEditingController();
  bool _loading = false;

  String? _improved;
  String? _explanation;
  String? _original;

  // Local accent for this space (green theme)
  static const Color kGreen = Color(0xFF00C853); // vivid green
  static const Color kGreenSoft = Color(0xFF00E676); // lighter accent

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final raw = _textCtrl.text.trim();
    if (raw.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _original = raw;
      _improved = null;
      _explanation = null;
    });

    const system = '''
You are a precise grammar corrector and rephraser.
Return STRICT JSON with these keys only:
- "improved": corrected, natural English; keep meaning; 1–3 sentences.
- "explanation": 1–3 short sentences describing the main fixes.
Do not include markdown, code fences, or extra text outside JSON.
''';

    try {
      final res = await BrainChannel.textOnly(
        system: system,
        user: raw,
        tag: 'GrammarCheck',
      );

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(res) as Map<String, dynamic>?;
      } catch (_) {
        // Fallback: try to extract a JSON block if model wrapped it.
        final start = res.indexOf('{');
        final end = res.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          data = jsonDecode(res.substring(start, end + 1)) as Map<String, dynamic>?;
        }
      }

      final improved = (data?['improved'] ?? '').toString().trim();
      final explanation = (data?['explanation'] ?? '').toString().trim();

      if (improved.isEmpty) {
        throw Exception('Empty improved text');
      }

      if (!mounted) return;
      setState(() {
        _improved = improved;
        _explanation = explanation.isEmpty
            ? "The text was polished for grammar, punctuation, and clarity."
            : explanation;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t generate right now. $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _copy() {
    final txt = _improved ?? _original ?? '';
    if (txt.isEmpty) return;
    Clipboard.setData(ClipboardData(text: txt));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  void _share() {
    final body = _improved ?? _original ?? '';
    if (body.isEmpty) return;
    final message = 'Grammar Check ✅\n\n$body';
    Share.share(message, subject: 'Grammar fix');
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final isLight = base.brightness == Brightness.light;

    // Local theme override: push green as primary just for this page.
    final themed = base.copyWith(
      colorScheme: cs.copyWith(primary: kGreen, secondary: kGreen),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: kGreen,
        foregroundColor: Colors.black,
      ),
    );

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grammar'),
          // removed the flag icon; only keep back & overflow if needed
          actions: [
            if ((_improved ?? '').isNotEmpty)
              IconButton(
                tooltip: 'Share',
                onPressed: _share,
                icon: const Icon(Icons.ios_share_rounded),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                'Which word or paragraph do you want to check grammar for?',
                style: base.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _InputCard(
                controller: _textCtrl,
                hint: 'Type or paste your text…',
                green: kGreen,
                isLight: isLight,
              ),
              const SizedBox(height: 14),
              _GenerateBar(
                onGenerate: _run,
                loading: _loading,
              ),
              const SizedBox(height: 18),
              if (_improved != null) _ResultCard(
                original: _original ?? '',
                improved: _improved ?? '',
                explanation: _explanation ?? '',
                onCopy: _copy,
                onShare: _share,
                green: kGreen,
                greenSoft: kGreenSoft,
                isLight: isLight,
                onRegenerate: _run,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final Color green;
  final bool isLight;

  const _InputCard({
    required this.controller,
    required this.hint,
    required this.green,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: green.withOpacity(.8), width: 2),
      borderRadius: BorderRadius.circular(18),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            green.withOpacity(.10),
            (isLight ? Colors.white : const Color(0xFF0F1216)),
          ],
        ),
        border: Border.all(color: green.withOpacity(.35), width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: controller,
        minLines: 6,
        maxLines: 14,
        style: base.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          isCollapsed: true,
          contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          hintStyle: base.textTheme.bodyMedium?.copyWith(
            color: isLight ? Colors.black54 : Colors.white60,
          ),
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: green, width: 2.2),
          ),
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _GenerateBar extends StatelessWidget {
  final VoidCallback onGenerate;
  final bool loading;
  const _GenerateBar({required this.onGenerate, required this.loading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onGenerate,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _GradientButton.bg,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ).merge(_GradientButton.style),
        child: loading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))
            : const Text('Generate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String original;
  final String improved;
  final String explanation;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;
  final bool loading;
  final Color green;
  final Color greenSoft;
  final bool isLight;

  const _ResultCard({
    required this.original,
    required this.improved,
    required this.explanation,
    required this.onCopy,
    required this.onShare,
    required this.onRegenerate,
    required this.loading,
    required this.green,
    required this.greenSoft,
    required this.isLight,
  });

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isLight ? const Color(0xFFF7FFF9) : const Color(0xFF0E1511),
        border: Border.all(color: green.withOpacity(.28), width: 2),
        boxShadow: [
          BoxShadow(
            color: green.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pill('Original', icon: Icons.error_outline_rounded, bg: Colors.red.withOpacity(.12), fg: Colors.red),
          const SizedBox(height: 8),
          Text(original, style: base.textTheme.bodyLarge?.copyWith(color: isLight ? Colors.black87 : Colors.white70)),
          const SizedBox(height: 14),
          _pill('Improve', icon: Icons.check_circle_rounded, bg: green.withOpacity(.16), fg: green),
          const SizedBox(height: 8),
          Text(
            improved,
            style: base.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isLight ? Colors.black : Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _pill('Explanation', icon: Icons.lightbulb_rounded, bg: greenSoft.withOpacity(.18), fg: greenSoft),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: base.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onRegenerate,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(color: green.withOpacity(.6), width: 2),
                    foregroundColor: isLight ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Copy',
                onPressed: onCopy,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: green.withOpacity(.45), width: 2),
                ),
                icon: const Icon(Icons.copy_rounded),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Share',
                onPressed: onShare,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: green.withOpacity(.45), width: 2),
                ),
                icon: const Icon(Icons.ios_share_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, {required IconData icon, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

/// Reusable gradient button style (green highlights)
class _GradientButton {
  static final ButtonStyle style = ButtonStyle(
    // Paint gradient as background using a MaterialStateProperty
    backgroundColor: MaterialStateProperty.resolveWith<Color>((states) => bg),
    shape: MaterialStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    overlayColor: MaterialStatePropertyAll(Colors.white.withOpacity(.08)),
  );

  static const Color bg = Color(0xFF00C853); // solid color (we tint with ink overlay)
}
