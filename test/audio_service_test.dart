import 'dart:typed_data';

import 'package:flutter_3_player_poker/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _ascii(Uint8List bytes, int offset, int length) {
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('所有提示音都合成合法的 16bit 单声道 WAV', () {
    final service = AudioService.instance;
    for (final cue in AudioCue.values) {
      final wav = service.debugWav(cue);
      final data = ByteData.sublistView(wav);

      expect(_ascii(wav, 0, 4), 'RIFF', reason: '$cue');
      expect(_ascii(wav, 8, 4), 'WAVE', reason: '$cue');
      expect(_ascii(wav, 12, 4), 'fmt ', reason: '$cue');
      expect(data.getUint16(20, Endian.little), 1, reason: '$cue 应为 PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: '$cue 应为单声道');
      expect(data.getUint32(24, Endian.little), 22050, reason: '$cue');
      expect(data.getUint16(34, Endian.little), 16, reason: '$cue');
      expect(_ascii(wav, 36, 4), 'data', reason: '$cue');
      expect(
        data.getUint32(40, Endian.little),
        wav.length - 44,
        reason: '$cue 数据长度应与头一致',
      );
      expect(wav.length, greaterThan(44), reason: '$cue');
    }
  });

  test('音效缓存复用同一份字节，避免重复合成', () {
    final service = AudioService.instance;
    expect(
      identical(
        service.debugWav(AudioCue.play),
        service.debugWav(AudioCue.play),
      ),
      isTrue,
    );
  });

  test('背景音乐是长度可控的循环 WAV', () {
    final wav = AudioService.instance.debugBgmWav();
    final data = ByteData.sublistView(wav);
    final dataSize = data.getUint32(40, Endian.little);
    final seconds = dataSize / (22050 * 2);

    expect(_ascii(wav, 0, 4), 'RIFF');
    expect(_ascii(wav, 8, 4), 'WAVE');
    expect(seconds, closeTo(12, 0.1));
    expect(wav.length, lessThan(600 * 1024));
  });
}
