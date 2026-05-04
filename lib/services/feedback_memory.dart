// lib/services/feedback_memory.dart
enum MessageFeedback { none, like, dislike }

/// In-memory preference/feedback cache (no DB migration required).
class FeedbackMemory {
  // chatId -> preferred format ("brief" | "bullets" | "steps" | "code")
  static final Map<String, String> _prefByChat = {};

  // messageId -> like/dislike
  static final Map<int, MessageFeedback> _fbByMsg = {};

  // track speaking msg
  static int? speakingMsgId;

  static String? getPreferredFormat(String chatId) => _prefByChat[chatId];

  static void setPreferredFormat(String chatId, String format) {
    _prefByChat[chatId] = format;
  }

  static MessageFeedback feedbackFor(int messageId) =>
      _fbByMsg[messageId] ?? MessageFeedback.none;

  static void setFeedback(int messageId, MessageFeedback f) {
    _fbByMsg[messageId] = f;
  }
}

/// Tiny style detector for "like→remember" and "dislike→rewrite".
class FormatClassifier {
  static String detect(String text) {
    final t = text.trim();
    if (RegExp(r'```').hasMatch(t)) return 'code';
    if (RegExp(r'^\s*\d+\.\s', multiLine: true).hasMatch(t)) return 'steps';
    if (RegExp(r'^\s*[-*•]\s', multiLine: true).hasMatch(t)) return 'bullets';
    // very long single paragraph => maybe not brief
    if (t.length > 260 && !t.contains('\n')) return 'paragraph';
    return 'brief';
  }

  static String alternativeTo(String current) {
    switch (current) {
      case 'bullets':
      case 'steps':
      case 'code':
      case 'paragraph':
        return 'brief';
      default:
        return 'bullets';
    }
  }

  /// Text hint to append to the prompt.
  static String hintFor(String format) {
    switch (format) {
      case 'bullets':
        return 'Preferred format: • bullets (≤4), ≤12 words each.';
      case 'steps':
        return 'Preferred format: numbered steps (1–3), concise.';
      case 'code':
        return 'Preferred format: code block only when applicable.';
      default:
        return 'Preferred format: brief (≤2 sentences).';
    }
  }

  /// Rewrite instruction.
  static String rewriteInstr(String target) {
    switch (target) {
      case 'bullets':
        return 'Rewrite as ≤4 concise bullet points (•), ≤12 words each.';
      case 'steps':
        return 'Rewrite as 1–3 numbered steps, concise.';
      case 'code':
        return 'Rewrite as a code block if meaningful; otherwise keep it brief.';
      default:
        return 'Rewrite as one short paragraph (≤2 sentences).';
    }
  }
}
