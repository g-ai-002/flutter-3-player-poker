import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../utils/test_environment.dart';
import 'log_service.dart';

/// 程序化生成的音效类型。
enum AudioCue { deal, play, pass, bomb, bid, double, reveal, win, lose }

/// 本地音频：音效与背景音乐全部用正弦波实时合成 WAV，不携带音频文件。
///
/// 播放失败只记录一次日志，绝不影响对局；Web 端背景音乐在用户首次
/// 点击「开始对局」后才会启动，符合浏览器的自动播放策略。
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  AudioPlayer? _sfxPlayer;
  AudioPlayer? _bgmPlayer;
  final Map<AudioCue, Uint8List> _cache = {};

  Uint8List? _bgmBytes;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _bgmRequested = false;
  bool _bgmPlaying = false;
  bool _warned = false;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  AudioPlayer get _sfx => _sfxPlayer ??= AudioPlayer();
  AudioPlayer get _bgm => _bgmPlayer ??= AudioPlayer();

  /// 测试环境没有原生音频通道，也不应留下播放器资源。
  bool get _blocked => isFlutterTest;

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    LogService.info('音效: ${value ? '开启' : '关闭'}');
    if (!value && _sfxPlayer != null) _ignore(_sfxPlayer!.stop());
  }

  void setMusicEnabled(bool value) {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    LogService.info('背景音乐: ${value ? '开启' : '关闭'}');
    if (!_bgmRequested) return;
    if (value) {
      _bgmPlaying ? _ignore(_bgm.resume()) : startBgm();
    } else {
      _bgmPlaying = false;
      if (_bgmPlayer != null) _ignore(_bgm.pause());
    }
  }

  /// 首次进入牌桌前生成常用波形，避免第一次出牌时才合成。
  void prewarm() {
    for (final cue in AudioCue.values) {
      _bytes(cue);
    }
    if (_blocked) return;
    _ignore(_sfx.setVolume(0.65));
  }

  /// 开始循环背景音乐；静音时只记录请求，取消静音后再播放。
  void startBgm() {
    _bgmRequested = true;
    if (_blocked) return;
    _bgmBytes ??= _buildBgmLoop();
    if (!_musicEnabled || _bgmPlaying) return;
    _ignore(_playBgm());
  }

  void stopBgm() {
    _bgmRequested = false;
    _bgmPlaying = false;
    if (_bgmPlayer != null) _ignore(_bgm.pause());
  }

  void play(AudioCue cue) {
    if (_blocked || !_soundEnabled) return;
    _ignore(_playCue(cue));
  }

  Future<void> _playCue(AudioCue cue) async {
    try {
      await _sfx.stop();
      await _sfx.play(BytesSource(_bytes(cue)));
    } catch (e) {
      _warnOnce('音效播放失败: $e');
    }
  }

  Future<void> _playBgm() async {
    if (!_bgmRequested || !_musicEnabled) return;
    try {
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setVolume(0.26);
      await _bgm.play(BytesSource(_bgmBytes!));
      _bgmPlaying = true;
    } catch (e) {
      _bgmPlaying = false;
      _warnOnce('背景音乐播放失败: $e');
    }
  }

  Uint8List _bytes(AudioCue cue) {
    return _cache.putIfAbsent(cue, () => _generate(cue));
  }

  /// 测试用：检查合成出的 WAV 头与波形长度。
  @visibleForTesting
  Uint8List debugWav(AudioCue cue) => _bytes(cue);

  /// 测试用：检查背景音乐循环的长度与格式。
  @visibleForTesting
  Uint8List debugBgmWav() => _bgmBytes ??= _buildBgmLoop();

  Uint8List _generate(AudioCue cue) {
    switch (cue) {
      case AudioCue.deal:
        return _mix([
          _wave(440, 60, gain: 0.22),
          _wave(660, 90, gain: 0.18, delayMs: 70),
        ]);
      case AudioCue.play:
        return _wave(760, 65, gain: 0.3, decay: 2.6);
      case AudioCue.pass:
        return _wave(280, 120, gain: 0.24, decay: 1.6);
      case AudioCue.bomb:
        return _mix([
          _wave(90, 320, gain: 0.42, decay: 1.4),
          _noise(280, gain: 0.3),
        ]);
      case AudioCue.bid:
        return _mix([
          _wave(520, 90, gain: 0.24),
          _wave(780, 120, gain: 0.2, delayMs: 80),
        ]);
      case AudioCue.double:
        return _mix([
          _wave(392, 90, gain: 0.22),
          _wave(523, 90, gain: 0.22, delayMs: 80),
          _wave(784, 160, gain: 0.24, delayMs: 160),
        ]);
      case AudioCue.reveal:
        return _mix([
          for (var i = 0; i < 4; i++)
            _wave(
              660 * pow(1.25, i).toDouble(),
              220,
              gain: 0.14,
              delayMs: i * 55,
            ),
        ]);
      case AudioCue.win:
        return _mix([
          _wave(523, 130),
          _wave(659, 130, delayMs: 120),
          _wave(784, 150, delayMs: 240),
          _wave(1047, 260, gain: 0.22, delayMs: 380),
        ]);
      case AudioCue.lose:
        return _mix([
          _wave(392, 160, gain: 0.24),
          _wave(330, 160, gain: 0.24, delayMs: 150),
          _wave(262, 320, gain: 0.22, delayMs: 300),
        ]);
    }
  }

  Uint8List _wave(
    double freq,
    int ms, {
    double gain = 0.25,
    double decay = 1.8,
    int delayMs = 0,
  }) {
    const rate = 22050;
    final samples = rate * ms ~/ 1000;
    final delay = rate * delayMs ~/ 1000;
    return _buildWav(rate, samples + delay, (i) {
      if (i < delay) return 0;
      final t = (i - delay) / rate;
      final envelope = pow(1 - (i - delay) / samples, decay).toDouble();
      return sin(2 * pi * freq * t) * envelope * gain;
    });
  }

  Uint8List _noise(int ms, {double gain = 0.2}) {
    const rate = 22050;
    final samples = rate * ms ~/ 1000;
    final random = Random(11);
    return _buildWav(rate, samples, (i) {
      final envelope = pow(1 - i / samples, 2).toDouble();
      final tone = sin(2 * pi * 70 * i / rate);
      return (random.nextDouble() * 2 - 1 + tone) * 0.5 * envelope * gain;
    });
  }

  /// 把多段波形叠加成一条音轨，长度取最长的一段。
  Uint8List _mix(List<Uint8List> parts) {
    if (parts.length == 1) return parts.first;
    final decoded = parts.map(_samplesOf).toList();
    final length = decoded.map((samples) => samples.length).reduce(max);
    return _buildWav(22050, length, (i) {
      var sum = 0.0;
      for (final samples in decoded) {
        if (i < samples.length) sum += samples[i];
      }
      return sum.clamp(-0.95, 0.95);
    });
  }

  Float64List _samplesOf(Uint8List wav) {
    final data = ByteData.sublistView(wav);
    final count = (wav.length - 44) ~/ 2;
    final samples = Float64List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = data.getInt16(44 + i * 2, Endian.little) / 32767;
    }
    return samples;
  }

  Uint8List _buildWav(
    int sampleRate,
    int numSamples,
    double Function(int index) sampleAt,
  ) {
    const channels = 1;
    const bitsPerSample = 16;
    final dataSize = numSamples * channels * (bitsPerSample ~/ 8);
    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    void writeStr(String value) {
      for (var i = 0; i < value.length; i++) {
        buffer.setUint8(offset++, value.codeUnitAt(i));
      }
    }

    void writeUint16(int value) {
      buffer.setUint16(offset, value, Endian.little);
      offset += 2;
    }

    void writeUint32(int value) {
      buffer.setUint32(offset, value, Endian.little);
      offset += 4;
    }

    writeStr('RIFF');
    writeUint32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeUint32(16);
    writeUint16(1);
    writeUint16(channels);
    writeUint32(sampleRate);
    writeUint32(sampleRate * channels * (bitsPerSample ~/ 8));
    writeUint16(channels * (bitsPerSample ~/ 8));
    writeUint16(bitsPerSample);
    writeStr('data');
    writeUint32(dataSize);

    for (var i = 0; i < numSamples; i++) {
      final value = (sampleAt(i) * 32767).round().clamp(-32768, 32767);
      buffer.setInt16(offset, value, Endian.little);
      offset += 2;
    }
    return buffer.buffer.asUint8List();
  }

  /// 12 秒循环：五声音阶旋律 + 舒缓低音，音量很低，长时间不刺耳。
  Uint8List _buildBgmLoop() {
    const rate = 22050;
    const durationMs = 12000;
    const noteMs = 750;
    const melody = [
      523.25,
      659.25,
      783.99,
      659.25,
      587.33,
      440.0,
      523.25,
      392.0,
    ];
    const bass = [130.81, 174.61, 196.0, 164.81];
    const samples = rate * durationMs ~/ 1000;
    return _buildWav(rate, samples, (i) {
      final t = i / rate;
      final note = (t * 1000 / noteMs).floor() % melody.length;
      final noteT = (t * 1000) % noteMs / 1000;
      final envelope = sin(pi * noteT / (noteMs / 1000));
      final lead = sin(2 * pi * melody[note] * t) * envelope * 0.07;
      final harmony = sin(2 * pi * melody[note] * 0.5 * t) * envelope * 0.018;
      final bassNote = bass[(t * 1000 / (noteMs * 2)).floor() % bass.length];
      final pulse = 0.5 + 0.5 * sin(2 * pi * t / 3);
      final low = sin(2 * pi * bassNote * t) * 0.035 * pulse;
      return lead + harmony + low;
    });
  }

  void _ignore(Future<void> future) {
    unawaited(future.catchError((Object e) => _warnOnce('音频操作失败: $e')));
  }

  void _warnOnce(String message) {
    if (_warned) return;
    _warned = true;
    LogService.warning(message);
  }

  void dispose() {
    final sfx = _sfxPlayer;
    final bgm = _bgmPlayer;
    _sfxPlayer = null;
    _bgmPlayer = null;
    if (sfx != null) _ignore(sfx.dispose());
    if (bgm != null) _ignore(bgm.dispose());
  }
}
