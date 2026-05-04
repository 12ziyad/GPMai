import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageInfoPage extends StatelessWidget {
  final bool isUser;
  final String messageText;
  final DateTime time;

  // meta (optional)
  final String? model;
  final int? inputTokens;
  final int? outputTokens;
  final int? pointsCost;
  final double? usdCost;

  const MessageInfoPage({
    super.key,
    required this.isUser,
    required this.messageText,
    required this.time,
    this.model,
    this.inputTokens,
    this.outputTokens,
    this.pointsCost,
    this.usdCost,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;
    final f = DateFormat("MMM d, yyyy • h:mm a");

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(k,
                    style: TextStyle(
                      color: isLight ? Colors.black54 : Colors.white60,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Message info"),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.onSurface.withOpacity(.12)),
              color: cs.surfaceVariant.withOpacity(.10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser ? "Sent from you" : "Sent from GPM",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                Text(
                  messageText,
                  style: TextStyle(
                    color: isLight ? Colors.black87 : Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.onSurface.withOpacity(.12)),
            ),
            child: Column(
              children: [
                row("Time", f.format(time)),
                if (model != null) row("Model", model!),
                if (pointsCost != null) row("Cost (points)", "$pointsCost"),
                if (usdCost != null) row("Cost (USD)", "\$${usdCost!.toStringAsFixed(6)}"),
                if (inputTokens != null) row("Input tokens", "$inputTokens"),
                if (outputTokens != null) row("Output tokens", "$outputTokens"),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "Tip: this info is generated from our Worker metadata ✅",
            style: TextStyle(
              color: isLight ? Colors.black54 : Colors.white60,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
