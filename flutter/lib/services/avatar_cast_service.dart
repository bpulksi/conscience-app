import 'package:flutter/services.dart';

/// One avatar personality as it ships in the APK (assets/avatars/<id>/persona.json).
class AvatarInfo {
  const AvatarInfo({
    required this.id,
    required this.name,
    required this.tone,
    required this.maxLinesPerDay,
  });

  final String id;
  final String name;
  final String tone;
  final int maxLinesPerDay;

  factory AvatarInfo.fromMap(Map<Object?, Object?> map) => AvatarInfo(
        id: '${map['id']}',
        name: '${map['name']}',
        tone: '${map['tone'] ?? ''}',
        maxLinesPerDay: int.tryParse('${map['maxLinesPerDay']}') ?? 0,
      );
}

/// Talks to AvatarChannel.kt: what exists, what is selected, and a sample line.
class AvatarCastService {
  static const _channel = MethodChannel('conscience/avatars');

  const AvatarCastService();

  Future<List<AvatarInfo>> list() async {
    final raw = await _channel.invokeMethod<List<Object?>>('list') ?? const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map(AvatarInfo.fromMap)
        .toList(growable: false);
  }

  Future<String?> selected() async {
    return _channel.invokeMethod<String>('selected');
  }

  Future<void> select(String id) async {
    await _channel.invokeMethod<void>('select', {'id': id});
  }

  Future<String?> sampleLine({required String id, String stage = 'impatient'}) async {
    return _channel.invokeMethod<String>('sampleLine', {'id': id, 'stage': stage});
  }

  Future<void> mute({int minutes = 30}) async {
    await _channel.invokeMethod<void>('mute', {'minutes': minutes});
  }

  /// Milliseconds since epoch when the mute ends, or 0 when not muted.
  Future<int> mutedUntil() async {
    return await _channel.invokeMethod<int>('muteStatus') ?? 0;
  }
}
