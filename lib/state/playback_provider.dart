import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../audio/audio_crossfade_controller.dart';
import '../audio/audio_handler.dart';
import '../models/playback_state.dart';
import '../models/song.dart';
import '../services/database_helper.dart';
import '../utils/asset_import_utils.dart';

class PlaybackProvider extends ChangeNotifier {
  static const List<double> _crossfadeOptions = [0, 1, 3, 5, 8, 12];

  final AudioHandler _audioHandler = AudioHandler();
  final DatabaseHelper _db = DatabaseHelper.instance;
  late final AudioCrossfadeController _crossfadeController;

  List<Song> _library = [];
  List<Song> get library => _library;

  PlaybackStateModel _state = PlaybackStateModel(queue: []);
  PlaybackStateModel get state => _state;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  Duration _currentPosition = Duration.zero;
  Duration get currentPosition => _currentPosition;

  Duration _totalDuration = Duration.zero;
  Duration get totalDuration => _totalDuration;

  Duration _bufferedPosition = Duration.zero;
  Duration get bufferedPosition => _bufferedPosition;

  String? _lastError;
  String? get lastError => _lastError;

  Song? get currentSong {
    if (_state.currentSongId == null) return null;
    try {
      return _library.firstWhere((song) => song.id == _state.currentSongId);
    } catch (_) {
      return null;
    }
  }

  PlaybackProvider() {
    _crossfadeController = AudioCrossfadeController(
      onTrackChanged: (song, _) {
        _state = _state.copyWith(
          currentSongId: song.id,
          currentPosition: 0.0,
        );
        _currentPosition = Duration.zero;
        _bufferedPosition = Duration.zero;
        unawaited(_db.savePlaybackState(_state));
        notifyListeners();
      },
      onPositionChanged: (position) {
        _currentPosition = position;
        _state = _state.copyWith(
          currentPosition: position.inMilliseconds / 1000.0,
        );
        notifyListeners();
      },
      onDurationChanged: (duration) {
        _totalDuration = duration;
        notifyListeners();
      },
      onBufferedChanged: (buffered) {
        _bufferedPosition = buffered;
        notifyListeners();
      },
      onPlayingChanged: (playing) {
        _isPlaying = playing;
        notifyListeners();
      },
      onError: (message) {
        _lastError = message;
        notifyListeners();
      },
    );
    _init();
  }

  Future<void> _init() async {
    await AssetImportUtils.deployBundledAssets();
    await loadLibrary();

    final savedState = await _db.readPlaybackState();
    if (savedState != null) {
      final normalizedCrossfade = _normalizeCrossfadeDuration(savedState.crossfadeDuration);
      _state = savedState.copyWith(
        crossfadeDuration: normalizedCrossfade,
      );
      if (normalizedCrossfade != savedState.crossfadeDuration) {
        await _db.savePlaybackState(_state);
      }
    } else {
      _state = _state.copyWith(crossfadeDuration: 5.0);
    }

    _audioHandler.setNativeCommandHandler(
      onNextTrack: () => next(manual: true),
      onPreviousTrack: previous,
    );

    await _crossfadeController.setCrossfadeDuration(_state.crossfadeDuration);
    _crossfadeController.setShuffleEnabled(_state.shuffleEnabled);
    notifyListeners();
  }

  Future<void> loadLibrary() async {
    _library = await _db.readAllSongs();
    notifyListeners();
  }

  Future<bool> playSong(Song song, {List<Song>? contextQueue}) async {
    _lastError = null;

    final queueSongs = _buildQueueSongs(contextQueue: contextQueue);
    if (queueSongs.isEmpty) {
      _lastError = 'No hay canciones disponibles para reproducir.';
      notifyListeners();
      return false;
    }

    final startIndex = queueSongs.indexWhere((s) => s.id == song.id);
    if (startIndex == -1) {
      _lastError = 'La canción seleccionada no está en la cola actual.';
      notifyListeners();
      return false;
    }

    if (!File(song.filePath).existsSync()) {
      _lastError = 'Audio file not found on disk.';
      _isPlaying = false;
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(
      queue: queueSongs.map((s) => s.id).toList(),
      currentSongId: song.id,
      currentPosition: 0.0,
    );
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _bufferedPosition = Duration.zero;
    await _db.savePlaybackState(_state);

    await _crossfadeController.setCrossfadeDuration(_state.crossfadeDuration);
    _crossfadeController.setShuffleEnabled(_state.shuffleEnabled);
    await _crossfadeController.setPlaylist(
      queueSongs,
      startIndex: startIndex,
      autoplay: true,
    );

    _isPlaying = _crossfadeController.isPlaying;
    notifyListeners();
    return _isPlaying;
  }

  Future<void> pause() async {
    await _crossfadeController.pauseWithFade();
  }

  Future<void> resume() async {
    _lastError = null;
    await _crossfadeController.resumeWithFade();
  }

  Future<void> next({bool manual = true}) async {
    await _crossfadeController.next(manual: manual);
  }

  Future<void> previous() async {
    await _crossfadeController.previous();
  }

  Future<void> seek(Duration position) async {
    await _crossfadeController.seek(position);
  }

  Future<void> toggleShuffle() async {
    _state = _state.copyWith(shuffleEnabled: !_state.shuffleEnabled);
    _crossfadeController.setShuffleEnabled(_state.shuffleEnabled);
    await _db.savePlaybackState(_state);
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(double duration) async {
    final normalized = _normalizeCrossfadeDuration(duration);
    _state = _state.copyWith(crossfadeDuration: normalized);
    await _crossfadeController.setCrossfadeDuration(normalized);
    await _db.savePlaybackState(_state);
    notifyListeners();
  }

  List<Song> _buildQueueSongs({List<Song>? contextQueue}) {
    if (contextQueue != null && contextQueue.isNotEmpty) {
      return List<Song>.from(contextQueue);
    }

    if (_state.queue.isNotEmpty) {
      final mapped = _state.queue
          .map((id) => _library.where((song) => song.id == id))
          .where((matches) => matches.isNotEmpty)
          .map((matches) => matches.first)
          .toList();
      if (mapped.isNotEmpty) return mapped;
    }

    return List<Song>.from(_library);
  }

  double _normalizeCrossfadeDuration(double duration) {
    if (_crossfadeOptions.contains(duration)) {
      return duration;
    }

    double best = _crossfadeOptions.first;
    double minDistance = (duration - best).abs();
    for (final option in _crossfadeOptions) {
      final distance = (duration - option).abs();
      if (distance < minDistance) {
        minDistance = distance;
        best = option;
      }
    }
    return best;
  }

  @override
  void dispose() {
    unawaited(_crossfadeController.dispose());
    super.dispose();
  }
}
