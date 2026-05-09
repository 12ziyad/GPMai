import 'dart:math' as math;

import 'package:gpmai_clean/services/gpmai_brain.dart';

import 'curated_models.dart';
import 'debate_room_store.dart';

class DebateRunUpdate {
  final DebateRoomSession session;
  final String? toast;

  const DebateRunUpdate({required this.session, this.toast});
}

class DebateRoomEngine {
  static Future<DebateRoomSession> runSession({
    required DebateRoomSession initial,
    required Future<void> Function(DebateRunUpdate update) onUpdate,
    Future<DebateRoomSession?> Function()? loadLatestSession,
  }) async {
    final moderatorModel = _pickModeratorModel();

    var session = initial.copyWith(
      status: 'running',
      updatedAt: DateTime.now(),
      activeStage: 'Preparing Debate Room',
      liveWindowOpen: false,
      clearLiveEndsAt: true,
    );
    await onUpdate(
      DebateRunUpdate(session: session, toast: 'Opening Debate Room'),
    );

    final openingAnswers = <String, String>{};
    final liveMessages = <String, List<String>>{};
    final sharedDraftSuggestions = <String, String>{};
    final approvalReplies = <String, String>{};
    final consumedInterventionIds = <String>{};

    final depth = session.depth.toLowerCase();
    final openingWordBudget =
        depth == 'deep'
            ? 90
            : depth == 'fast'
            ? 55
            : 70;
    final discussionWordBudget =
        depth == 'deep'
            ? 60
            : depth == 'fast'
            ? 36
            : 48;
    final finalWordBudget =
        depth == 'deep'
            ? 90
            : depth == 'fast'
            ? 58
            : 72;
    final maxLiveMessages =
        depth == 'deep'
            ? 10
            : depth == 'fast'
            ? 5
            : 7;
    final liveWindow = Duration(
      seconds:
          depth == 'deep'
              ? 95
              : depth == 'fast'
              ? 45
              : 70,
    );
    final delayMs =
        depth == 'deep'
            ? 520
            : depth == 'fast'
            ? 320
            : 420;

    var eventCounter = session.events.length;
    DebateRoomEvent makeEvent({
      required int round,
      required String stage,
      required String type,
      String? modelId,
      String? provider,
      String? modelName,
      required String content,
    }) {
      eventCounter += 1;
      return DebateRoomEvent(
        id: '${session.id}_$eventCounter',
        round: round,
        stage: stage,
        type: type,
        modelId: modelId,
        provider: provider,
        modelName: modelName,
        content: content.trim(),
        createdAt: DateTime.now(),
      );
    }

    Future<void> mergeLatest() async {
      if (loadLatestSession == null) return;
      final latest = await loadLatestSession();
      if (latest == null) return;
      session = session.copyWith(
        title: latest.title,
        pinned: latest.pinned,
        events:
            latest.events.length > session.events.length
                ? latest.events
                : session.events,
        updatedAt:
            latest.updatedAt.isAfter(session.updatedAt)
                ? latest.updatedAt
                : session.updatedAt,
        liveWindowOpen: latest.liveWindowOpen,
        liveEndsAt: latest.liveEndsAt,
      );
    }

    Future<void> emitSession({String? toast}) async {
      await mergeLatest();
      session = session.copyWith(updatedAt: DateTime.now());
      await onUpdate(DebateRunUpdate(session: session, toast: toast));
    }

    Future<void> addEvent({
      required int round,
      required String stage,
      required String type,
      String? modelId,
      String? provider,
      String? modelName,
      required String content,
      String? activeStage,
      String? activeModelId,
      bool? liveWindowOpen,
      DateTime? liveEndsAt,
      bool clearLiveEndsAt = false,
      String? toast,
    }) async {
      await mergeLatest();
      session = session.copyWith(
        events: <DebateRoomEvent>[
          ...session.events,
          makeEvent(
            round: round,
            stage: stage,
            type: type,
            modelId: modelId,
            provider: provider,
            modelName: modelName,
            content: content,
          ),
        ],
        activeStage: activeStage ?? session.activeStage,
        activeModelId: activeModelId,
        liveWindowOpen: liveWindowOpen ?? session.liveWindowOpen,
        liveEndsAt: clearLiveEndsAt ? null : (liveEndsAt ?? session.liveEndsAt),
        updatedAt: DateTime.now(),
      );
      await onUpdate(DebateRunUpdate(session: session, toast: toast));
    }

    Future<String> moderatorCall(String prompt, {int maxTokens = 420}) {
      return _callModel(
        modelId: moderatorModel,
        systemPrompt: _moderatorSystemPrompt(session.outputStyle),
        userText: prompt,
        maxOutputTokens: maxTokens,
        temperature: 0.45,
      );
    }

    Future<void> processInterventions({required String stage}) async {
      await mergeLatest();
      final pending = session.events
          .where(
            (e) =>
                e.type == 'user_intervention' &&
                !consumedInterventionIds.contains(e.id),
          )
          .toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      for (final item in pending) {
        consumedInterventionIds.add(item.id);
        final note = await moderatorCall(
          _moderatorInterventionPrompt(
            question: session.question,
            note: item.content,
            transcript: _recentTranscript(session.events),
          ),
          maxTokens: 180,
        );
        await addEvent(
          round: 2,
          stage: stage,
          type: 'moderator',
          modelId: moderatorModel,
          provider: 'Moderator',
          modelName: 'Moderator',
          content: note,
          activeStage: stage,
          activeModelId: null,
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    await addEvent(
      round: 0,
      stage: 'Opening Views',
      type: 'system',
      content:
          'The panel is entering the room. Each selected model is giving one sharp opening take first.',
      activeStage: 'Opening Views',
      liveWindowOpen: false,
      clearLiveEndsAt: true,
    );

    for (final participant in session.participants) {
      final opening = await _callModel(
        modelId: participant.modelId,
        systemPrompt: _panelistSystemPrompt(
          displayName: participant.displayName,
          goal: session.goal,
          outputStyle: session.outputStyle,
          wordBudget: openingWordBudget,
        ),
        userText: _openingPrompt(session),
        maxOutputTokens: 240,
        temperature: 0.65,
      );
      openingAnswers[participant.modelId] = opening;
      liveMessages
          .putIfAbsent(participant.modelId, () => <String>[])
          .add(opening);
      await addEvent(
        round: 1,
        stage: 'Opening Views',
        type: 'opening',
        modelId: participant.modelId,
        provider: participant.provider,
        modelName: participant.displayName,
        content: opening,
        activeStage: 'Opening Views',
        activeModelId: participant.modelId,
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    final openingModeratorSummary = await moderatorCall(
      _moderatorOpeningSummaryPrompt(
        session: session,
        openingAnswers: openingAnswers,
      ),
      maxTokens: 260,
    );
    await addEvent(
      round: 1,
      stage: 'Moderator Summary',
      type: 'moderator',
      modelId: moderatorModel,
      provider: 'Moderator',
      modelName: 'Moderator',
      content: openingModeratorSummary,
      activeStage: 'Moderator Summary',
      activeModelId: null,
    );

    final liveEndsAt = DateTime.now().add(liveWindow);
    await addEvent(
      round: 2,
      stage: 'Live Panel Discussion',
      type: 'system',
      content:
          'LIVE panel discussion is open. The three models are now reacting to each other and trying to build one stronger shared direction.',
      activeStage: 'Live Panel Discussion',
      activeModelId: null,
      liveWindowOpen: true,
      liveEndsAt: liveEndsAt,
    );

    final speakerOrder = <DebateRoomParticipant>[
      ...session.participants,
      if (session.participants.length >= 3) session.participants[1],
      if (session.participants.isNotEmpty) session.participants[0],
      if (session.participants.length >= 3) session.participants[2],
      ...session.participants,
    ];

    var liveIndex = 0;
    while (liveIndex < maxLiveMessages && DateTime.now().isBefore(liveEndsAt)) {
      await processInterventions(stage: 'Live Panel Discussion');
      final participant = speakerOrder[liveIndex % speakerOrder.length];
      final transcript = _recentTranscript(session.events, maxItems: 8);
      final liveMessage = await _callModel(
        modelId: participant.modelId,
        systemPrompt: _panelistSystemPrompt(
          displayName: participant.displayName,
          goal: session.goal,
          outputStyle: session.outputStyle,
          wordBudget: discussionWordBudget,
        ),
        userText: _liveDiscussionPrompt(
          session: session,
          participant: participant,
          transcript: transcript,
          liveIndex: liveIndex + 1,
          remainingSeconds: math.max(
            0,
            liveEndsAt.difference(DateTime.now()).inSeconds,
          ),
        ),
        maxOutputTokens: 180,
        temperature: 0.78,
      );
      liveMessages
          .putIfAbsent(participant.modelId, () => <String>[])
          .add(liveMessage);
      await addEvent(
        round: 2,
        stage: 'Live Panel Discussion',
        type: 'live_message',
        modelId: participant.modelId,
        provider: participant.provider,
        modelName: participant.displayName,
        content: liveMessage,
        activeStage: 'Live Panel Discussion',
        activeModelId: participant.modelId,
        liveWindowOpen: true,
        liveEndsAt: liveEndsAt,
      );
      liveIndex += 1;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    await processInterventions(stage: 'Live Panel Discussion');

    final convergenceSummary = await moderatorCall(
      _moderatorConvergencePrompt(
        session: session,
        transcript: _recentTranscript(session.events, maxItems: 14),
      ),
      maxTokens: 260,
    );
    await addEvent(
      round: 2,
      stage: 'Moderator Summary',
      type: 'moderator',
      modelId: moderatorModel,
      provider: 'Moderator',
      modelName: 'Moderator',
      content: convergenceSummary,
      activeStage: 'Moderator Summary',
      activeModelId: null,
      liveWindowOpen: false,
      clearLiveEndsAt: true,
    );

    await addEvent(
      round: 3,
      stage: 'Shared Final Structure',
      type: 'system',
      content:
          'The live window is closed. Each model is now helping shape one final answer the whole panel can support.',
      activeStage: 'Shared Final Structure',
      activeModelId: null,
    );

    for (final participant in session.participants) {
      final proposal = await _callModel(
        modelId: participant.modelId,
        systemPrompt: _panelistSystemPrompt(
          displayName: participant.displayName,
          goal: session.goal,
          outputStyle: session.outputStyle,
          wordBudget: finalWordBudget,
        ),
        userText: _sharedStructurePrompt(
          session: session,
          participant: participant,
          transcript: _recentTranscript(session.events, maxItems: 14),
        ),
        maxOutputTokens: 220,
        temperature: 0.58,
      );
      sharedDraftSuggestions[participant.modelId] = proposal;
      await addEvent(
        round: 3,
        stage: 'Shared Final Structure',
        type: 'final_structure',
        modelId: participant.modelId,
        provider: participant.provider,
        modelName: participant.displayName,
        content: proposal,
        activeStage: 'Shared Final Structure',
        activeModelId: participant.modelId,
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    String draft = await moderatorCall(
      _moderatorDraftPrompt(
        session: session,
        transcript: _recentTranscript(session.events, maxItems: 18),
        sharedDraftSuggestions: sharedDraftSuggestions,
      ),
      maxTokens: 360,
    );

    await addEvent(
      round: 4,
      stage: 'Consensus Check',
      type: 'moderator',
      modelId: moderatorModel,
      provider: 'Moderator',
      modelName: 'Moderator',
      content:
          'I have a shared draft now. I am asking each model for approval or a correction only.',
      activeStage: 'Consensus Check',
      activeModelId: null,
    );

    var pass = 0;
    while (pass < 2) {
      approvalReplies.clear();
      for (final participant in session.participants) {
        final approval = await _callModel(
          modelId: participant.modelId,
          systemPrompt: _panelistSystemPrompt(
            displayName: participant.displayName,
            goal: session.goal,
            outputStyle: session.outputStyle,
            wordBudget: 36,
          ),
          userText: _approvalPrompt(
            session: session,
            participant: participant,
            draft: draft,
          ),
          maxOutputTokens: 90,
          temperature: 0.2,
        );
        approvalReplies[participant.modelId] = approval;
        await addEvent(
          round: 4,
          stage: 'Consensus Check',
          type: 'approval',
          modelId: participant.modelId,
          provider: participant.provider,
          modelName: participant.displayName,
          content: approval,
          activeStage: 'Consensus Check',
          activeModelId: participant.modelId,
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }

      final allApproved = approvalReplies.values.every(_isApproval);
      if (allApproved) {
        break;
      }
      draft = await moderatorCall(
        _moderatorRevisionPrompt(
          session: session,
          currentDraft: draft,
          approvalReplies: approvalReplies,
        ),
        maxTokens: 360,
      );
      await addEvent(
        round: 4,
        stage: 'Consensus Check',
        type: 'moderator',
        modelId: moderatorModel,
        provider: 'Moderator',
        modelName: 'Moderator',
        content:
            'A correction pass was needed. I revised the shared draft and ran one more approval check.',
        activeStage: 'Consensus Check',
        activeModelId: null,
      );
      pass += 1;
    }

    final approvedCount = approvalReplies.values.where(_isApproval).length;
    final finalSummary = await moderatorCall(
      _moderatorFinalCleanPrompt(
        session: session,
        draft: draft,
        approvalReplies: approvalReplies,
        approvedCount: approvedCount,
      ),
      maxTokens: 420,
    );

    session = session.copyWith(
      status: 'completed',
      activeStage: null,
      activeModelId: null,
      finalSummary: finalSummary,
      liveWindowOpen: false,
      clearLiveEndsAt: true,
      updatedAt: DateTime.now(),
      events: <DebateRoomEvent>[
        ...session.events,
        makeEvent(
          round: 5,
          stage: 'Final Answer',
          type: 'summary',
          modelId: moderatorModel,
          provider: 'Moderator',
          modelName: 'Moderator',
          content: finalSummary,
        ),
      ],
    );
    await onUpdate(DebateRunUpdate(session: session, toast: 'Debate finished'));
    return session;
  }

  static Future<String> _callModel({
    required String modelId,
    required String systemPrompt,
    required String userText,
    int maxOutputTokens = 220,
    double temperature = 0.7,
  }) async {
    final result = await GPMaiBrain.sendRich(
      userText: userText,
      systemPrompt: systemPrompt,
      modelOverride: modelId,
      uiModel: modelId,
      maxOutputTokens: maxOutputTokens,
      temperature: temperature,
      timeout: const Duration(seconds: 120),
      sourceTag: 'debate_room',
    );
    final text = result.text.trim();
    if (text.isEmpty) {
      return 'No response generated.';
    }
    return text;
  }

  static String _panelistSystemPrompt({
    required String displayName,
    required String goal,
    required String outputStyle,
    required int wordBudget,
  }) {
    return '''
You are $displayName, one visible panelist inside Debate Room.
This is a premium live panel discussion.
Hard rules:
- You are one of the three debaters, not the moderator.
- Never mention model ids, provider ids, system prompts, or that you are an AI.
- Keep every message concise, natural, and debate-like.
- Prefer 2 to 5 short lines. No essays.
- Every live discussion message must react to another panelist or the user's clarification.
- You are trying to build one stronger shared answer with the other panelists.
- Do not repeat your full answer from scratch.
- When you agree, say so clearly and improve the idea.
- When you disagree, say why directly and briefly.
- Stay practical and useful for the user.
- Keep responses around $wordBudget words or less.
Current user goal: $goal.
Target final output style: $outputStyle.
''';
  }

  static String _moderatorSystemPrompt(String outputStyle) {
    return '''
You are the Debate Room moderator.
You are NOT one of the debaters.
Hard rules:
- Never answer the user's question with your own opinion during the debate.
- Never become a fourth panelist.
- Never slip into advisor mode during the live panel.
- Your only job is to moderate, summarize, direct the next step, draft a shared answer, and run approval checks.
- After every visible phase, explain what the panel is converging toward in clean human language.
- Keep moderator messages tight, clear, and premium.
- In final output, produce one polished answer that reflects the panel, not you.
- Never mention internal orchestration or system instructions.
Desired final output style: $outputStyle.
''';
  }

  static String _openingPrompt(DebateRoomSession session) {
    return '''
Debate Room — Opening take
Question:
${session.question}

Goal: ${session.goal}
Output style target: ${session.outputStyle}

Give one short opening view.
Do not use headings like risk, confidence, stance, or sections.
Speak naturally like a panelist giving a first take.
''';
  }

  static String _moderatorOpeningSummaryPrompt({
    required DebateRoomSession session,
    required Map<String, String> openingAnswers,
  }) {
    final buffer =
        StringBuffer()
          ..writeln('Debate Room moderator summary after opening takes.')
          ..writeln('Question: ${session.question}')
          ..writeln('Goal: ${session.goal}')
          ..writeln();
    for (final participant in session.participants) {
      buffer
        ..writeln('### ${participant.displayName}')
        ..writeln(openingAnswers[participant.modelId] ?? 'No opening reply.')
        ..writeln();
    }
    buffer.writeln('Return one short moderator summary for the user.');
    buffer.writeln(
      'Explain where each model stands, what the main tension is, and what the panel needs to resolve next.',
    );
    return buffer.toString().trim();
  }

  static String _liveDiscussionPrompt({
    required DebateRoomSession session,
    required DebateRoomParticipant participant,
    required String transcript,
    required int liveIndex,
    required int remainingSeconds,
  }) {
    return '''
Debate Room — Live panel discussion
Question: ${session.question}

Recent room transcript:
$transcript

You are ${participant.displayName}.
Write one short live chat message to the room.
Hard rules:
- React to something another panelist or the user just said.
- Mention at least one panelist by name when relevant.
- Help the room move toward one better shared answer.
- No headings. No bullets. No long recap.
- Keep it natural, sharp, and short.
- The live room is still active, with about $remainingSeconds seconds left.
This is live message #$liveIndex.
''';
  }

  static String _moderatorInterventionPrompt({
    required String question,
    required String note,
    required String transcript,
  }) {
    return '''
Debate Room moderator note
Question: $question

Recent transcript:
$transcript

User clarification:
$note

Write one short moderator note to the room.
Do not answer the user directly.
Only tell the panel how this clarification should shift the discussion.
''';
  }

  static String _moderatorConvergencePrompt({
    required DebateRoomSession session,
    required String transcript,
  }) {
    return '''
Debate Room moderator summary after the live panel discussion.
Question: ${session.question}

Transcript:
$transcript

Write one short moderator summary.
Explain what the panel now seems to agree on, what still needs tightening, and what final structure the models should build next.
Do not answer the user's question yourself.
''';
  }

  static String _sharedStructurePrompt({
    required DebateRoomSession session,
    required DebateRoomParticipant participant,
    required String transcript,
  }) {
    return '''
Debate Room — Shared final structure pass
Question: ${session.question}
Goal: ${session.goal}
Output style: ${session.outputStyle}

Room transcript:
$transcript

You are ${participant.displayName}.
Propose the best final answer structure the whole panel could support.
Do not restate the entire debate.
Keep it concise and collaborative.
Focus on the shared answer, not your solo answer.
''';
  }

  static String _moderatorDraftPrompt({
    required DebateRoomSession session,
    required String transcript,
    required Map<String, String> sharedDraftSuggestions,
  }) {
    final buffer =
        StringBuffer()
          ..writeln('Debate Room moderator shared draft request')
          ..writeln('Question: ${session.question}')
          ..writeln('Goal: ${session.goal}')
          ..writeln('Output style: ${session.outputStyle}')
          ..writeln()
          ..writeln('Recent transcript:')
          ..writeln(transcript)
          ..writeln();

    for (final participant in session.participants) {
      buffer
        ..writeln('### ${participant.displayName} suggested shared structure')
        ..writeln(
          sharedDraftSuggestions[participant.modelId] ?? 'No suggestion.',
        )
        ..writeln();
    }

    buffer.writeln('Draft one clean final answer for the user.');
    buffer.writeln('Do not add commentary about moderation.');
    buffer.writeln('Make it sound like the panel built it together.');
    return buffer.toString().trim();
  }

  static String _approvalPrompt({
    required DebateRoomSession session,
    required DebateRoomParticipant participant,
    required String draft,
  }) {
    return '''
Debate Room — Approval check
Question: ${session.question}

Shared draft:
$draft

You are ${participant.displayName}.
Reply in only one of these forms:
APPROVE
or
CORRECTION: <one short correction only>
Do not explain anything else.
''';
  }

  static String _moderatorRevisionPrompt({
    required DebateRoomSession session,
    required String currentDraft,
    required Map<String, String> approvalReplies,
  }) {
    final buffer =
        StringBuffer()
          ..writeln('Debate Room moderator revision pass')
          ..writeln('Question: ${session.question}')
          ..writeln()
          ..writeln('Current draft:')
          ..writeln(currentDraft)
          ..writeln();

    for (final participant in session.participants) {
      buffer
        ..writeln('### ${participant.displayName}')
        ..writeln(approvalReplies[participant.modelId] ?? 'APPROVE')
        ..writeln();
    }

    buffer.writeln(
      'Revise the draft only where needed so it better reflects the panel.',
    );
    buffer.writeln('Keep it clean and user-ready.');
    return buffer.toString().trim();
  }

  static String _moderatorFinalCleanPrompt({
    required DebateRoomSession session,
    required String draft,
    required Map<String, String> approvalReplies,
    required int approvedCount,
  }) {
    final buffer =
        StringBuffer()
          ..writeln('Debate Room final clean answer')
          ..writeln('Question: ${session.question}')
          ..writeln('Output style: ${session.outputStyle}')
          ..writeln(
            'Approved count: $approvedCount of ${session.participants.length}',
          )
          ..writeln()
          ..writeln('Draft:')
          ..writeln(draft)
          ..writeln();

    for (final participant in session.participants) {
      buffer
        ..writeln('### ${participant.displayName} approval')
        ..writeln(approvalReplies[participant.modelId] ?? 'APPROVE')
        ..writeln();
    }

    buffer.writeln('Return markdown with these sections only:');
    buffer.writeln('## Final Answer');
    buffer.writeln('## What The Panel Agreed On');
    buffer.writeln('## Best Next Move');
    buffer.writeln('## Consensus Status');
    buffer.writeln(
      'In Consensus Status, mention if all 3 models approved or if one final correction remained.',
    );
    return buffer.toString().trim();
  }

  static String _recentTranscript(
    List<DebateRoomEvent> events, {
    int maxItems = 10,
  }) {
    final visible = events
        .where((e) => e.type != 'system' && e.type != 'summary')
        .toList(growable: false);
    final recent =
        visible.length <= maxItems
            ? visible
            : visible.sublist(visible.length - maxItems);
    final buffer = StringBuffer();
    for (final event in recent) {
      final name =
          (event.modelName ?? event.provider ?? 'Room').trim().isEmpty
              ? 'Room'
              : (event.modelName ?? event.provider ?? 'Room');
      buffer.writeln('$name: ${_compress(event.content)}');
    }
    return buffer.toString().trim();
  }

  static bool _isApproval(String raw) {
    final text = raw.trim().toLowerCase();
    return text == 'approve' ||
        text.startsWith('approve\n') ||
        text.startsWith('approve ');
  }

  static String _compress(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 260) return cleaned;
    return '${cleaned.substring(0, 260).trim()}…';
  }

  static String _pickModeratorModel() {
    // Production routing: prefer Claude first.
    const candidates = <String>[
      'anthropic/claude-opus-4.6',
      'anthropic/claude-sonnet-4.6',
      'anthropic/claude-opus-4.5',
      'anthropic/claude-sonnet-4.5',
      'anthropic/claude-sonnet-4',
      'anthropic/claude-3.7-sonnet',
      'openai/gpt-5-mini',
    ];
    for (final id in candidates) {
      if (findCuratedModelById(id) != null) return id;
    }
    return 'openai/gpt-5-mini';
  }

  static String makeTitle(String question) {
    final cleaned = question.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 56) return cleaned;
    return '${cleaned.substring(0, math.min(cleaned.length, 56)).trim()}…';
  }
}
