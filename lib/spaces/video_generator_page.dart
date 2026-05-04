import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../models/media_result.dart';
import '../services/curated_media_models.dart';
import '../services/media_api.dart';
import '../services/media_file_service.dart';
import '../services/media_input_helper.dart';
import '../services/media_history_store.dart';
import '../widgets/media_result_card.dart';
import '../widgets/model_history_sheet.dart';

class VideoGeneratorPage extends StatefulWidget {
  final MediaModel? initialModel;

  const VideoGeneratorPage({
    super.key,
    this.initialModel,
  });

  @override
  State<VideoGeneratorPage> createState() => _VideoGeneratorPageState();
}

class _VideoGeneratorPageState extends State<VideoGeneratorPage> {
  final TextEditingController _promptController = TextEditingController();

  late MediaModel _selectedModel;

  final List<GeneratedMediaItem> _results = [];
  final MediaHistoryStore _historyStore = MediaHistoryStore();

  bool _isGenerating = false;
  Timer? _generateTicker;
  DateTime? _generationStartedAt;
  int _elapsedSeconds = 0;

  final MediaInputHelper _mediaInputHelper = MediaInputHelper();
  PickedInputImage? _selectedInputImage;
  PickedInputAudio? _selectedInputAudio;

  bool get _supportsImageInput => _selectedModel.supportsImageUpload;
  bool get _supportsAudioInput => _selectedModel.supportsAudioInput;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.initialModel ?? videoModels.first;
    _loadSavedHistory();
    unawaited(_restoreActiveGeneration());
  }

  @override
  void dispose() {
    _generateTicker?.cancel();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickModel() async {
    final picked = await showModalBottomSheet<MediaModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SimpleVideoModelSheet(
        models: videoModels,
        selected: _selectedModel,
        title: 'Choose video model',
        subtitle: 'Pick a production-ready model for video generation.',
      ),
    );

    if (picked == null) return;

    setState(() {
      _selectedModel = picked;
      if (!_supportsImageInput) _selectedInputImage = null;
      _selectedInputAudio = null;
    });
    _loadSavedHistory();
  }


  void _startGenerateTimer() {
    _generateTicker?.cancel();
    _generationStartedAt = DateTime.now();
    _elapsedSeconds = 0;
    _generateTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _generationStartedAt == null) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_generationStartedAt!).inSeconds;
      });
    });
  }

  void _stopGenerateTimer() {
    _generateTicker?.cancel();
    _generateTicker = null;
    _generationStartedAt = null;
  }

  String get _generationStatusText {
    if (_elapsedSeconds < 4) return 'Preparing request';
    if (_elapsedSeconds < 24) return 'Generating video';
    return 'Finalizing result';
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      _showSnack('Enter a prompt first');
      return;
    }
    if (_isGenerating) {
      _showSnack('A video is already generating. Please wait.');
      return;
    }

    final input = <String, dynamic>{
      'mode': _selectedInputImage != null ? 'image_to_video' : 'text_to_video',
    };
    final inputUrls = _selectedInputImage == null ? const <String>[] : <String>[_selectedInputImage!.dataUrl];

    setState(() => _isGenerating = true);
    _startGenerateTimer();

    try {
      final startedAt = DateTime.now();
      final first = await MediaApi.startGeneration(
        MediaGenerationRequest(
          modelId: _selectedModel.id,
          category: 'video',
          prompt: prompt,
          input: input,
          inputUrls: inputUrls,
        ),
      );

      if (!first.processing) {
        await _handleCompletedResult(first, prompt: prompt, createdAt: startedAt);
        return;
      }

      final session = ActiveGenerationSession(
        category: 'video',
        modelId: _selectedModel.id,
        modelName: _selectedModel.name,
        prompt: prompt,
        predictionId: first.predictionId,
        startedAt: startedAt,
      );
      await _historyStore.saveActiveGeneration(session);
      await _resumeActiveGeneration(session);
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isGenerating = false);
      }
      _stopGenerateTimer();
      await _historyStore.clearActiveGeneration('video');
    }
  }

  Future<void> _restoreActiveGeneration() async {
    final session = await _historyStore.loadActiveGeneration('video');
    if (session == null) return;
    if (!mounted) return;
    _promptController.text = session.prompt;
    final restoredModel = videoModels.where((m) => m.id == session.modelId).toList();
    setState(() {
      _isGenerating = true;
      if (restoredModel.isNotEmpty) {
        _selectedModel = restoredModel.first;
      }
      _elapsedSeconds = DateTime.now().difference(session.startedAt).inSeconds;
    });
    _generationStartedAt = session.startedAt;
    _startGenerateTimer();
    await _resumeActiveGeneration(session);
  }

  Future<void> _resumeActiveGeneration(ActiveGenerationSession session) async {
    try {
      final result = await MediaApi.waitForCompletion(
        predictionId: session.predictionId,
        category: 'video',
        model: session.modelId,
      );
      await _handleCompletedResult(result, prompt: session.prompt, createdAt: session.startedAt);
    } catch (e) {
      await _historyStore.clearActiveGeneration('video');
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''));
        setState(() => _isGenerating = false);
      }
      _stopGenerateTimer();
    }
  }

  Future<void> _handleCompletedResult(
    MediaGenerationResult result, {
    required String prompt,
    required DateTime createdAt,
  }) async {
    var items = result.toGeneratedItems(
      prompt: prompt,
      modelName: _selectedModel.name,
      createdAt: createdAt,
    );
    items = await MediaFileService.cacheItemsLocally(items);
    items = items
        .map((item) => item.copyWith(
              prompt: prompt,
              metadata: {
                ...item.metadata,
                'displayPrompt': prompt,
                'originalPrompt': prompt,
              },
            ))
        .toList(growable: false);

    await _historyStore.prependItems(items);
    await _historyStore.clearActiveGeneration('video');

    if (!mounted) return;
    _stopGenerateTimer();
    setState(() {
      _isGenerating = false;
      _results.insertAll(0, items);
    });
    _showSnack('Video ready');
  }


    Future<void> _loadSavedHistory() async {
    try {
      final items = await _historyStore.loadByCategoryAndModel(
        'video',
        _selectedModel.id,
      );
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(items);
      });
    } catch (_) {}
  }

  Future<void> _deleteHistoryItem(GeneratedMediaItem item) async {
    setState(() {
      _results.removeWhere((e) =>
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
          category: 'video',
          modelId: _selectedModel.id,
          title: '${_selectedModel.name} history',
        ),
      ),
    );

    if (!mounted) return;
    await _loadSavedHistory();
  }

Future<void> _openInputPickerMenu() async {
    if (_isGenerating || !_selectedModel.supportsImageUpload) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take photo'), onTap: () => Navigator.pop(context, 'camera')),
              ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Gallery'), onTap: () => Navigator.pop(context, 'gallery')),
              ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: const Text('File'), onTap: () => Navigator.pop(context, 'file')),
            ],
          ),
        ),
      ),
    );

    Future<PickedInputImage?> Function()? picker;
    if (action == 'camera') picker = _mediaInputHelper.pickFromCamera;
    if (action == 'gallery') picker = _mediaInputHelper.pickFromGallery;
    if (action == 'file') picker = _mediaInputHelper.pickFromFile;
    if (picker == null) return;
    final picked = await picker();
    if (picked == null || !mounted) return;
    setState(() => _selectedInputImage = picked);
  }

  void _removeSelectedImage() {
    setState(() => _selectedInputImage = null);
  }

  Future<void> _openAudioPickerMenu() async {
    if (_isGenerating || !_supportsAudioInput) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.mic_rounded),
                title: const Text('Record voice'),
                subtitle: const Text('Record one short voice note'),
                onTap: () => Navigator.pop(context, 'record'),
              ),
              ListTile(
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Choose audio file'),
                subtitle: const Text('Use one MP3, WAV, M4A, AAC, OGG, or FLAC file'),
                onTap: () => Navigator.pop(context, 'file'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      PickedInputAudio? picked;
      if (action == 'record') {
        picked = await _recordVoiceFlow();
      } else if (action == 'file') {
        picked = await _mediaInputHelper.pickAudioFile();
      }
      if (picked == null || !mounted) return;
      setState(() => _selectedInputAudio = picked);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<PickedInputAudio?> _recordVoiceFlow() async {
    await _mediaInputHelper.startVoiceRecording();
    if (!mounted) return null;
    final picked = await showModalBottomSheet<PickedInputAudio?>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _RecordingVoiceSheet(helper: _mediaInputHelper),
    );
    return picked;
  }

  void _removeSelectedAudio() {
    setState(() => _selectedInputAudio = null);
  }

  int _parseInt(String raw, {required int fallback}) {
    return int.tryParse(raw.trim()) ?? fallback;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Video Generator',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: scheme.surfaceVariant.withOpacity(.24),
                border: Border.all(
                  color: scheme.outline.withOpacity(.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create videos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _supportsImageInput
                        ? 'Write a clear video prompt. Add one image only when the selected model supports image-to-video.'
                        : 'Write a clear prompt for motion, style, and camera movement.',
                    style: TextStyle(
                      height: 1.4,
                      color: scheme.onSurface.withOpacity(.68),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AbsorbPointer(
                    absorbing: _isGenerating,
                    child: _SelectedVideoModelCard(
                      model: _selectedModel,
                      onTap: _pickModel,
                    ),
                  ),
                  if (_supportsImageInput) ...[
                    const SizedBox(height: 14),
                    _InputPickerButton(
                      enabled: !_isGenerating,
                      hasImage: _selectedInputImage != null,
                      onTap: _openInputPickerMenu,
                    ),
                    const SizedBox(height: 12),
                    _SelectedInputPreview(
                      image: _selectedInputImage,
                      onRemove: _isGenerating || _selectedInputImage == null ? null : _removeSelectedImage,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _VideoPromptComposer(
                    controller: _promptController,
                    enabled: !_isGenerating,
                    supportsImageInput: _supportsImageInput,
                  ),
                  if (_isGenerating) ...[
                    const SizedBox(height: 14),
                    _GeneratingStatusCard(
                      status: _generationStatusText,
                      elapsedSeconds: _elapsedSeconds,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isGenerating ? null : _generate,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.videocam_rounded),
                          label: Text(
                            _isGenerating ? 'Generating • ${_elapsedSeconds}s' : 'Generate Video',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isGenerating ? null : _openHistorySheet,
                        icon: const Icon(Icons.history_rounded),
                        label: const Text('History'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Results',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Text(
                    '${_results.length}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  color: scheme.surfaceVariant.withOpacity(.20),
                  border: Border.all(
                    color: scheme.outline.withOpacity(.08),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.videocam_outlined,
                      size: 42,
                      color: scheme.onSurface.withOpacity(.5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No videos yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate your first video and it will show up here with quick preview, save, share, and regenerate actions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.4,
                        color: scheme.onSurface.withOpacity(.66),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _results
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: MediaResultCard(
                          key: ValueKey('${item.modelId}-${item.createdAt.microsecondsSinceEpoch}-${item.previewUrl}'),
                          item: item,
                          onRegenerate: () {
                            _promptController.text = (item.metadata['displayPrompt'] ?? item.metadata['originalPrompt'] ?? item.prompt).toString();
                            _generate();
                          },
                          onDelete: () => _deleteHistoryItem(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedVideoModelCard extends StatelessWidget {
  final MediaModel model;
  final VoidCallback onTap;

  const _SelectedVideoModelCard({
    required this.model,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: scheme.primary.withOpacity(.08),
          border: Border.all(
            color: scheme.primary.withOpacity(.16),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: scheme.primary.withOpacity(.12),
              ),
              child: Icon(
                Icons.videocam_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _VideoPromptComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool supportsImageInput;

  const _VideoPromptComposer({
    required this.controller,
    required this.enabled,
    required this.supportsImageInput,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: scheme.surface.withOpacity(.78),
        border: Border.all(color: scheme.outline.withOpacity(.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Video prompt',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            supportsImageInput
                ? 'Describe the motion and mood for this image.'
                : 'Describe the scene, motion, and camera feel.',
            style: TextStyle(
              height: 1.35,
              color: scheme.onSurface.withOpacity(.68),
              fontSize: 12.8,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            enabled: enabled,
            minLines: 5,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: supportsImageInput
                  ? 'Example: Slow cinematic push-in, gentle hair movement, warm sunset light'
                  : 'Example: Cinematic drone shot through a neon city at night',
              filled: true,
              fillColor: scheme.surfaceVariant.withOpacity(.22),
              contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: scheme.outline.withOpacity(.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: scheme.outline.withOpacity(.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: scheme.primary.withOpacity(.45), width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratingStatusCard extends StatelessWidget {
  final String status;
  final int elapsedSeconds;

  const _GeneratingStatusCard({
    required this.status,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withOpacity(.14),
            scheme.secondary.withOpacity(.08),
            scheme.surfaceVariant.withOpacity(.30),
          ],
        ),
        border: Border.all(color: scheme.primary.withOpacity(.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withOpacity(.12),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'This can take around 20–90 seconds depending on model and queue.',
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(.68),
                    height: 1.3,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${elapsedSeconds}s',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: scheme.primary,
                ),
              ),
              Text(
                'elapsed',
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(.62),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleVideoModelSheet extends StatefulWidget {
  final List<MediaModel> models;
  final MediaModel selected;
  final String title;
  final String subtitle;

  const _SimpleVideoModelSheet({
    required this.models,
    required this.selected,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_SimpleVideoModelSheet> createState() => _SimpleVideoModelSheetState();
}

class _SimpleVideoModelSheetState extends State<_SimpleVideoModelSheet> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() {
        _query = _search.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final models = widget.models.where((m) {
      if (_query.isEmpty) return true;
      final text = '${m.name} ${m.id} ${m.provider} ${m.badge}'.toLowerCase();
      return text.contains(_query);
    }).toList();

    final featured = models.where((m) => m.featured).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * .88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: scheme.onSurface.withOpacity(.68),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search video models...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceVariant.withOpacity(.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: scheme.outline.withOpacity(.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: scheme.outline.withOpacity(.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: scheme.primary.withOpacity(.35),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              children: [
                if (featured.isNotEmpty) ...[
                  const Text(
                    'Featured',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...featured.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VideoSheetModelTile(
                        model: m,
                        selected: m.id == widget.selected.id,
                        onTap: () => Navigator.pop(context, m),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'All Models',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...models.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _VideoSheetModelTile(
                      model: m,
                      selected: m.id == widget.selected.id,
                      onTap: () => Navigator.pop(context, m),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoSheetModelTile extends StatelessWidget {
  final MediaModel model;
  final bool selected;
  final VoidCallback onTap;

  const _VideoSheetModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? scheme.primary.withOpacity(.08)
              : scheme.surfaceVariant.withOpacity(.20),
          border: Border.all(
            color: selected
                ? scheme.primary.withOpacity(.30)
                : scheme.outline.withOpacity(.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: scheme.primary.withOpacity(.10),
              ),
              child: Icon(
                Icons.videocam_rounded,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface.withOpacity(.62),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if ((model.badge ?? '').trim().isNotEmpty)
                        _Pill(label: model.badge ?? ''),
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
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
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          color: scheme.primary,
        ),
      ),
    );
  }
}


class _InputPickerButton extends StatelessWidget {
  final bool enabled;
  final bool hasImage;
  final VoidCallback onTap;

  const _InputPickerButton({
    required this.enabled,
    required this.hasImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surfaceVariant.withOpacity(.18),
          border: Border.all(color: scheme.outline.withOpacity(.10)),
        ),
        child: Row(
          children: [
            Icon(Icons.add_photo_alternate_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasImage ? 'Change image' : 'Add image',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(.70)),
          ],
        ),
      ),
    );
  }
}

class _SelectedInputPreview extends StatelessWidget {
  final PickedInputImage? image;
  final VoidCallback? onRemove;

  const _SelectedInputPreview({
    required this.image,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceVariant.withOpacity(.18),
        border: Border.all(color: scheme.outline.withOpacity(.10)),
      ),
      child: image == null
          ? Row(
              children: [
                Icon(Icons.image_outlined, color: scheme.onSurface.withOpacity(.65)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No image selected',
                    style: TextStyle(color: scheme.onSurface.withOpacity(.72)),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(image!.previewPath!),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: scheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    image!.previewPath ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurface.withOpacity(.68),
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove image',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
    );
  }
}

class _RecordingVoiceSheet extends StatefulWidget {
  final MediaInputHelper helper;

  const _RecordingVoiceSheet({required this.helper});

  @override
  State<_RecordingVoiceSheet> createState() => _RecordingVoiceSheetState();
}

class _RecordingVoiceSheetState extends State<_RecordingVoiceSheet> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  PickedInputAudio? _recorded;
  bool _busy = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _recorded == null) {
        setState(() => _elapsed += const Duration(seconds: 1));
      }
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _stopRecording() async {
    if (_busy || _recorded != null) return;
    setState(() => _busy = true);
    try {
      final audio = await widget.helper.stopVoiceRecording();
      if (!mounted) return;
      setState(() => _recorded = audio);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePlayback() async {
    final audio = _recorded;
    if (audio == null) return;
    final path = audio.previewPath;
    if (path == null || path.trim().isEmpty) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _cancel() async {
    if (_recorded == null) {
      await widget.helper.cancelVoiceRecording();
    }
    if (mounted) Navigator.pop(context, null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasRecording = _recorded != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(.12),
              ),
              alignment: Alignment.center,
              child: Icon(
                hasRecording ? Icons.audio_file_rounded : Icons.mic_rounded,
                size: 34,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasRecording ? 'Preview voice note' : 'Recording voice…',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              hasRecording
                  ? 'Replay it before adding to the video.'
                  : 'Speak clearly. You can stop, preview, then add it.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurface.withOpacity(.72), height: 1.35),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: scheme.surfaceVariant.withOpacity(.22),
                border: Border.all(color: scheme.outline.withOpacity(.10)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!hasRecording) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(hasRecording ? (_recorded!.label) : _fmt(_elapsed), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (hasRecording)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _togglePlayback,
                      icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(_playing ? 'Pause preview' : 'Play preview'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _recorded),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Use this voice'),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _stopRecording,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceInputButton extends StatelessWidget {
  final bool enabled;
  final bool hasAudio;
  final VoidCallback onTap;

  const _VoiceInputButton({
    required this.enabled,
    required this.hasAudio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: scheme.surfaceVariant.withOpacity(.18),
          border: Border.all(color: scheme.outline.withOpacity(.10)),
        ),
        child: Row(
          children: [
            Icon(Icons.mic_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasAudio ? 'Change voice' : 'Add voice',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurface.withOpacity(.70),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedAudioPreview extends StatefulWidget {
  final PickedInputAudio? audio;
  final VoidCallback? onRemove;

  const _SelectedAudioPreview({
    required this.audio,
    this.onRemove,
  });

  @override
  State<_SelectedAudioPreview> createState() => _SelectedAudioPreviewState();
}

class _SelectedAudioPreviewState extends State<_SelectedAudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final path = widget.audio?.previewPath;
    if (path == null || path.trim().isEmpty) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final audio = widget.audio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: scheme.surfaceVariant.withOpacity(.18),
        border: Border.all(color: scheme.outline.withOpacity(.10)),
      ),
      child: audio == null
          ? Row(
              children: [
                Icon(Icons.audio_file_outlined, color: scheme.onSurface.withOpacity(.65)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No voice selected',
                    style: TextStyle(color: scheme.onSurface.withOpacity(.72)),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(.12),
                  ),
                  child: IconButton(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voice ready',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        audio.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withOpacity(.68),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onRemove != null)
                  IconButton(
                    tooltip: 'Remove voice',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
    );
  }
}

