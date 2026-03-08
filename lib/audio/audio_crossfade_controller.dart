import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

typedef TrackChangedCallback = void Function(Song song, int index);
typedef PositionChangedCallback = void Function(Duration position);
typedef DurationChangedCallback = void Function(Duration duration);
typedef BufferedChangedCallback = void Function(Duration buffered);
typedef PlayingChangedCallback = void Function(bool isPlaying);
typedef PlaybackErrorCallback = void Function(String message);

class AudioCrossfadeController {
  AudioCrossfadeController({
    this.onTrackChanged,
    this.onPositionChanged,
    this.onDurationChanged,
    this.onBufferedChanged,
    this.onPlayingChanged,
    this.onError,
  }) {
    _activePlayerRef = _playerA;
    _inactivePlayerRef = _playerB;
    _bindActivePlayerListeners();
  }

  final TrackChangedCallback? onTrackChanged;
  final PositionChangedCallback? onPositionChanged;
  final DurationChangedCallback? onDurationChanged;
  final BufferedChangedCallback? onBufferedChanged;
  final PlayingChangedCallback? onPlayingChanged;
  final PlaybackErrorCallback? onError;

  final AudioPlayer _playerA = AudioPlayer();
  final AudioPlayer _playerB = AudioPlayer();

  late AudioPlayer _activePlayerRef;
  late AudioPlayer _inactivePlayerRef;

  List<Song> _playlist = [];
  int _currentIndex = -1;
  int? _preparedNextIndex;
  bool _shuffleEnabled = false;
  bool _isDisposed = false;
  bool _isTransitioning = false;
  bool _isPlaying = false;

  double _crossfadeDuration = 5.0;

  StreamSubscription<PlayerState>? _activePlayerStateSub;
  StreamSubscription<Duration>? _activePositionSub;
  StreamSubscription<Duration?>? _activeDurationSub;
  StreamSubscription<Duration>? _activeBufferedSub;

  static const Duration _fadeStep = Duration(milliseconds: 50);

  Song? get currentSong =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;
  int? get currentIndex => _currentIndex >= 0 ? _currentIndex : null;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _activePlayer.position;
  Duration get totalDuration => _activePlayer.duration ?? Duration.zero;
  Duration get bufferedPosition => _activePlayer.bufferedPosition;

  Future<void> setCrossfadeDuration(double seconds) async {
    _crossfadeDuration = seconds.clamp(0.0, 12.0).toDouble();
  }

  void setShuffleEnabled(bool enabled) {
    _shuffleEnabled = enabled;
    _preparedNextIndex = _resolveNextIndex();
    unawaited(_prepareInactivePlayer());
  }

  Future<void> setPlaylist(
    List<Song> playlist, {
    required int startIndex,
    bool autoplay = true,
  }) async {
    if (_isDisposed) return;
    if (playlist.isEmpty || startIndex < 0 || startIndex >= playlist.length) {
      return;
    }

    _playlist = List<Song>.from(playlist);
    _currentIndex = startIndex;
    _preparedNextIndex = _resolveNextIndex();

    try {
      await _activePlayer.stop();
      await _inactivePlayer.stop();
      await _activePlayer.setVolume(1.0);
      await _inactivePlayer.setVolume(0.0);
      await _activePlayer.setFilePath(_playlist[_currentIndex].filePath);
      await _prepareInactivePlayer();

      onTrackChanged?.call(_playlist[_currentIndex], _currentIndex);
      onPositionChanged?.call(Duration.zero);
      onDurationChanged?.call(_activePlayer.duration ?? Duration.zero);
      onBufferedChanged?.call(_activePlayer.bufferedPosition);

      if (autoplay) {
        await _activePlayer.play();
        _setPlaying(true);
      } else {
        _setPlaying(false);
      }
    } catch (e) {
      onError?.call('No se pudo preparar la pista: $e');
    }
  }

  Future<void> play() async {
    if (_isDisposed || _currentIndex == -1) return;
    await _activePlayer.play();
    _setPlaying(true);
  }

  Future<void> pauseWithFade({Duration duration = const Duration(milliseconds: 500)}) async {
    if (_isDisposed || !_isPlaying) return;
    await _fadeSinglePlayer(_activePlayer, from: _activePlayer.volume, to: 0.0, duration: duration);
    await _activePlayer.pause();
    await _activePlayer.setVolume(1.0);
    _setPlaying(false);
  }

  Future<void> resumeWithFade({Duration duration = const Duration(milliseconds: 500)}) async {
    if (_isDisposed || _currentIndex == -1 || _isPlaying) return;
    await _activePlayer.setVolume(0.0);
    await _activePlayer.play();
    _setPlaying(true);
    await _fadeSinglePlayer(_activePlayer, from: 0.0, to: 1.0, duration: duration);
  }

  Future<void> seek(Duration position) async {
    if (_isDisposed || _currentIndex == -1) return;
    final duration = _activePlayer.duration ?? Duration.zero;
    final clamped = duration > Duration.zero
        ? Duration(milliseconds: position.inMilliseconds.clamp(0, duration.inMilliseconds).toInt())
        : Duration(milliseconds: max(0, position.inMilliseconds).toInt());
    await _activePlayer.seek(clamped);
    onPositionChanged?.call(clamped);
  }

  Future<void> next({bool manual = false}) async {
    final targetIndex = _resolveNextIndex();
    if (targetIndex == null || _isTransitioning) return;

    final fadeSeconds = manual ? 1.5 : _crossfadeDuration;
    if (fadeSeconds <= 0) {
      await _advanceWithoutFade(targetIndex);
      return;
    }
    await _executeCrossfade(targetIndex: targetIndex, duration: Duration(milliseconds: (fadeSeconds * 1000).round()));
  }

  Future<void> previous() async {
    if (_isDisposed || _currentIndex == -1 || _playlist.isEmpty || _isTransitioning) return;
    final currentPosition = _activePlayer.position.inMilliseconds / 1000.0;

    if (currentPosition >= 3.0) {
      await _activePlayer.seek(Duration.zero);
      onPositionChanged?.call(Duration.zero);
      return;
    }

    int previousIndex;
    if (_shuffleEnabled) {
      previousIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    } else {
      previousIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
    }
    await _executeCrossfade(
      targetIndex: previousIndex,
      duration: const Duration(milliseconds: 1500),
    );
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _activePlayerStateSub?.cancel();
    await _activePositionSub?.cancel();
    await _activeDurationSub?.cancel();
    await _activeBufferedSub?.cancel();
    await _playerA.dispose();
    await _playerB.dispose();
  }

  AudioPlayer get _activePlayer => _activePlayerRef;
  AudioPlayer get _inactivePlayer => _inactivePlayerRef;

  void _bindActivePlayerListeners() {
    _activePlayerStateSub?.cancel();
    _activePositionSub?.cancel();
    _activeDurationSub?.cancel();
    _activeBufferedSub?.cancel();

    _activePlayerStateSub = _activePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && !_isTransitioning) {
        final nextIndex = _resolveNextIndex();
        if (nextIndex != null) {
          unawaited(next(manual: false));
        } else {
          _setPlaying(false);
        }
      }
    });

    _activePositionSub = _activePlayer.positionStream.listen((position) {
      onPositionChanged?.call(position);
      _maybeTriggerAutoCrossfade(position);
    });

    _activeDurationSub = _activePlayer.durationStream.listen((duration) {
      onDurationChanged?.call(duration ?? Duration.zero);
    });

    _activeBufferedSub = _activePlayer.bufferedPositionStream.listen((buffered) {
      onBufferedChanged?.call(buffered);
    });
  }

  void _swapPlayers() {
    final oldActive = _activePlayerRef;
    _activePlayerRef = _inactivePlayerRef;
    _inactivePlayerRef = oldActive;
    _bindActivePlayerListeners();
    onDurationChanged?.call(_activePlayer.duration ?? Duration.zero);
    onBufferedChanged?.call(_activePlayer.bufferedPosition);
    onPositionChanged?.call(_activePlayer.position);
  }

  void _maybeTriggerAutoCrossfade(Duration position) {
    if (_isDisposed || !_isPlaying || _isTransitioning || _crossfadeDuration <= 0) return;
    final duration = _activePlayer.duration;
    if (duration == null || duration <= Duration.zero) return;

    final targetIndex = _resolveNextIndex();
    if (targetIndex == null) return;

    final remaining = duration - position;
    if (remaining <= Duration(milliseconds: (_crossfadeDuration * 1000).round()) &&
        remaining > const Duration(milliseconds: 50)) {
      unawaited(next(manual: false));
    }
  }

  int? _resolveNextIndex() {
    if (_playlist.isEmpty || _currentIndex == -1) return null;

    if (_shuffleEnabled) {
      if (_playlist.length <= 1) return null;
      final random = Random();
      int candidate = _currentIndex;
      while (candidate == _currentIndex) {
        candidate = random.nextInt(_playlist.length);
      }
      return candidate;
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _playlist.length) return null;
    return nextIndex;
  }

  Future<void> _prepareInactivePlayer() async {
    if (_preparedNextIndex == null) return;

    final nextSong = _playlist[_preparedNextIndex!];
    try {
      await _inactivePlayer.stop();
      await _inactivePlayer.setVolume(0.0);
      await _inactivePlayer.setFilePath(nextSong.filePath);
    } catch (e) {
      onError?.call('No se pudo precargar la siguiente pista: $e');
    }
  }

  Future<void> _advanceWithoutFade(int targetIndex) async {
    if (_isDisposed || targetIndex < 0 || targetIndex >= _playlist.length) return;
    _isTransitioning = true;
    try {
      await _activePlayer.stop();
      await _activePlayer.setVolume(1.0);
      await _activePlayer.setFilePath(_playlist[targetIndex].filePath);
      _currentIndex = targetIndex;
      _preparedNextIndex = _resolveNextIndex();
      await _prepareInactivePlayer();
      onTrackChanged?.call(_playlist[_currentIndex], _currentIndex);
      onPositionChanged?.call(Duration.zero);
      onDurationChanged?.call(_activePlayer.duration ?? Duration.zero);
      onBufferedChanged?.call(_activePlayer.bufferedPosition);
      await _activePlayer.play();
      _setPlaying(true);
    } catch (e) {
      onError?.call('No se pudo avanzar a la siguiente pista: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _executeCrossfade({
    required int targetIndex,
    required Duration duration,
  }) async {
    if (_isDisposed || targetIndex < 0 || targetIndex >= _playlist.length) return;
    _isTransitioning = true;

    try {
      if (_preparedNextIndex != targetIndex) {
        _preparedNextIndex = targetIndex;
        await _prepareInactivePlayer();
      }

      await _inactivePlayer.setVolume(0.0);
      await _inactivePlayer.play();

      final totalMs = duration.inMilliseconds;
      final steps = max(1, (totalMs / _fadeStep.inMilliseconds).round());
      for (int i = 0; i <= steps; i++) {
        if (_isDisposed) return;
        final p = i / steps;
        final fadeOut = cos(p * pi / 2);
        final fadeIn = sin(p * pi / 2);
        await _activePlayer.setVolume(fadeOut);
        await _inactivePlayer.setVolume(fadeIn);
        await Future<void>.delayed(_fadeStep);
      }

      await _activePlayer.stop();
      await _activePlayer.setVolume(0.0);
      await _inactivePlayer.setVolume(1.0);
      _swapPlayers();

      _currentIndex = targetIndex;
      _preparedNextIndex = _resolveNextIndex();
      await _prepareInactivePlayer();
      onTrackChanged?.call(_playlist[_currentIndex], _currentIndex);
      onPositionChanged?.call(Duration.zero);
      _setPlaying(true);
    } catch (e) {
      onError?.call('Error durante crossfade: $e');
      _setPlaying(_activePlayer.playing);
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _fadeSinglePlayer(
    AudioPlayer player, {
    required double from,
    required double to,
    required Duration duration,
  }) async {
    final totalMs = duration.inMilliseconds;
    final steps = max(1, (totalMs / _fadeStep.inMilliseconds).round());
    for (int i = 0; i <= steps; i++) {
      if (_isDisposed) return;
      final t = i / steps;
      final eased = 0.5 - 0.5 * cos(pi * t);
      final volume = from + (to - from) * eased;
      await player.setVolume(volume.clamp(0.0, 1.0).toDouble());
      await Future<void>.delayed(_fadeStep);
    }
  }

  void _setPlaying(bool value) {
    if (_isPlaying == value) return;
    _isPlaying = value;
    onPlayingChanged?.call(_isPlaying);
  }
}
