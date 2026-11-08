import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../utils/test_environment.dart';
import 'log_service.dart';

/// 程序化生成的音效类型。
enum AudioCue { deal, play, pass, bomb, bid, double, reveal, win, lose }

/// 本地音频：音效与背景音乐全部用正弦波实时合成 WAV，不携带音频文件。
///
/// 合成好的 WAV 通过 flutter_soloud 的内存音源播放，Android、Windows 与
/// Web 共用同一套实现。播放失败只记录日志，绝不影响对局；Web 端背景
/// 音乐在用户首次点击「开始对局」后才会启动，符合浏览器的自动播放策略。
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  final Map<AudioCue, AudioSource> _sources = {};
  final Map<AudioCue, Uint8List> _cache = {};
  final Set<String> _reported = {};

  AudioSource? _bgmSource;
  SoundHandle? _bgmHandle;
  Uint8List? _bgmBytes;

  Future<void>? _loading;
  Future<void>? _engineReady;
  DateTime? _retryAt;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _bgmRequested = false;

  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  /// 背景音乐是否处于请求播放状态：退出牌桌后必须为 false。
  bool get bgmRequested => _bgmRequested;

  SoLoud get _soloud => SoLoud.instance;

  /// 测试环境没有原生音频通道，也不应留下播放器资源。
  bool get _blocked => isFlutterTest;

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    LogService.info('音效: ${value ? '开启' : '关闭'}');
    if (value) {
      unawaited(_ensureLoaded());
      return;
    }
    if (!_soloud.isInitialized) return;
    for (final source in _sources.values) {
      _soloud.stopAudioSource(source);
    }
  }

  void setMusicEnabled(bool value) {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    LogService.info('背景音乐: ${value ? '开启' : '关闭'}');
    if (!_bgmRequested || !_soloud.isInitialized) return;
    final handle = _bgmHandle;
    if (handle == null || !_soloud.getIsValidVoiceHandle(handle)) {
      if (value) startBgm();
      return;
    }
    _soloud.setPause(handle, !value);
  }

  /// 启动时调用：初始化音频引擎并预加载全部提示音，失败原因会写入日志。
  Future<void> initialize() => _ensureLoaded();

  /// 首次进入牌桌前生成常用波形，避免第一次出牌时才合成。
  void prewarm() {
    for (final cue in AudioCue.values) {
      _bytes(cue);
    }
    if (_blocked) return;
    unawaited(_ensureLoaded());
  }

  /// 开始循环背景音乐；静音时只记录请求，取消静音后再播放。
  void startBgm() {
    _bgmRequested = true;
    if (_blocked || !_musicEnabled) return;
    unawaited(_playBgm());
  }

  void stopBgm() {
    _bgmRequested = false;
    _stopBgmVoice();
  }

  void play(AudioCue cue) {
    if (_blocked || !_soundEnabled) return;
    unawaited(_playCue(cue));
  }

  Future<void> _playCue(AudioCue cue) async {
    try {
      final source = await _ensureSource(cue);
      if (source == null || !_soundEnabled) return;
      _soloud.play(source, volume: 0.95);
    } catch (e, stack) {
      _report('音效播放失败（${cue.name}）', e, stack);
    }
  }

  Future<void> _playBgm() async {
    try {
      final source = await _ensureBgmSource();
      if (source == null || !_bgmRequested || !_musicEnabled) return;
      final handle = _bgmHandle;
      if (handle != null && _soloud.getIsValidVoiceHandle(handle)) {
        _soloud.setPause(handle, false);
        return;
      }
      _bgmHandle = _soloud.play(source, volume: 0.26, looping: true);
    } catch (e, stack) {
      _report('背景音乐播放失败', e, stack);
    }
  }

  void _stopBgmVoice() {
    final handle = _bgmHandle;
    _bgmHandle = null;
    if (handle == null || !_soloud.isInitialized) return;
    if (_soloud.getIsValidVoiceHandle(handle)) _ignore(_soloud.stop(handle));
  }

  Future<AudioSource?> _ensureSource(AudioCue cue) async {
    final loaded = _sources[cue];
    if (loaded != null) return loaded;
    await _ensureLoaded();
    return _sources[cue];
  }

  Future<void> _ensureLoaded() {
    if (_blocked || _sources.length == AudioCue.values.length) {
      return Future.value();
    }
    final retryAt = _retryAt;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) {
      return Future.value();
    }
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  /// 全局唯一的引擎初始化入口。
  ///
  /// SoLoud 的 `init()` 在检测到引擎已初始化时会先 deinit 再重建，正在加载的
  /// 音源会全部失效。背景音乐与音效曾各自调用 init，导致音效加载被中断、
  /// 出牌永远没有声音，因此这里必须合并成同一个 Future。
  Future<void> _ensureEngine() {
    if (_soloud.isInitialized) return Future.value();
    return _engineReady ??= _soloud.init().whenComplete(
      () => _engineReady = null,
    );
  }

  Future<void> _load() async {
    try {
      await _ensureEngine();
      for (final cue in AudioCue.values) {
        if (_sources.containsKey(cue)) continue;
        _sources[cue] = await _soloud.loadMem(
          'poker-${cue.name}.wav',
          _bytes(cue),
        );
      }
      _retryAt = null;
      LogService.info('音效已就绪：${_sources.length}/${AudioCue.values.length}');
    } catch (e, stack) {
      // 初始化失败后 5 秒允许重试，避免一次失败导致整局静音。
      _retryAt = DateTime.now().add(const Duration(seconds: 5));
      _report('音效加载失败', e, stack);
    }
  }

  Future<AudioSource?> _ensureBgmSource() async {
    if (_blocked) return null;
    final loaded = _bgmSource;
    if (loaded != null) return loaded;
    await _ensureEngine();
    _bgmBytes ??= _buildBgmLoop();
    return _bgmSource = await _soloud.loadMem('poker-bgm.wav', _bgmBytes!);
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
          _wave(520, 70, gain: 0.32, decay: 2.2),
          _wave(660, 80, gain: 0.28, decay: 2.2, delayMs: 65),
          _wave(820, 90, gain: 0.26, decay: 2.2, delayMs: 130),
        ]);
      case AudioCue.play:
        // 出牌：纸牌拍在桌面上的一声清脆响，混入少量噪声更接近材质声。
        return _mix([
          _wave(760, 120, gain: 0.42, decay: 2.4),
          _noise(80, gain: 0.22),
        ]);
      case AudioCue.pass:
        return _wave(320, 170, gain: 0.32);
      case AudioCue.bomb:
        return _mix([
          _wave(90, 380, gain: 0.5, decay: 1.4),
          _noise(320, gain: 0.38),
        ]);
      case AudioCue.bid:
        return _mix([
          _wave(560, 110),
          _wave(840, 150, gain: 0.26, delayMs: 90),
        ]);
      case AudioCue.double:
        return _mix([
          _wave(392, 110, gain: 0.26),
          _wave(523, 110, gain: 0.26, delayMs: 80),
          _wave(784, 180, gain: 0.28, delayMs: 160),
        ]);
      case AudioCue.reveal:
        return _mix([
          for (var i = 0; i < 4; i++)
            _wave(
              660 * pow(1.25, i).toDouble(),
              220,
              gain: 0.16,
              delayMs: i * 55,
            ),
        ]);
      case AudioCue.win:
        return _mix([
          _wave(523, 130),
          _wave(659, 130, delayMs: 120),
          _wave(784, 150, delayMs: 240),
          _wave(1047, 260, gain: 0.24, delayMs: 380),
        ]);
      case AudioCue.lose:
        return _mix([
          _wave(392, 160, gain: 0.26),
          _wave(330, 160, gain: 0.26, delayMs: 150),
          _wave(262, 320, gain: 0.24, delayMs: 300),
        ]);
    }
  }

  Uint8List _wave(
    double freq,
    int ms, {
    double gain = 0.3,
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

  void _disposeSources(List<AudioSource> sources) {
    for (final source in sources) {
      unawaited(_disposeSource(source));
    }
  }

  Future<void> _disposeSource(AudioSource source) async {
    try {
      await _soloud.disposeSource(source);
    } catch (e) {
      _report('音频释放失败', e);
    }
  }

  void _ignore(Future<void> future) {
    unawaited(future.catchError((Object e) => _report('音频操作失败', e)));
  }

  /// 同类错误只写一次日志，避免每回合刷屏。
  void _report(String message, Object error, [StackTrace? stack]) {
    if (!_reported.add('$message|$error')) return;
    LogService.error('$message: $error', error, stack);
  }

  void dispose() {
    final sources = [..._sources.values, ?_bgmSource];
    _sources.clear();
    _bgmSource = null;
    _bgmHandle = null;
    _bgmRequested = false;
    if (_blocked) return;
    _disposeSources(sources);
  }
}
