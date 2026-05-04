import 'curated_media_models.dart';

enum AudioUiKind {
  speech,
  music,
}

enum VoiceControlType {
  none,
  speakerEnum,
  voiceEnum,
  styleHint,
}

class AudioModelProfile {
  final AudioUiKind kind;
  final VoiceControlType voiceControlType;
  final List<String> speakerOptions;
  final List<String> voiceOptions;
  final List<String> voiceStyleOptions;

  const AudioModelProfile({
    required this.kind,
    this.voiceControlType = VoiceControlType.none,
    this.speakerOptions = const [],
    this.voiceOptions = const [],
    this.voiceStyleOptions = const [],
  });
}

class AudioModelRegistry {
  static const List<String> qwenSpeakers = [
    'Aiden',
    'Dylan',
    'Eric',
    'Ono_anna',
    'Ryan',
    'Serena',
    'Sohee',
    'Uncle_fu',
    'Vivian',
  ];

  static const List<String> elevenlabsVoices = [
    'Rachel',
    'Drew',
    'Clyde',
    'Paul',
    'Aria',
    'Domi',
    'Dave',
    'Roger',
    'Fin',
    'Sarah',
    'James',
    'Jane',
    'Juniper',
    'Arabella',
    'Hope',
    'Bradford',
    'Reginald',
    'Gaming',
    'Austin',
    'Kuon',
    'Blondie',
    'Priyanka',
    'Alexandra',
    'Monika',
    'Mark',
    'Grimblewood',
  ];

  static const List<String> speechStyles = [
    'Female',
    'Male',
    'Child',
    'Narrator',
    'Calm',
    'Energetic',
  ];

  static AudioModelProfile profileForModel(CuratedMediaModel model) {
    final id = model.id.toLowerCase();

    if (id == 'qwen/qwen3-tts') {
      return const AudioModelProfile(
        kind: AudioUiKind.speech,
        voiceControlType: VoiceControlType.speakerEnum,
        speakerOptions: qwenSpeakers,
      );
    }

    if (id == 'elevenlabs/turbo-v2.5' ||
        id == 'elevenlabs/flash-v2.5' ||
        id == 'elevenlabs/v2-multilingual' ||
        id == 'elevenlabs/v3') {
      return const AudioModelProfile(
        kind: AudioUiKind.speech,
        voiceControlType: VoiceControlType.voiceEnum,
        voiceOptions: elevenlabsVoices,
      );
    }

    if (id == 'minimax/speech-2.8-turbo' ||
        id == 'minimax/speech-2.8-hd') {
      return const AudioModelProfile(
        kind: AudioUiKind.speech,
        voiceControlType: VoiceControlType.styleHint,
        voiceStyleOptions: speechStyles,
      );
    }

    return const AudioModelProfile(
      kind: AudioUiKind.music,
      voiceControlType: VoiceControlType.none,
    );
  }

  static String modeFor(CuratedMediaModel model) {
    final profile = profileForModel(model);
    return profile.kind == AudioUiKind.music ? 'music' : 'speech';
  }

  static List<String> supportTagsForModel(CuratedMediaModel model) {
    final profile = profileForModel(model);
    final tags = <String>[];

    if (profile.kind == AudioUiKind.speech) {
      tags.add('Speech');
    } else {
      tags.add('Music');
    }

    switch (profile.voiceControlType) {
      case VoiceControlType.speakerEnum:
        tags.add('Speakers');
        break;
      case VoiceControlType.voiceEnum:
        tags.add('Voices');
        break;
      case VoiceControlType.styleHint:
        tags.add('Voice styles');
        break;
      case VoiceControlType.none:
        break;
    }

    return tags;
  }
}
