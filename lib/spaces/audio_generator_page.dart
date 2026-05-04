import 'dart:async';

import 'package:flutter/material.dart';

import '../models/media_result.dart';
import '../services/audio_model_registry.dart';
import '../services/curated_media_models.dart';
import '../services/media_api.dart';
import '../services/media_history_store.dart';
import '../widgets/media_generate_sheet.dart';
import '../widgets/media_result_card.dart';
import '../widgets/model_history_sheet.dart';

class AudioGeneratorPage extends StatefulWidget {
  final CuratedMediaModel? initialModel;

  const AudioGeneratorPage({
    super.key,
    this.initialModel,
  });

  @override
  State<AudioGeneratorPage> createState() => _AudioGeneratorPageState();
}

class _AudioGeneratorPageState extends State<AudioGeneratorPage> {
  final TextEditingController _prompt = TextEditingController();
  final List<GeneratedMediaItem> _history = [];
  final MediaHistoryStore _historyStore = MediaHistoryStore();

  late CuratedMediaModel _selectedModel;

  bool _busy = false;
  String _selectedSpeaker = 'Aiden';
  String _selectedVoice = 'Rachel';
  String _voiceStyle = 'Female';

  @override
  void initState() {
    super.initState();
    final audioList = CuratedMediaCatalog.audioModels;

    if (widget.initialModel != null) {
      _selectedModel = widget.initialModel!;
    } else if (audioList.isNotEmpty) {
      _selectedModel = audioList.first;
    } else {
      _selectedModel = const CuratedMediaModel(
        id: 'audio/placeholder',
        name: 'Audio Model',
        provider: 'Replicate',
        category: MediaCategory.audio,
        description: 'Audio model',
      );
    }

    _syncStateForModel(_selectedModel);
    unawaited(_loadSavedHistory());
    unawaited(_restoreActiveGeneration());
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  AudioModelProfile get _profile =>
      AudioModelRegistry.profileForModel(_selectedModel);

  String get _mode => AudioModelRegistry.modeFor(_selectedModel);

  void _syncStateForModel(CuratedMediaModel model) {
    final profile = AudioModelRegistry.profileForModel(model);

    if (profile.speakerOptions.isNotEmpty) {
      _selectedSpeaker = profile.speakerOptions.first;
    } else {
      _selectedSpeaker = 'Aiden';
    }

    if (profile.voiceOptions.isNotEmpty) {
      _selectedVoice = profile.voiceOptions.first;
    } else {
      _selectedVoice = 'Rachel';
    }

    if (profile.voiceStyleOptions.isNotEmpty) {
      _voiceStyle = profile.voiceStyleOptions.first;
    } else {
      _voiceStyle = 'Female';
    }
  }

  String _voiceStyleHint(String style) {
    switch (style.toLowerCase()) {
      case 'male':
        return 'male';
      case 'female':
        return 'female';
      case 'child':
        return 'child';
      case 'narrator':
        return 'narrator';
      case 'calm':
        return 'calm';
      case 'energetic':
        return 'energetic';
      default:
        return style.toLowerCase();
    }
  }

  List<String> _supportTags(CuratedMediaModel model) {
    return AudioModelRegistry.supportTagsForModel(model);
  }

  Future<void> _pickModel() async {
    final models = CuratedMediaCatalog.audioModels;
    if (models.isEmpty) {
      _showSnack('No audio models found.');
      return;
    }

    final selected = await MediaGenerateSheet.open(
      context,
      models: models,
      selected: _selectedModel,
      title: 'Choose audio model',
      subtitle: 'Pick the best model for speech or music.',
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedModel = selected;
        _syncStateForModel(selected);
      });
      unawaited(_loadSavedHistory());
    }
  }

  Future<void> _generate() async {
    final rawPrompt = _prompt.text.trim();
    if (rawPrompt.isEmpty || _busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      final profile = _profile;
      final input = <String, dynamic>{};
      var finalPrompt = rawPrompt;

      final modelId = _selectedModel.id.toLowerCase();

      if (_mode == 'speech') {
        input['text'] = rawPrompt;

        if (profile.voiceControlType == VoiceControlType.speakerEnum) {
          input['speaker'] = _selectedSpeaker;
        } else if (profile.voiceControlType == VoiceControlType.voiceEnum) {
          input['voice'] = _selectedVoice;
        } else if (profile.voiceControlType == VoiceControlType.styleHint) {
          final voiceHint = _voiceStyleHint(_voiceStyle);
          input['voice'] = voiceHint;
          input['voice_style'] = voiceHint;
        }

        finalPrompt = rawPrompt;
      } else {
        if (modelId == 'minimax/music-1.5') {
          finalPrompt =
              'Create a polished music track with expressive vocals and clear musical structure. Song idea / lyrics: $rawPrompt';
        } else if (modelId == 'stability-ai/stable-audio-2.5') {
          finalPrompt =
              'Generate high-quality music/audio based on this idea: $rawPrompt';
        }

        input['prompt'] = finalPrompt;
        input['lyrics'] = rawPrompt;
      }

      final startedAt = DateTime.now();
      final first = await MediaApi.startGeneration(
        MediaGenerationRequest(
          modelId: _selectedModel.id,
          category: 'audio',
          prompt: finalPrompt,
          input: input,
        ),
      );

      if (!first.processing) {
        await _handleCompletedResult(first, prompt: finalPrompt, createdAt: startedAt);
        return;
      }

      final session = ActiveGenerationSession(
        category: 'audio',
        modelId: _selectedModel.id,
        modelName: _selectedModel.name,
        prompt: finalPrompt,
        predictionId: first.predictionId,
        startedAt: startedAt,
      );
      await _historyStore.saveActiveGeneration(session);
      await _resumeActiveGeneration(session);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      setState(() => _busy = false);
      await _historyStore.clearActiveGeneration('audio');
    }
  }

  Future<void> _restoreActiveGeneration() async {
    final session = await _historyStore.loadActiveGeneration('audio');
    if (session == null || !mounted) return;
    _prompt.text = session.prompt;
    setState(() {
      _busy = true;
      final matches = CuratedMediaCatalog.audioModels.where((m) => m.id == session.modelId);
      if (matches.isNotEmpty) {
        _selectedModel = matches.first;
        _syncStateForModel(_selectedModel);
      }
    });
    await _resumeActiveGeneration(session);
  }

  Future<void> _resumeActiveGeneration(ActiveGenerationSession session) async {
    try {
      final result = await MediaApi.waitForCompletion(
        predictionId: session.predictionId,
        category: 'audio',
        model: session.modelId,
      );
      await _handleCompletedResult(result, prompt: session.prompt, createdAt: session.startedAt);
    } catch (e) {
      await _historyStore.clearActiveGeneration('audio');
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _busy = false);
    }
  }

  Future<void> _handleCompletedResult(
    MediaGenerationResult result, {
    required String prompt,
    required DateTime createdAt,
  }) async {
    final items = result.toGeneratedItems(
      prompt: prompt,
      modelName: _selectedModel.name,
      createdAt: createdAt,
    );

    if (items.isEmpty) {
      throw Exception('No audio output returned by the backend.');
    }

    await _persistGeneratedItems(items);
    await _historyStore.clearActiveGeneration('audio');

    if (!mounted) return;

    setState(() {
      _history.insertAll(0, items);
      _busy = false;
    });

    final walletText = result.pointsBalanceAfter == null
        ? ''
        : '  Balance: ${result.pointsBalanceAfter}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Audio generated  ${result.pointsCost} points$walletText'),
      ),
    );
  }


  void _reusePrompt(GeneratedMediaItem item) {
    _prompt.text = item.prompt;
    _prompt.selection = TextSelection.fromPosition(
      TextPosition(offset: _prompt.text.length),
    );
    _showSnack('Prompt loaded');
  }
  Future<void> _loadSavedHistory() async {
    try {
      final items = await _historyStore.loadByCategoryAndModel('audio', _selectedModel.id);
      if (!mounted) return;
      setState(() {
        _history
          ..clear()
          ..addAll(items);
      });
    } catch (_) {}
  }

  Future<void> _persistGeneratedItems(List<GeneratedMediaItem> items) async {
    try {
      await _historyStore.prependItems(items);
    } catch (_) {}
  }
  Future<void> _deleteHistoryItem(GeneratedMediaItem item) async {
    setState(() {
      _history.removeWhere((e) =>
          e.previewUrl == item.previewUrl &&
          e.modelId == item.modelId &&
          e.createdAt == item.createdAt);
    });

    try {
      await _historyStore.deleteItem(item);
    } catch (_) {}
  }



  Future<void> _openHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .92,
        child: ModelHistorySheet(
          category: 'audio',
          modelId: _selectedModel.id,
          title: '${_selectedModel.name} history',
        ),
      ),
    );

    if (!mounted) return;
    await _loadSavedHistory();
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Widget _chip(String label) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: scheme.primary.withOpacity(.08),
        border: Border.all(
          color: scheme.primary.withOpacity(.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final scheme = Theme.of(context).colorScheme;
    final profile = _profile;

    final showSpeakerDropdown =
        _mode == 'speech' &&
        profile.voiceControlType == VoiceControlType.speakerEnum;

    final showVoiceEnumDropdown =
        _mode == 'speech' &&
        profile.voiceControlType == VoiceControlType.voiceEnum;

    final showVoiceStyleDropdown =
        _mode == 'speech' &&
        profile.voiceControlType == VoiceControlType.styleHint;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Audio Generator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mode == 'speech' ? 'Generate speech' : 'Generate music',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mode == 'speech'
                        ? 'Use exact speakers, exact voices, or simple TTS voice styles depending on the selected model.'
                        : 'Generate music from a prompt or lyric idea.',
                    style: TextStyle(
                      color: isLight ? Colors.black54 : Colors.white70,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _busy ? null : _pickModel,
                    child: Ink(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: scheme.primary.withOpacity(.18),
                        ),
                        color: scheme.primary.withOpacity(.06),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: scheme.primary.withOpacity(.14),
                            child: Icon(
                              Icons.graphic_eq_rounded,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedModel.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedModel.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isLight ? Colors.black54 : Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.expand_more_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _supportTags(_selectedModel).map(_chip).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (showSpeakerDropdown)
                    DropdownButtonFormField<String>(
                      value: _selectedSpeaker,
                      items: profile.speakerOptions
                          .map(
                            (speaker) => DropdownMenuItem(
                              value: speaker,
                              child: Text(speaker),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                                () => _selectedSpeaker =
                                    v ?? profile.speakerOptions.first,
                              ),
                      decoration: const InputDecoration(
                        labelText: 'Speaker',
                      ),
                    ),

                  if (showSpeakerDropdown) const SizedBox(height: 14),

                  if (showVoiceEnumDropdown)
                    DropdownButtonFormField<String>(
                      value: _selectedVoice,
                      items: profile.voiceOptions
                          .map(
                            (voice) => DropdownMenuItem(
                              value: voice,
                              child: Text(voice),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                                () => _selectedVoice =
                                    v ?? profile.voiceOptions.first,
                              ),
                      decoration: const InputDecoration(
                        labelText: 'Voice',
                      ),
                    ),

                  if (showVoiceEnumDropdown) const SizedBox(height: 14),

                  if (showVoiceStyleDropdown)
                    DropdownButtonFormField<String>(
                      value: _voiceStyle,
                      items: profile.voiceStyleOptions
                          .map(
                            (style) => DropdownMenuItem(
                              value: style,
                              child: Text(style),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(
                                () => _voiceStyle =
                                    v ?? profile.voiceStyleOptions.first,
                              ),
                      decoration: const InputDecoration(
                        labelText: 'Voice style',
                      ),
                    ),

                  if (showVoiceStyleDropdown) const SizedBox(height: 14),

                  TextField(
                    controller: _prompt,
                    enabled: !_busy,
                    maxLines: 5,
                    minLines: 4,
                    decoration: InputDecoration(
                      labelText: _mode == 'speech' ? 'What should it say?' : 'Song idea or lyrics',
                      hintText: _mode == 'speech'
                          ? 'Example: Hello there, welcome to GPMai'
                          : 'Example: Emotional pop song about chasing dreams under city lights',
                    ),
                  ),

                  if (_busy) ...[
                    const SizedBox(height: 12),
                    _AudioBusyBanner(),
                    const SizedBox(height: 16),
                  ] else
                    const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _generate,
                          icon: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.multitrack_audio_rounded),
                          label: Text(_busy ? 'Generating' : 'Generate audio'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _openHistorySheet,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('History'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Results',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_history.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      size: 44,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your generated audio will appear here',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Generate speech or music and manage the results here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isLight ? Colors.black54 : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._history.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MediaResultCard(
                  key: ValueKey('${item.predictionId ?? item.previewUrl}-${item.createdAt.microsecondsSinceEpoch}'),
                  item: item,
                  onRegenerate: () {
                    _prompt.text = item.prompt;
                    _generate();
                  },
                  onUseAsPrompt: () => _reusePrompt(item),
                onDelete: () => _deleteHistoryItem(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class _AudioBusyBanner extends StatelessWidget {
  const _AudioBusyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withOpacity(.18),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_top_rounded, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Generation in progress. Please wait for it to finish before starting another one.',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
