// lib/screens/chat_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart' as arc; // for .docx
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf; // for .pdf
import 'package:xml/xml.dart' as xml; // for .docx
import 'package:shared_preferences/shared_preferences.dart';

import '../services/feedback_memory.dart';
import '../services/gpmai_brain.dart';
import '../services/model_prefs.dart';
import '../services/sql_chat_store.dart';
import '../prompts/bots_prompts.dart';
import '../services/custom_personas_service.dart';
import '../services/curated_models.dart';
import '../services/curated_media_models.dart';
import '../services/media_api.dart';
import '../services/provider_branding.dart';
import 'voice_chat_page.dart';
import '../widgets/markdown_bubble.dart';
import '../widgets/expandable_textbox.dart';
import '../services/research_canvas_store.dart';
import '../widgets/save_to_canvas_sheet.dart';
import '../widgets/auto_prompt_chips.dart';
import '../widgets/memory_mode_chip.dart';
import 'memory_hub_page.dart';

class _InlineImage {
  final String mime;
  final Uint8List bytes;
  const _InlineImage(this.mime, this.bytes);
}

class _ParsedInline {
  final String text;
  final List<_InlineImage> images;
  const _ParsedInline(this.text, this.images);
}

class _ParsedRemoteMedia {
  final String text;
  final List<String> imageUrls;
  final List<String> otherUrls;

  const _ParsedRemoteMedia({
    required this.text,
    required this.imageUrls,
    required this.otherUrls,
  });
}

class ChatPage extends StatefulWidget {
  final String userId;
  final String chatId;
  final String chatName;
  final String? systemPrompt;
  final String? welcome;
  final String? seedUserText;
  final String? prefillInput;
  final List<AttachmentSeed>? initialAttachments;
  final bool autoSendInitialAttachments;
  final bool showMathShortcuts;

  const ChatPage({
    super.key,
    required this.userId,
    required this.chatId,
    required this.chatName,
    this.systemPrompt,
    this.welcome,
    this.seedUserText,
    this.initialAttachments,
    this.autoSendInitialAttachments = false,
    this.showMathShortcuts = false,
    this.prefillInput,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

enum GenerateState { idle, sending, generating }
enum _AttachKind { image, file }

class _Attachment {
  final _AttachKind kind;
  final String name;
  final Uint8List? bytes;
  const _Attachment.image({required this.name, this.bytes}) : kind = _AttachKind.image;
  const _Attachment.file({required this.name, this.bytes}) : kind = _AttachKind.file;
}

class AttachmentSeed {
  final String name;
  final Uint8List bytes;
  final bool isImage;
  const AttachmentSeed.image({required this.name, required this.bytes}) : isImage = true;
  const AttachmentSeed.file({required this.name, required this.bytes}) : isImage = false;
}

class _ChatPageState extends State<ChatPage> {
  static const int _kTurns = 6;
  static const int _kMaxChars = 1000;
  static const int _kMaxAttach = 3;
  static const Color _electricBlue = Color(0xFF00B8FF);

  final SqlChatStore _store = SqlChatStore();
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focus = FocusNode();
  final ImagePicker _picker = ImagePicker();

  bool _isListening = false;
  String _lastSpeechWords = '';
  bool _userUsedVoice = false;
  bool _showScrollToBottom = false;
  GenerateState _state = GenerateState.idle;
  bool _cancelRequested = false;

  final List<_Attachment> _attachments = [];
  _AttachKind? _attachMode;
  final Map<int, List<_InlineImage>> _inlineImageCache = {};
  bool _didInitialAutoScroll = false;

  late SharedPreferences _prefs;
  bool _prefsReady = false;
  String _selectedModelId = ModelPrefs.fallbackModelId;
  String _selectedModelLabel = 'GPT-5 Mini';
  String? _presetSystemPrompt;
  String? _presetWelcome;
  IconData? _personaAvatarIcon;
  String? _personaAvatarEmoji;
  Color? _personaAvatarColor;

  OverlayEntry? _chipEntry;
  bool _autoContinueArmed = false;

  static const String _kPlanStart = '<<PLAN>>';
  static const String _kPlanEnd = '<<ENDPLAN>>';
  static const String _kMetaStart = '<<META>>';
  static const String _kMetaEnd = '<<ENDMETA>>';

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final atBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (mounted) setState(() => _showScrollToBottom = !atBottom);
    });

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      _tts.setCompletionHandler(() {
        FeedbackMemory.speakingMsgId = null;
        if (mounted) setState(() {});
      });
      _tts.setCancelHandler(() {
        FeedbackMemory.speakingMsgId = null;
        if (mounted) setState(() {});
      });
      _tts.setErrorHandler((_) {
        FeedbackMemory.speakingMsgId = null;
        if (mounted) setState(() {});
      });
    } catch (_) {}

    _initPrefsAndModel();
    _bootstrapIfEmpty();

    final p = widget.prefillInput?.trim();
    if (p != null && p.isNotEmpty) {
      _controller.text = p;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      _focus.requestFocus();
    }

    final seeds = widget.initialAttachments;
    if (seeds != null && seeds.isNotEmpty) {
      final remaining = _kMaxAttach;
      final take = seeds.take(remaining);
      final firstIsImage = take.first.isImage;
      for (final s in take) {
        if (s.isImage != firstIsImage) continue;
        if (s.isImage) {
          _attachments.add(_Attachment.image(name: s.name, bytes: s.bytes));
          _attachMode ??= _AttachKind.image;
        } else {
          _attachments.add(_Attachment.file(name: s.name, bytes: s.bytes));
          _attachMode ??= _AttachKind.file;
        }
      }
      if (widget.autoSendInitialAttachments) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendMessage(_controller.text);
        });
      }
    }
  }

  Future<void> _initPrefsAndModel() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _prefsReady = true;

      final chat = await _store.getChat(widget.chatId);
      String? presetModelId;
      String? presetModelName;
      bool presetIsPersona = false;

      if (chat?.presetJson != null && chat!.presetJson!.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(chat.presetJson!) as Map<String, dynamic>;
          presetModelId = decoded['modelId']?.toString();
          presetModelName = decoded['modelName']?.toString();
          final kind = decoded['kind']?.toString();
          presetIsPersona = kind == 'persona' || kind == 'custom_persona';
          if (kind == 'persona') {
            final personaId = decoded['personaId']?.toString() ?? '';
            final style = decoded['responseStyle']?.toString();
            final persona = personaById(personaId);
            _presetSystemPrompt = buildPersonaSystemPrompt(personaId, customStyle: style);
            _presetWelcome = persona?.greeting;
            _personaAvatarIcon = persona?.icon;
            _personaAvatarColor = persona?.accent;
          } else if (kind == 'custom_persona') {
            final style = decoded['responseStyle']?.toString();
            final raw = decoded['customPersona'];
            if (raw is Map) {
              final cp = CustomPersona.fromJson(Map<String, dynamic>.from(raw));
              _presetSystemPrompt = buildCustomPersonaSystemPrompt(name: cp.name, description: cp.description, behaviorPrompt: cp.behaviorPrompt, responseStyle: style);
              _presetWelcome = cp.greeting;
              _personaAvatarIcon = cp.icon;
              _personaAvatarEmoji = cp.emoji;
              _personaAvatarColor = cp.accent;
            }
          }
        } catch (_) {}
      }

      final perChatKey = _chatModelKey(widget.chatId);
      final savedForChat = _prefs.getString(perChatKey);
      final globalSaved = await ModelPrefs.getSelected();

      final chosenRaw = [
        presetModelId,
        savedForChat,
        globalSaved,
        ModelPrefs.fallbackModelId,
      ].firstWhere((e) => e != null && e.trim().isNotEmpty)!;

      final resolvedChat = findCuratedModelById(chosenRaw) ??
          findCuratedModelByAnyKey(chosenRaw) ??
          findCuratedModelByAnyKey(presetModelName ?? '');
      final resolvedMedia = CuratedMediaCatalog.findById(chosenRaw);

      if (resolvedChat != null) {
        _selectedModelId = resolvedChat.id;
        _selectedModelLabel = presetIsPersona && (presetModelName?.trim().isNotEmpty == true) ? presetModelName!.trim() : resolvedChat.displayName;
        GPMaiBrain.defaultUiModel = resolvedChat.id;
      } else if (resolvedMedia != null) {
        _selectedModelId = resolvedMedia.id;
        _selectedModelLabel = resolvedMedia.name;
      } else {
        final fallback = await ModelPrefs.getSelectedModel();
        _selectedModelId = fallback.id;
        _selectedModelLabel = fallback.displayName;
        GPMaiBrain.defaultUiModel = fallback.id;
      }

      if (_prefsReady) {
        await _prefs.setString(perChatKey, _selectedModelId);
      }
      await ModelPrefs.setSelected(_selectedModelId);

      if (mounted) setState(() {});
    } catch (_) {
      final fallback = findCuratedModelById(ModelPrefs.fallbackModelId) ?? curatedOfficialModels.first;
      _selectedModelId = fallback.id;
      _selectedModelLabel = fallback.displayName;
      GPMaiBrain.defaultUiModel = _selectedModelId;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _chipEntry?.remove();
    _controller.dispose();
    _scrollController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _bootstrapIfEmpty() async {
    try {
      final existing = await _store.watchMessages(widget.chatId).first;
      if (existing.isNotEmpty) return;

      final w = (widget.welcome ?? _presetWelcome)?.trim();
      if (w != null && w.isNotEmpty) {
        await _store.addMessage(chatId: widget.chatId, role: 'gpm', text: w);
      }
      final seed = widget.seedUserText?.trim();
      if (seed != null && seed.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await _sendMessage(seed);
      }
    } catch (_) {}
  }


  String _chatModelKey(String chatId) => 'chat_model_id:$chatId';

  String _providerForModelId(String modelId) {
    final chatModel = findCuratedModelByAnyKey(modelId) ?? findCuratedModelById(modelId);
    if (chatModel != null) return chatModel.provider;
    final mediaModel = CuratedMediaCatalog.findById(modelId);
    if (mediaModel != null) return mediaModel.provider;
    return '';
  }

  Color _assistantAccentColor([Map<String, dynamic>? meta]) {
    if (_personaAvatarColor != null) return _personaAvatarColor!;
    final modelId = (meta?['usedUiModel'] ?? meta?['uiModelKey'] ?? _selectedModelId).toString();
    final label = (meta?['usedUiModelLabel'] ?? meta?['uiModelLabel'] ?? _selectedModelLabel).toString();
    final provider = _providerForModelId(modelId);
    return ProviderBranding.resolve(provider: provider, modelId: modelId, displayName: label).accent;
  }

  Color _assistantSurfaceColor([Map<String, dynamic>? meta]) {
    final modelId = (meta?['usedUiModel'] ?? meta?['uiModelKey'] ?? _selectedModelId).toString();
    final label = (meta?['usedUiModelLabel'] ?? meta?['uiModelLabel'] ?? _selectedModelLabel).toString();
    final provider = _providerForModelId(modelId);
    return ProviderBranding.resolve(provider: provider, modelId: modelId, displayName: label)
        .responseSurface(Theme.of(context).brightness);
  }

  Future<void> _setModelIdForThisChat(String modelId) async {
    final resolvedChat = findCuratedModelById(modelId) ??
        findCuratedModelByAnyKey(modelId);
    final resolvedMedia = CuratedMediaCatalog.findById(modelId);

    if (resolvedChat != null) {
      setState(() {
        _selectedModelId = resolvedChat.id;
        _selectedModelLabel = resolvedChat.displayName;
      });

      if (_prefsReady) {
        await _prefs.setString(_chatModelKey(widget.chatId), resolvedChat.id);
      }
      await ModelPrefs.setSelected(resolvedChat.id);
      GPMaiBrain.defaultUiModel = resolvedChat.id;
      return;
    }

    if (resolvedMedia != null) {
      setState(() {
        _selectedModelId = resolvedMedia.id;
        _selectedModelLabel = resolvedMedia.name;
      });

      if (_prefsReady) {
        await _prefs.setString(_chatModelKey(widget.chatId), resolvedMedia.id);
      }
      await ModelPrefs.setSelected(resolvedMedia.id);
      return;
    }

    final fallback = await ModelPrefs.getSelectedModel();
    setState(() {
      _selectedModelId = fallback.id;
      _selectedModelLabel = fallback.displayName;
    });
    if (_prefsReady) {
      await _prefs.setString(_chatModelKey(widget.chatId), fallback.id);
    }
    await ModelPrefs.setSelected(fallback.id);
    GPMaiBrain.defaultUiModel = fallback.id;
  }

  CuratedMediaModel? get _selectedMediaModel => CuratedMediaCatalog.findById(_selectedModelId);
  bool get _isMediaChat => _selectedMediaModel != null;

  void _showSoftChip(String text) {
    _chipEntry?.remove();
    _chipEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          left: 14,
          right: 14,
          top: MediaQuery.of(ctx).size.height * 0.68,
          child: IgnorePointer(
            ignoring: true,
            child: const Material(color: Colors.transparent),
          ),
        );
      },
    );

    final overlay = Overlay.of(context);
    if (overlay == null) return;
    overlay.insert(_chipEntry!);
    Future.delayed(const Duration(milliseconds: 2000), () {
      _chipEntry?.remove();
      _chipEntry = null;
    });
  }

  String _fallbackChipText() {
    final i = DateTime.now().millisecondsSinceEpoch % 3;
    if (i == 0) return 'Optimizing engine for stabilityâ€¦';
    if (i == 1) return 'Switching to a fast engineâ€¦';
    return 'Balancing speed & qualityâ€¦';
  }

  Future<void> _maybeAutoName(String firstUserText) async {
    String t = firstUserText.trim();
    if (t.isEmpty) return;
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    if (t.length > 32) t = '${t.substring(0, 32)}â€¦';
    try {
      await _store.rename(widget.chatId, t);
    } catch (_) {}
  }

  Future<void> _autoTitleAfterTurns() async {
    try {
      final msgs = await _store.watchMessages(widget.chatId).first;
      if (msgs.length < 4) return;
      final chat = await _store.getChat(widget.chatId);
      if (chat == null) return;
      final current = chat.name.trim();
      if (current.isNotEmpty &&
          current != 'New Chat' &&
          current.length > 3 &&
          !current.endsWith('â€¦')) return;

      final slice = msgs.length > 6 ? msgs.sublist(msgs.length - 6) : msgs;
      final convo =
          slice.map((m) => '${m.role == "user" ? "User" : "GPMai"}: ${m.text}').join('\n');

      final prompt = '''
Create a very short, specific chat title (â‰¤5 words). Title Case. No quotes.
If unclear, pick the clearest task/topic.
Conversation excerpt:
$convo
'''.trim();

      final r = await GPMaiBrain.sendRich(
        userId: widget.userId,
        chatId: '${widget.chatId}__utility_auto_title',
        uiModel: _selectedModelId,
        userText: prompt,
        systemPrompt: widget.systemPrompt,
        sourceTag: 'utility:auto_title',
      );

      String t = r.text.replaceAll('\n', ' ').trim();
      if (t.isEmpty) return;
      if (t.length > 30) t = t.substring(0, 30);
      await _store.rename(widget.chatId, t);
    } catch (_) {}
  }

  Future<String> _buildMemoryTranscript() async {
    try {
      final msgs = await _store.watchMessages(widget.chatId).first;
      if (msgs.isEmpty) return '';
      final take = (_kTurns * 2);
      final slice = msgs.length <= take ? msgs : msgs.sublist(msgs.length - take);

      String trim(String s) => (s.length <= _kMaxChars) ? s : '${s.substring(0, _kMaxChars)}â€¦';

      final lines = <String>[];
      for (final m in slice) {
        final who = (m.role == 'user') ? 'User' : 'GPMai';
        lines.add('$who: ${trim(m.text)}');
      }
      return lines.join('\n\n');
    } catch (_) {
      return '';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  ({Map<String, dynamic>? meta, String body}) _extractMetaFromText(String s) {
    final start = s.indexOf(_kMetaStart);
    final end = s.indexOf(_kMetaEnd);
    if (start >= 0 && end > start) {
      final raw = s.substring(start + _kMetaStart.length, end).trim();
      final before = s.substring(0, start).trimRight();
      final after = s.substring(end + _kMetaEnd.length).trimLeft();
      final body = (before.isEmpty) ? after : (after.isEmpty ? before : '$before\n\n$after');

      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return (meta: decoded, body: body.trim());
        }
      } catch (_) {}
      return (meta: null, body: body.trim());
    }
    return (meta: null, body: s);
  }


  String _cleanCanvasText(String? raw) {
    final source = (raw ?? '').trim();
    if (source.isEmpty) return '';
    final extracted = _extractMetaFromText(source);
    final body = extracted.body.trim();
    if (body.isNotEmpty) return body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (source.startsWith(_kMetaStart)) {
      final close = source.indexOf('}');
      if (close != -1 && close + 1 < source.length) {
        return source.substring(close + 1).replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return source.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _encodeMetaIntoText({required Map<String, dynamic> meta, required String body}) {
    final j = jsonEncode(meta);
    if (body.trim().isEmpty) {
      return '$_kMetaStart$j$_kMetaEnd';
    }
    return '$_kMetaStart$j$_kMetaEnd\n\n$body';
  }

  int _estimateTokensFromText(String s) {
    final len = s.trim().length;
    if (len <= 0) return 0;
    return math.max(1, (len / 4).ceil());
  }

  bool _canAddOfKind(_AttachKind kind, int incomingCount) {
    if (_attachments.isNotEmpty && _attachMode != null && _attachMode != kind) {
      _toast('Pick either photos or files (max $_kMaxAttach). Clear to switch.');
      return false;
    }
    if (_attachments.length >= _kMaxAttach) {
      _toast('You can attach up to $_kMaxAttach items.');
      return false;
    }
    final remaining = _kMaxAttach - _attachments.length;
    if (incomingCount > remaining) {
      _toast('Only $remaining more allowed.');
    }
    return true;
  }

  String _guessImageMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    return 'image/png';
  }

  String _dataUrlFromBytes(Uint8List bytes, String mime) {
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  String _asDataUrl(Uint8List bytes, String name) {
    final mime = _guessImageMime(name);
    return _dataUrlFromBytes(bytes, mime);
  }

  Future<String> _extractPdfText(Uint8List? bytes) async {
    if (bytes == null) return '';
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      final text = sf.PdfTextExtractor(doc).extractText();
      doc.dispose();
      final trimmed = text.trim();
      return trimmed.length > 12000 ? '${trimmed.substring(0, 12000)}â€¦' : trimmed;
    } catch (_) {
      return '';
    }
  }

  Future<String> _extractDocxText(Uint8List? bytes) async {
    if (bytes == null) return '';
    try {
      final zip = arc.ZipDecoder().decodeBytes(bytes, verify: false);
      arc.ArchiveFile? entry;
      for (final f in zip.files) {
        if (f.name == 'word/document.xml') {
          entry = f;
          break;
        }
      }
      if (entry == null) return '';
      final content = entry.content;
      String xmlStr = '';
      if (content is List<int>) {
        xmlStr = utf8.decode(content, allowMalformed: true);
      } else if (content is Uint8List) {
        xmlStr = utf8.decode(content, allowMalformed: true);
      } else {
        xmlStr = content?.toString() ?? '';
      }
      if (xmlStr.isEmpty) return '';
      final doc = xml.XmlDocument.parse(xmlStr);
      final buf = StringBuffer();
      for (final p in doc.findAllElements('w:p')) {
        final line = p.findAllElements('w:t').map((t) => t.text).join();
        final trimmed = line.replaceAll('\t', ' ').trim();
        if (trimmed.isNotEmpty) buf.writeln(trimmed);
      }
      final out = buf.toString().trim();
      return out.length > 12000 ? '${out.substring(0, 12000)}â€¦' : out;
    } catch (_) {
      return '';
    }
  }

  Future<void> _addFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;

      if (!_canAddOfKind(_AttachKind.file, result.files.length)) return;

      final remaining = _kMaxAttach - _attachments.length;
      final list = result.files
          .map((f) {
            final ext = (f.extension ?? '').toLowerCase();
            final img = ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp';
            if (img) {
              return _Attachment.image(name: f.name, bytes: f.bytes);
            } else {
              return _Attachment.file(name: f.name, bytes: f.bytes);
            }
          })
          .take(remaining)
          .toList();

      if (!mounted) return;
      setState(() {
        _attachments.addAll(list);
        _attachMode ??= _AttachKind.file;
      });
    } catch (e) {
      _toast('File picker error: $e');
    }
  }

  void _removeAttachment(int i) {
    setState(() => _attachments.removeAt(i));
    if (_attachments.isEmpty) _attachMode = null;
  }

  Widget _attachmentPreview() {
    if (_attachments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 4),
        itemCount: _attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = _attachments[i];
          final isImg = a.kind == _AttachKind.image;
          final box = Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: isImg && a.bytes != null
                ? Image.memory(a.bytes!, fit: BoxFit.cover)
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.insert_drive_file_rounded, size: 32, color: Colors.white70),
                    ),
                  ),
          );

          return Stack(
            children: [
              box,
              Positioned(
                right: 4,
                top: 4,
                child: InkWell(
                  onTap: () => _removeAttachment(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<_InlineImage> _extractInlineImagesFromText(String s) {
    final reg = RegExp(r'data:(image\/[a-zA-Z0-9.+-]+);base64,([A-Za-z0-9\/+==]+)');
    final matches = reg.allMatches(s);
    final out = <_InlineImage>[];
    for (final m in matches) {
      final mime = m.group(1)!;
      final b64 = m.group(2)!;
      out.add(_InlineImage(mime, base64Decode(b64)));
    }
    return out;
  }

  _ParsedInline _parseInlineImagesCached(int messageId, String s) {
    final reg = RegExp(r'data:(image\/[a-zA-Z0-9.+-]+);base64,([A-Za-z0-9\/+==]+)');
    if (_inlineImageCache.containsKey(messageId)) {
      final cleaned = s.replaceAll(reg, '').trim();
      return _ParsedInline(cleaned, _inlineImageCache[messageId]!);
    }
    final images = <_InlineImage>[];
    for (final m in reg.allMatches(s)) {
      final mime = m.group(1)!;
      final b64 = m.group(2)!;
      images.add(_InlineImage(mime, base64Decode(b64)));
    }
    _inlineImageCache[messageId] = images;
    final cleaned = s.replaceAll(reg, '').trim();
    return _ParsedInline(cleaned, images);
  }

  ({String? plan, String body}) _extractPlanFromText(String s) {
    final start = s.indexOf(_kPlanStart);
    final end = s.indexOf(_kPlanEnd);
    if (start == 0 && end > start) {
      final plan = s.substring(_kPlanStart.length, end).trim();
      final rest = s.substring(end + _kPlanEnd.length).trim();
      return (plan: plan.isEmpty ? null : plan, body: rest);
    }
    return (plan: null, body: s);
  }

  String _encodePlanIntoText({required String plan, required String body}) {
    return '$_kPlanStart\n$plan\n$_kPlanEnd\n\n$body';
  }

  bool _looksLikeImageUrl(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp') ||
        u.endsWith('.gif');
  }

  String _normalizeUrlToken(String raw) {
    return raw
        .trim()
        .replaceAll(RegExp(r'^[<\(\[\{]+'), '')
        .replaceAll(RegExp(r'[>\)\]\},.!?;:]+$'), '');
  }

  _ParsedRemoteMedia _extractRemoteMedia({
    required String text,
    Map<String, dynamic>? meta,
  }) {
    final imageUrls = <String>[];
    final otherUrls = <String>[];
    final seen = <String>{};

    void addUrl(String raw) {
      final url = _normalizeUrlToken(raw);
      if (url.isEmpty || !url.startsWith('http')) return;
      if (!seen.add(url)) return;

      if (_looksLikeImageUrl(url)) {
        imageUrls.add(url);
      } else {
        otherUrls.add(url);
      }
    }

    final metaUrls = meta?['outputUrls'];
    if (metaUrls is List) {
      for (final u in metaUrls) {
        if (u != null) addUrl(u.toString());
      }
    }

    final reg = RegExp(r'https?:\/\/[^\s<>()]+', caseSensitive: false);
    for (final m in reg.allMatches(text)) {
      final url = m.group(0);
      if (url != null) addUrl(url);
    }

    String cleaned = text;
    for (final url in imageUrls) {
      cleaned = cleaned.replaceAll(url, '');
    }

    cleaned = cleaned
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();

    return _ParsedRemoteMedia(
      text: cleaned,
      imageUrls: imageUrls,
      otherUrls: otherUrls,
    );
  }

  String _buildMediaReplyText(MediaGenerationResult result) {
    final media = _selectedMediaModel;
    final title = media?.name ?? result.modelId;
    final category = media?.categoryLabel ?? result.category;
    final urls = result.outputUrls;

    final b = StringBuffer()
      ..writeln('Generated $category with **$title** âœ…')
      ..writeln('')
      ..writeln('- Provider: ${result.provider}')
      ..writeln('- Status: ${result.status}')
      ..writeln('- Points used: ${result.pointsCost}')
      ..writeln('- Cost: \$${result.usdCost.toStringAsFixed(3)}');

    if (result.pointsBalanceAfter != null) {
      b.writeln('- Wallet after: ${result.pointsBalanceAfter}');
    }

    if (urls.isNotEmpty) {
      b.writeln('');
      b.writeln('Output:');
      for (final url in urls) {
        b.writeln(url);
      }
    }

    return b.toString().trim();
  }

  Future<void> _sendMediaGeneration({
    required String prompt,
    required int attachCountSent,
  }) async {
    final media = _selectedMediaModel;
    if (media == null) throw Exception('Selected media model not found');

    final result = await MediaApi.generate(
      MediaGenerationRequest(
        modelId: media.id,
        category: media.categoryKey,
        prompt: prompt,
      ),
    );

    final replyText = _buildMediaReplyText(result);
    final botMeta = <String, dynamic>{
      'role': 'gpm',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'chatId': widget.chatId,
      'uiModelKey': media.id,
      'uiModelLabel': media.name,
      'usedUiModel': media.id,
      'usedUiModelLabel': media.name,
      'fallback': false,
      'cooldown': false,
      'attachmentsUsed': attachCountSent,
      'estTokens': _estimateTokensFromText(replyText),
      'provider': result.provider,
      'category': result.category,
      'predictionId': result.predictionId,
      'usdCost': result.usdCost,
      'pointsCost': result.pointsCost,
      'pricingSource': result.pricingSource ?? '',
      'pricingVersion': result.pricingVersion ?? '',
      'outputUrls': result.outputUrls,
    };

    final botStoredText = _encodeMetaIntoText(meta: botMeta, body: replyText);
    await _store.addMessage(chatId: widget.chatId, role: 'gpm', text: botStoredText);
  }

  Future<void> _sendMessage(String raw, {String? promptChipLabel}) async {
    if (_state != GenerateState.idle) return;

    final text = raw.trim();
    final hasAny = text.isNotEmpty || _attachments.isNotEmpty;
    if (!hasAny) return;

    setState(() {
      _state = GenerateState.sending;
      _cancelRequested = false;
      _autoContinueArmed = true;
    });

    _controller.clear();
    _userUsedVoice = _isListening;

    try {
      if (text.isNotEmpty) await _maybeAutoName(text);
    } catch (_) {}

    final imageDataUrls = <String>[];
    final nonImageNames = <String>[];
    for (final a in _attachments) {
      if (a.kind == _AttachKind.image && a.bytes != null) {
        imageDataUrls.add(_asDataUrl(a.bytes!, a.name));
      } else if (a.kind == _AttachKind.file) {
        nonImageNames.add(a.name);
      }
    }

    String visibleText = text;
    if (imageDataUrls.isNotEmpty) {
      final glue = visibleText.isEmpty ? '' : '\n\n';
      visibleText = '$visibleText$glue${imageDataUrls.join('\n\n')}';
    }
    if (nonImageNames.isNotEmpty) {
      visibleText = '$visibleText\n\n(Attachments: ${nonImageNames.join(", ")})';
    }

    final userMeta = <String, dynamic>{
      'role': 'user',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'chatId': widget.chatId,
      'uiModelKey': _selectedModelId,
      'uiModelLabel': _selectedModelLabel,
      'attachments': _attachments.length,
      'estTokens': _estimateTokensFromText(visibleText),
      if (promptChipLabel != null && promptChipLabel.trim().isNotEmpty) 'promptChipLabel': promptChipLabel.trim(),
    };

    final userStoredText = _encodeMetaIntoText(
      meta: userMeta,
      body: visibleText.isEmpty ? '(no text)' : visibleText,
    );

    await _store.addMessage(
      chatId: widget.chatId,
      role: 'user',
      text: userStoredText,
    );

    _jumpToBottom();
    setState(() => _state = GenerateState.generating);

    final pref = FeedbackMemory.getPreferredFormat(widget.chatId);
    final prefHint = (pref == null) ? '' : '\n${FormatClassifier.hintFor(pref)}';

    final attachmentGuide = _attachments.isEmpty
        ? ''
        : '\nThe user attached ${_attachments.length} item(s). Use them if relevant.';

    const behaviorHint = '''
Style rules:
- Be clear, friendly, and not dry.
- Avoid one-line answers unless the user asked for super-short.
- After answering, ask ONE short follow-up question (unless the user said â€œno questionsâ€).
- If the output is long, you may continue in next messages smoothly.
''';

    // Send only the latest user turn; Worker owns history/context.
    final composedUser = text.isEmpty
        ? '(Attachment uploaded)$attachmentGuide'
        : '$text$attachmentGuide';

    final parts = <Map<String, dynamic>>[];

    for (final a in _attachments) {
      if (a.kind == _AttachKind.image && a.bytes != null) {
        parts.add({
          'type': 'image_url',
          'image_url': {'url': _asDataUrl(a.bytes!, a.name)},
        });
      } else if (a.kind == _AttachKind.file) {
        final lower = a.name.toLowerCase();
        if (lower.endsWith('.pdf')) {
          final tx = await _extractPdfText(a.bytes);
          parts.add({
            'type': 'text',
            'text': tx.isNotEmpty
                ? '[Attachment: ${a.name}]\n\n$tx'
                : '[Attachment: ${a.name}] (PDF could not be read.)',
          });
        } else if (lower.endsWith('.docx')) {
          final tx = await _extractDocxText(a.bytes);
          parts.add({
            'type': 'text',
            'text': tx.isNotEmpty
                ? '[Attachment: ${a.name}]\n\n$tx'
                : '[Attachment: ${a.name}] (DOCX could not be read.)',
          });
        } else if (lower.endsWith('.txt') && a.bytes != null) {
          final txt = utf8.decode(a.bytes!, allowMalformed: true);
          parts.add({'type': 'text', 'text': '[Attachment: ${a.name}]\n\n$txt'});
        } else {
          parts.add({
            'type': 'text',
            'text':
                '[Attachment: ${a.name}] (File type not parsed. Provide summary only if asked.)'
          });
        }
      }
    }

    if (text.isNotEmpty) {
      final inlines = _extractInlineImagesFromText(text);
      for (final img in inlines) {
        parts.add({
          'type': 'image_url',
          'image_url': {'url': _dataUrlFromBytes(img.bytes, img.mime)},
        });
      }
    }

    final attachCountSent = _attachments.length;
    setState(() {
      _attachments.clear();
      _attachMode = null;
    });

    if (_isMediaChat) {
      try {
        await _sendMediaGeneration(
          prompt: text.isEmpty ? 'Generate something creative.' : text,
          attachCountSent: attachCountSent,
        );
      } catch (e) {
        final replyText = '[Media Error] $e';
        final botMeta = <String, dynamic>{
          'role': 'gpm',
          'ts': DateTime.now().millisecondsSinceEpoch,
          'chatId': widget.chatId,
          'uiModelKey': _selectedModelId,
          'uiModelLabel': _selectedModelLabel,
          'usedUiModel': _selectedModelId,
          'usedUiModelLabel': _selectedModelLabel,
          'fallback': false,
          'cooldown': false,
          'attachmentsUsed': attachCountSent,
          'estTokens': _estimateTokensFromText(replyText),
        };
        final botStoredText = _encodeMetaIntoText(meta: botMeta, body: replyText);
        await _store.addMessage(chatId: widget.chatId, role: 'gpm', text: botStoredText);
      }

      if (mounted) {
        setState(() {
          _state = GenerateState.idle;
          _userUsedVoice = false;
          _autoContinueArmed = false;
        });
      }
      _scrollToBottom();
      return;
    }

    final mergedSystem = [
      if ((widget.systemPrompt ?? _presetSystemPrompt) != null && (widget.systemPrompt ?? _presetSystemPrompt)!.trim().isNotEmpty)
        (widget.systemPrompt ?? _presetSystemPrompt)!.trim(),
      'If the user asks what model/engine you are, do NOT mention any model names, ids, numbers, or versions. '
          'Instead say you are using a fast, high-quality engine optimized for this app.',
      behaviorHint.trim(),
      if (prefHint.isNotEmpty) prefHint.trim(),
    ].join('\n\n');

    BrainResult r;
    try {
      r = await GPMaiBrain.sendRich(
        userId: widget.userId,
        chatId: widget.chatId,
        uiModel: _selectedModelId,
        userText: composedUser,
        systemPrompt: mergedSystem,
        contentParts: parts.isEmpty ? null : parts,
      );
    } catch (e) {
      r = BrainResult(text: '[Error] $e', fallback: false, cooldown: false);
    }

    if (_cancelRequested) {
      if (mounted) setState(() => _state = GenerateState.idle);
      return;
    }

    if (r.fallback) {
      _showSoftChip(_fallbackChipText());
    }

    String replyText = r.text.trim();
    if (replyText.isEmpty) {
      replyText = 'â€¦';
    }

    final shouldShowPlanPanel = r.plan != null && r.plan!.trim().isNotEmpty;
    if (shouldShowPlanPanel) {
      replyText = _encodePlanIntoText(plan: r.plan!.trim(), body: replyText);
    }

    final usedResolved = findCuratedModelByAnyKey(r.usedUiModel) ??
        findCuratedModelById(r.usedUiModel) ??
        findCuratedModelById(_selectedModelId) ??
        await ModelPrefs.getSelectedModel();

    final botMeta = <String, dynamic>{
      'role': 'gpm',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'chatId': widget.chatId,
      'uiModelKey': _selectedModelId,
      'uiModelLabel': _selectedModelLabel,
      'usedUiModel': r.usedUiModel,
      'usedUiModelLabel': usedResolved.displayName,
      'fallback': r.fallback,
      'cooldown': r.cooldown,
      'attachmentsUsed': attachCountSent,
      'estTokens': _estimateTokensFromText(replyText),
      if (r.raw['_gpmai'] != null) 'workerGpmai': r.raw['_gpmai'],
    };

    final botStoredText = _encodeMetaIntoText(meta: botMeta, body: replyText);
    await _store.addMessage(chatId: widget.chatId, role: 'gpm', text: botStoredText);

    unawaited(_autoTitleAfterTurns());

    if (_userUsedVoice) {
      try {
        await _tts.speak(r.text);
        FeedbackMemory.speakingMsgId = -1;
        if (mounted) setState(() {});
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _state = GenerateState.idle;
        _userUsedVoice = false;
      });
    }

    _scrollToBottom();

    if (!r.cooldown && _autoContinueArmed) {
      _autoContinueArmed = false;
      final looksCut = _looksTruncated(r.text);
      if (looksCut) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await _sendMessage('Continue from where you stopped. Do not repeat earlier content.');
      }
    }
  }

  bool _looksTruncated(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    final openFences = RegExp(r'```').allMatches(t).length;
    if (openFences.isOdd) return true;
    if (t.endsWith(':') || t.endsWith('-') || t.endsWith('â€¢')) return true;
    final lines = t.split('\n');
    if (t.length > 900 && lines.isNotEmpty && lines.last.trim().length < 12) {
      return true;
    }
    return false;
  }

  void _stopGenerating() {
    _cancelRequested = true;
    setState(() => _state = GenerateState.idle);
  }

  Future<void> _startListening() async {
    if (_state == GenerateState.generating) return;
    if (_isListening || _speech.isListening) {
      await _stopListeningAndSend();
      return;
    }

    _lastSpeechWords = '';
    final available = await _speech.initialize(
      onStatus: (status) async {
        final done = status == 'done' || status == 'notListening';
        if (!mounted) return;
        setState(() => _isListening = !done);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _isListening = false);
      },
    );

    if (available) {
      setState(() => _isListening = true);
      await _speech.listen(
        partialResults: true,
        onResult: (val) {
          _lastSpeechWords = val.recognizedWords;
          if (mounted) setState(() {});
          if (val.finalResult) {
            _speech.stop();
            if (mounted) setState(() => _isListening = false);
            if (_lastSpeechWords.trim().isNotEmpty) {
              _sendMessage(_lastSpeechWords.trim());
              _lastSpeechWords = '';
            }
          }
        },
      );
    }
  }

  Future<void> _stopListeningAndSend() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) setState(() => _isListening = false);
    final words = _lastSpeechWords.trim();
    _lastSpeechWords = '';
    if (words.isNotEmpty) {
      await _sendMessage(words);
    }
  }

  Future<void> _addFromCamera() async {
    try {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 92);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!_canAddOfKind(_AttachKind.image, 1)) return;
      if (!mounted) return;
      setState(() {
        _attachments.add(_Attachment.image(name: shot.name.isEmpty ? 'camera.jpg' : shot.name, bytes: bytes));
        _attachMode ??= _AttachKind.image;
      });
    } catch (e) {
      _toast('Camera error: $e');
    }
  }

  Future<void> _addFromGallery() async {
    try {
      final shot = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!_canAddOfKind(_AttachKind.image, 1)) return;
      if (!mounted) return;
      setState(() {
        _attachments.add(_Attachment.image(name: shot.name.isEmpty ? 'gallery.jpg' : shot.name, bytes: bytes));
        _attachMode ??= _AttachKind.image;
      });
    } catch (e) {
      _toast('Gallery error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final screenWidth = MediaQuery.of(context).size.width;

    Color userBg() => isLight ? const Color(0xFFEFF8FF) : const Color(0xFF0F1218);
    Color aiBg() => isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22);
    Color userText() => isLight ? Colors.black87 : Colors.white;
    Color aiText() => isLight ? Colors.black87 : Colors.white;

    final speaking = FeedbackMemory.speakingMsgId != null;
    final hasPayload = _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
    final modelLabel = _selectedModelLabel;

    Widget likeDislikeRow({required int messageId, required bool isUser, required String? botText, String? originalQuestion}) {
      if (isUser) return const SizedBox.shrink();
      final fb = FeedbackMemory.feedbackFor(messageId);
      final inactive = Theme.of(context).textTheme.bodySmall?.color ?? Colors.white70;
      Widget actionItem({required IconData icon, required String label, required VoidCallback? onTap, Color? color, bool active = false}) {
        final tint = color ?? (active ? _electricBlue : inactive);
        return Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Icon(icon, size: 22, color: tint),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(top: 6, left: 52),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                actionItem(
                  icon: fb == MessageFeedback.like ? Icons.thumb_up : Icons.thumb_up_outlined,
                  label: 'Like',
                  color: fb == MessageFeedback.like ? _electricBlue : inactive,
                  onTap: () {
                    FeedbackMemory.setFeedback(messageId, MessageFeedback.like);
                    if (botText != null) {
                      final style = FormatClassifier.detect(botText);
                      FeedbackMemory.setPreferredFormat(widget.chatId, style);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thanks! I’ll keep this style.')),
                    );
                    setState(() {});
                  },
                ),
                actionItem(
                  icon: fb == MessageFeedback.dislike ? Icons.thumb_down : Icons.thumb_down_outlined,
                  label: 'Dislike',
                  color: fb == MessageFeedback.dislike ? Colors.redAccent : inactive,
                  onTap: () {
                    FeedbackMemory.setFeedback(messageId, MessageFeedback.dislike);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Noted. Trying a better format…')),
                    );
                    setState(() {});
                  },
                ),
                actionItem(
                  icon: Icons.auto_awesome_mosaic_rounded,
                  label: 'Canvas',
                  onTap: botText == null || botText.trim().isEmpty
                      ? null
                      : () => _saveMessageToCanvas(
                            messageText: botText,
                            originalQuestion: originalQuestion,
                          ),
                ),
                actionItem(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onTap: botText == null || botText.trim().isEmpty
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: botText));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied')),
                          );
                        },
                ),
                actionItem(
                  icon: Icons.refresh_rounded,
                  label: 'Regenerate',
                  onTap: (_state != GenerateState.idle || originalQuestion == null || originalQuestion.trim().isEmpty)
                      ? null
                      : () => _sendMessage(originalQuestion!),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: 'chat-title-${widget.chatId}',
          child: Material(color: Colors.transparent, child: Text(widget.chatName)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: MemoryModeChip(
                compact: true,
                onOpenHub: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoryHubPage()),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(.24),
                  ),
                ),
                child: Text(
                  modelLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<List<Message>>(
                  stream: _store.watchMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;

                    if (!_didInitialAutoScroll) {
                      _didInitialAutoScroll = true;
                      _jumpToBottom();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
                      itemCount: messages.length + (_state == GenerateState.generating ? 1 : 0),
                      itemBuilder: (_, index) {
                        if (index == messages.length && _state == GenerateState.generating) {
                          return _BotTypingBubble(accentColor: _assistantAccentColor(), avatarIcon: _personaAvatarIcon, avatarEmoji: _personaAvatarEmoji, avatarColor: _personaAvatarColor ?? _assistantAccentColor());
                        }

                        final msg = messages[index];
                        final isUser = msg.role == 'user';
                        final metaParsed = _extractMetaFromText(msg.text);
                        final meta = metaParsed.meta;
                        String cleanText = metaParsed.body;

                        String? plan;
                        String bodyText = cleanText;
                        if (!isUser) {
                          final parsedPlan = _extractPlanFromText(cleanText);
                          plan = parsedPlan.plan;
                          bodyText = parsedPlan.body;
                        }

                        final remoteMedia = _extractRemoteMedia(
                          text: bodyText,
                          meta: meta,
                        );

                        final parsedInline = _parseInlineImagesCached(msg.id, remoteMedia.text);
                        final assistantAccent = _assistantAccentColor(meta);
                        final bg = isUser ? userBg() : _assistantSurfaceColor(meta);
                        final fg = isUser ? userText() : aiText();

                        final bubbleContent = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser && plan != null && plan.trim().isNotEmpty)
                              _PlanDisclosure(plan: plan.trim()),
                            if (parsedInline.text.isNotEmpty)
                              SelectionContainer.disabled(
                                child: MarkdownBubble(
                                  text: parsedInline.text,
                                  textColor: fg,
                                  linkColor: const Color(0xFF00B8FF),
                                ),
                              ),
                            if (parsedInline.images.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final im in parsedInline.images)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: math.min(screenWidth * .64, 360),
                                      height: 190,
                                      color: Colors.black12,
                                      child: Image.memory(
                                        im.bytes,
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.low,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            if (remoteMedia.imageUrls.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final imageUrl in remoteMedia.imageUrls)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: math.min(screenWidth * .64, 360),
                                      constraints: const BoxConstraints(minHeight: 150, maxHeight: 360),
                                      color: Colors.black12,
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          if (progress == null) return child;
                                          return const SizedBox(
                                            height: 180,
                                            child: Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            height: 150,
                                            padding: const EdgeInsets.all(14),
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.broken_image_outlined, size: 30),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Could not load image',
                                                  style: TextStyle(
                                                    color: fg.withOpacity(.85),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                SelectableText(
                                                  imageUrl,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF00B8FF),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            if (remoteMedia.otherUrls.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              MarkdownBubble(
                                text: remoteMedia.otherUrls.join('\n'),
                                textColor: fg,
                                linkColor: const Color(0xFF00B8FF),
                              ),
                            ],
                            if (isUser && (meta?['promptChipLabel'] ?? '').toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: const Color(0xFF12C6FF).withOpacity(.12),
                                    border: Border.all(color: const Color(0xFF12C6FF).withOpacity(.26)),
                                  ),
                                  child: Text(
                                    '✓ ${(meta?['promptChipLabel'] ?? '').toString()}',
                                    style: const TextStyle(color: Color(0xFF12C6FF), fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );

                        String? previousUserText;
                        if (!isUser) {
                          for (var i = index - 1; i >= 0; i--) {
                            final prev = messages[i];
                            if ((prev.role.trim().toLowerCase() == 'user')) {
                              previousUserText = _cleanCanvasText(prev.text);
                              if (previousUserText.isNotEmpty) break;
                            }
                          }
                        }

                        final bubble = GestureDetector(
                          onLongPress: () => _showMsgActionsSheet(
                            context: context,
                            messageId: msg.id,
                            text: bodyText,
                            isUser: isUser,
                            meta: meta,
                            originalQuestion: previousUserText,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: screenWidth * 0.78),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.primary
                                      : assistantAccent.withOpacity(Theme.of(context).brightness == Brightness.light ? .50 : .70),
                                  width: isUser ? 1.2 : 1.15,
                                ),
                              ),
                              child: bubbleContent,
                            ),
                          ),
                        );

                        final row = Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment:
                              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isUser)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 10),
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: (_personaAvatarColor ?? assistantAccent).withOpacity(.16),
                                  child: _personaAvatarEmoji != null && _personaAvatarEmoji!.trim().isNotEmpty
                                      ? Text(_personaAvatarEmoji!, style: const TextStyle(fontSize: 16))
                                      : (_personaAvatarIcon != null
                                          ? Icon(_personaAvatarIcon, size: 18, color: _personaAvatarColor ?? assistantAccent)
                                          : CircleAvatar(radius: 18, backgroundColor: assistantAccent.withOpacity(.16), backgroundImage: const AssetImage('assets/ai_orb.png'))),
                                ),
                              ),
                            Flexible(child: bubble),
                          ],
                        );

                        if (!isUser &&
                            FeedbackMemory.feedbackFor(msg.id) == MessageFeedback.dislike) {
                          FeedbackMemory.setFeedback(msg.id, MessageFeedback.none);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _rewriteBotMessage(msg.id, bodyText);
                          });
                        }

                        return Column(
                          crossAxisAlignment:
                              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            row,
                            likeDislikeRow(messageId: msg.id, isUser: isUser, botText: bodyText, originalQuestion: previousUserText),
                          ],
                        );
                      },
                    );
                  },
                ),
                if (speaking)
                  Positioned(
                    left: 16,
                    bottom: 124,
                    child: FloatingActionButton.extended(
                      heroTag: 'stopTts',
                      elevation: 1,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () async {
                        try {
                          await _tts.stop();
                        } catch (_) {}
                        FeedbackMemory.speakingMsgId = null;
                        if (mounted) setState(() {});
                      },
                      backgroundColor: Colors.redAccent.withOpacity(.15),
                      foregroundColor: Colors.redAccent,
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Stop voice'),
                    ),
                  ),
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 124,
                    child: FloatingActionButton(
                      heroTag: 'scrollDown',
                      mini: true,
                      backgroundColor: _electricBlue,
                      foregroundColor: Colors.black,
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ),
              ],
            ),
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.greenAccent.withOpacity(.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, color: Colors.greenAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lastSpeechWords.trim().isEmpty ? 'Listeningâ€¦ speak now' : _lastSpeechWords,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _stopListeningAndSend,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoPromptChips(
                    controller: _controller,
                    screenContext: 'chat',
                    onSend: (transformedText, chipType, chipLabel) async {
                      await _sendMessage(transformedText, promptChipLabel: chipLabel);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SmallCircleIcon(
                        icon: Icons.attach_file_rounded,
                        color: _electricBlue,
                        onTap: _showAddSheet,
                        tooltip: 'Add',
                      ),
                      const SizedBox(width: 8),
                      _SmallCircleIcon(
                        icon: _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: _isListening ? Colors.greenAccent : _electricBlue,
                        onTap: _state == GenerateState.generating
                            ? null
                            : (_isListening ? _stopListeningAndSend : _startListening),
                        tooltip: _isListening ? 'Stop & send' : 'Voice dictate',
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ExpandableTextBox(
                          controller: _controller,
                          focusNode: _focus,
                          isLight: isLight,
                          borderColor: _electricBlue,
                          attachmentPreview: _attachmentPreview(),
                          onExpandSend: (value) => _sendMessage(value),
                          hintText: 'Type your message…',
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RightPrimaryButton(
                        state: _state,
                        hasPayload: hasPayload,
                        onStop: _stopGenerating,
                        onSend: () => _sendMessage(_controller.text),
                        onHandsFree: () {
                          Navigator.of(context).push(PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 280),
                            pageBuilder: (_, a1, __) => FadeTransition(
                              opacity: a1,
                              child: const VoiceChatComingSoonPage(),
                            ),
                          ));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rewriteBotMessage(int msgId, String originalText) async {
    final currentFormat = FormatClassifier.detect(originalText);
    final target = FormatClassifier.alternativeTo(currentFormat);
    final instr = FormatClassifier.rewriteInstr(target);

    final prompt = 'Rewrite the assistant\'s previous answer in an improved format.\n'
        '$instr\nKeep meaning, be concise, no new facts.\n\n'
        'Answer to rewrite:\n$originalText';

    final r = await GPMaiBrain.sendRich(
      userId: widget.userId,
      chatId: '${widget.chatId}__utility_rewrite',
      uiModel: _selectedModelId,
      userText: prompt,
      systemPrompt: widget.systemPrompt,
      sourceTag: 'utility:rewrite',
    );

    String rewritten = r.text.trim();
    if (rewritten.isEmpty) return;

    final botMeta = <String, dynamic>{
      'role': 'gpm',
      'ts': DateTime.now().millisecondsSinceEpoch,
      'chatId': widget.chatId,
      'uiModelKey': _selectedModelId,
      'uiModelLabel': _selectedModelLabel,
      'usedUiModel': r.usedUiModel,
      'fallback': r.fallback,
      'cooldown': r.cooldown,
      'attachmentsUsed': 0,
      'estTokens': _estimateTokensFromText(rewritten),
      'note': 'rewrite',
    };

    await _store.addMessage(
      chatId: widget.chatId,
      role: 'gpm',
      text: _encodeMetaIntoText(meta: botMeta, body: rewritten),
    );

    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Future.delayed(const Duration(milliseconds: 140));
                await _addFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Future.delayed(const Duration(milliseconds: 140));
                await _addFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Choose files'),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await Future.delayed(const Duration(milliseconds: 140));
                await _addFromFiles();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openMessageInfo({
    required BuildContext context,
    required int messageId,
    required bool isUser,
    required String text,
    Map<String, dynamic>? meta,
  }) async {
    final m = meta ?? <String, dynamic>{};
    m.putIfAbsent('messageId', () => messageId);
    m.putIfAbsent('isUser', () => isUser);
    m.putIfAbsent('textChars', () => text.trim().length);
    m.putIfAbsent('estTokens', () => _estimateTokensFromText(text));

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageInfoPage(meta: m, messageText: text),
      ),
    );
  }


  Future<void> _saveMessageToCanvas({
    required String messageText,
    String? originalQuestion,
  }) async {
    final clean = _cleanCanvasText(messageText);
    if (clean.isEmpty) return;
    final cleanQuestion = _cleanCanvasText(originalQuestion);
    final title = cleanQuestion.isNotEmpty
        ? (cleanQuestion.length > 52 ? '${cleanQuestion.substring(0, 52)}…' : cleanQuestion)
        : (clean.length > 52 ? '${clean.substring(0, 52)}…' : clean);
    await SaveToCanvasSheet.open(
      context,
      draft: ResearchCanvasBlockDraft(
        type: 'text',
        title: title,
        question: cleanQuestion.isEmpty ? null : cleanQuestion,
        content: clean,
        sourceLabel: widget.systemPrompt != null ? 'Persona chat' : 'Chat',
        modelLabel: _selectedModelLabel,
        tags: const <String>[],
        extra: <String, dynamic>{'chatId': widget.chatId, 'chatName': widget.chatName, 'userId': widget.userId, 'sourceType': 'chat'},
      ),
    );
  }

  Future<void> _saveSelectedSnippetToCanvas({
    required String snippet,
    String? originalQuestion,
  }) async {
    final clean = _cleanCanvasText(snippet);
    if (clean.isEmpty) return;
    final cleanQuestion = _cleanCanvasText(originalQuestion);
    await SaveToCanvasSheet.open(
      context,
      draft: ResearchCanvasBlockDraft(
        type: 'text',
        title: clean.length > 48 ? '${clean.substring(0, 48)}…' : clean,
        question: cleanQuestion.isEmpty ? null : cleanQuestion,
        content: clean,
        sourceLabel: 'Selected text',
        modelLabel: _selectedModelLabel,
        extra: <String, dynamic>{'chatId': widget.chatId, 'chatName': widget.chatName, 'userId': widget.userId, 'sourceType': 'chat'},
      ),
    );
  }

  Future<void> _showMsgActionsSheet({
    required BuildContext context,
    required int messageId,
    required String text,
    required bool isUser,
    Map<String, dynamic>? meta,
    String? originalQuestion,
  }) async {
    final cs = Theme.of(context).colorScheme;

    Future<void> copy() async {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
      }
    }

    Future<void> share() async {
      await Share.share(text);
      if (mounted) Navigator.pop(context);
    }

    Future<void> select() async {
      final editor = TextEditingController(text: text);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select text'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trim this into the exact excerpt you want to keep or copy.', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: TextField(
                    controller: editor,
                    maxLines: null,
                    minLines: 10,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _saveSelectedSnippetToCanvas(snippet: editor.text, originalQuestion: originalQuestion);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.auto_awesome_mosaic_rounded),
                      label: const Text('Add to Canvas'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: editor.text));
                        if (ctx.mounted) Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted) Navigator.pop(context);
    }

    Future<void> speak() async {
      if (FeedbackMemory.speakingMsgId == messageId) {
        await _tts.stop();
        FeedbackMemory.speakingMsgId = null;
      } else {
        try {
          await _tts.stop();
        } catch (_) {}
        FeedbackMemory.speakingMsgId = messageId;
        await _tts.speak(text);
      }
      if (mounted) {
        Navigator.pop(context);
        setState(() {});
      }
    }

    Future<void> info() async {
      Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 120));
      await _openMessageInfo(
        context: context,
        messageId: messageId,
        isUser: isUser,
        text: text,
        meta: meta,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(leading: const Icon(Icons.copy_rounded), title: const Text('Copy'), onTap: copy),
            ListTile(leading: const Icon(Icons.share_rounded), title: const Text('Share'), onTap: share),
            if (!isUser)
              ListTile(
                leading: const Icon(Icons.auto_awesome_mosaic_rounded),
                title: const Text('Add to Canvas'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveMessageToCanvas(messageText: text, originalQuestion: originalQuestion);
                },
              ),
            ListTile(
              leading: const Icon(Icons.select_all_rounded),
              title: const Text('Select text'),
              onTap: select,
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_rounded),
              title: Text(FeedbackMemory.speakingMsgId == messageId ? 'Stop speaking' : 'Speak'),
              onTap: speak,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Message info'),
              onTap: info,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class MessageInfoPage extends StatelessWidget {
  final Map<String, dynamic> meta;
  final String messageText;

  const MessageInfoPage({super.key, required this.meta, required this.messageText});

  String _fmtTime(int? ms) {
    if (ms == null || ms <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $h:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    final role = (meta['role'] ?? (meta['isUser'] == true ? 'user' : 'gpm')).toString();
    final time = _fmtTime(meta['ts'] is int ? meta['ts'] as int : int.tryParse('${meta['ts']}'));
    final modelLabel = (meta['uiModelLabel'] ?? '-').toString();
    final modelKey = (meta['uiModelKey'] ?? '-').toString();
    final usedModel = (meta['usedUiModel'] ?? '-').toString();
    final usedLabel = (meta['usedUiModelLabel'] ?? usedModel).toString();
    final estTokens = meta['estTokens'];
    final tokStr = (estTokens == null) ? '-' : estTokens.toString();
    final attachments = meta['attachments'] ?? meta['attachmentsUsed'] ?? 0;

    Widget tile(String label, String value, {IconData? icon}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isLight ? Colors.black.withOpacity(.04) : Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLight ? Colors.black54 : Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: isLight ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Message info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withOpacity(.12),
                  cs.primary.withOpacity(.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: cs.primary.withOpacity(.20)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black,
                  backgroundImage: role == 'gpm' ? const AssetImage('assets/ai_orb.png') : null,
                  child: role == 'user' ? Icon(Icons.person_rounded, color: cs.primary) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role == 'user' ? 'Sent by you' : 'Sent by GPMai',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(
                        time,
                        style: TextStyle(
                          color: isLight ? Colors.black54 : Colors.white60,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          tile('Engine', modelLabel, icon: Icons.smart_toy_rounded),
          const SizedBox(height: 10),
          tile('Engine key', modelKey, icon: Icons.vpn_key_rounded),
          const SizedBox(height: 10),
          tile('Used engine', usedLabel, icon: Icons.bolt_rounded),
          const SizedBox(height: 10),
          tile('Used id', usedModel, icon: Icons.code_rounded),
          const SizedBox(height: 10),
          tile('Estimated tokens', tokStr, icon: Icons.data_usage_rounded),
          const SizedBox(height: 10),
          tile('Attachments', '$attachments', icon: Icons.attach_file_rounded),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isLight ? Colors.black.withOpacity(.04) : Colors.white.withOpacity(.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.paid_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 10),
                    const Text('Cost', style: TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Points: ${meta['pointsCost'] ?? meta['points'] ?? '-'} â€¢ USD: ${meta['usdCost'] ?? meta['usd'] ?? '-'}',
                  style: TextStyle(
                    color: isLight ? Colors.black54 : Colors.white60,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isLight ? Colors.black12 : Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Message', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SelectableText(
                  messageText,
                  style: TextStyle(
                    color: isLight ? Colors.black87 : Colors.white,
                    height: 1.25,
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

class _PlanDisclosure extends StatefulWidget {
  final String plan;
  const _PlanDisclosure({required this.plan});

  @override
  State<_PlanDisclosure> createState() => _PlanDisclosureState();
}

class _PlanDisclosureState extends State<_PlanDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? Colors.black.withOpacity(.06) : Colors.white.withOpacity(.10);
    final border = isLight ? Colors.black26 : Colors.white24;
    final fg = isLight ? Colors.black87 : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _open ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      color: fg.withOpacity(.85),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Thought',
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _open ? 'Hide' : 'Show',
                      style: TextStyle(color: fg.withOpacity(.65), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  widget.plan,
                  style: TextStyle(
                    color: fg.withOpacity(.9),
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BotTypingBubble extends StatefulWidget {
  final Color accentColor;
  final IconData? avatarIcon;
  final String? avatarEmoji;
  final Color? avatarColor;

  const _BotTypingBubble({
    required this.accentColor,
    this.avatarIcon,
    this.avatarEmoji,
    this.avatarColor,
  });

  @override
  State<_BotTypingBubble> createState() => _BotTypingBubbleState();
}

class _BotTypingBubbleState extends State<_BotTypingBubble> with SingleTickerProviderStateMixin {
  static const Color _electricBlue = Color(0xFF00B8FF);
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight ? Colors.black.withOpacity(.06) : const Color(0xFF171B22);

    final accent = widget.accentColor;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: (widget.avatarColor ?? accent).withOpacity(.16),
              child: widget.avatarEmoji != null && widget.avatarEmoji!.trim().isNotEmpty
                  ? Text(widget.avatarEmoji!, style: const TextStyle(fontSize: 16))
                  : (widget.avatarIcon != null
                      ? Icon(widget.avatarIcon, size: 18, color: widget.avatarColor ?? accent)
                      : const CircleAvatar(radius: 18, backgroundColor: Colors.black, backgroundImage: AssetImage('assets/ai_orb.png'))),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(.12),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final s1 = 0.8 + _ctrl.value * 0.4;
                final s2 = 0.7 + (1 - _ctrl.value) * 0.5;
                final s3 = 0.8 + (_ctrl.value * 0.4);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(scale: s1),
                    const SizedBox(width: 6),
                    _dot(scale: s2),
                    const SizedBox(width: 6),
                    _dot(scale: s3),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot({required double scale}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.white, widget.accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _SmallCircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? tooltip;
  const _SmallCircleIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    const w = 42.0;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(w / 2),
        child: Ink(
          width: w,
          height: w,
          decoration: BoxDecoration(
            color: color.withOpacity(.14),
            border: Border.all(color: color.withOpacity(.38)),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

class _RightPrimaryButton extends StatelessWidget {
  final GenerateState state;
  final bool hasPayload;
  final VoidCallback onStop;
  final VoidCallback onSend;
  final VoidCallback onHandsFree;

  const _RightPrimaryButton({
    required this.state,
    required this.hasPayload,
    required this.onStop,
    required this.onSend,
    required this.onHandsFree,
  });

  @override
  Widget build(BuildContext context) {
    const double size = 46.0;
    const Color bg = Color(0xFF00B8FF);

    Widget child;
    VoidCallback onTap;

    if (state == GenerateState.generating) {
      child = const Icon(Icons.stop_rounded, color: Colors.black);
      onTap = onStop;
    } else if (hasPayload) {
      child = const Icon(Icons.arrow_upward_rounded, color: Colors.black);
      onTap = onSend;
    } else {
      child = const Icon(Icons.support_agent_rounded, color: Colors.black);
      onTap = onHandsFree;
    }

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Ink(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}
