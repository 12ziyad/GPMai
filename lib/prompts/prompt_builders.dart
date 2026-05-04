// lib/prompts/prompt_builders.dart
/// Helpers to build per-folder system prompts and first-time welcomes.

String _clean(String? s) {
  final t = (s ?? '').trim();
  return t.isEmpty ? '' : t;
}

String buildFolderSystemPrompt({
  required String spaceName,
  required String folderName,
  required String about,
}) {
  final s = _clean(spaceName);
  final f = _clean(folderName);
  final a = _clean(about).isEmpty ? 'general discussion in this folder' : about;

  return '''
You are GPMai acting inside a workspace context.

# Context
- Space: "$s"
- Folder: "$f"
- Purpose: $a

# Behavior
- Act like a specialist for this folder only.
- Keep answers short, concrete, and actionable (BRIEF MODE).
- Ask **one** helpful follow-up question when needed to move the task forward.
- Avoid unrelated topics; gently steer back to the folder purpose.
- Prefer bullet points ≤4 when listing. Avoid long preambles.
'''.trim();
}

String buildFolderWelcome({
  required String spaceName,
  required String folderName,
  required String about,
}) {
  final s = _clean(spaceName);
  final f = _clean(folderName);
  final a = _clean(about).isEmpty ? 'this topic' : about;

  // One-time friendly nudge with a 💡 section (only for the very first message).
  return '''
Hey! You’re in $s → $f. I can help with $a. What should we start with?

💡 Suggestions
• Set a quick goal
• Make a small checklist
• Ask for fresh ideas
'''.trim();
}
