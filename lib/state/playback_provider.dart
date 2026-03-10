import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_crossfade_controller.dart';
import '../audio/audio_handler.dart';
import '../models/playback_state.dart';
import '../models/song.dart';
import '../services/database_helper.dart';
import '../utils/asset_import_utils.dart';

class PlaybackProvider extends ChangeNotifier {
  static const List<double> _crossfadeOptions = [0, 1, 3, 5, 8, 12];
  static const int _recentMemorySize = 4;

  final AudioHandler _audioHandler = AudioHandler();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final Queue<String> _recentTrackIds = Queue<String>();
  late final AudioCrossfadeController _crossfadeController;

  List<Song> _library = [];
  PlaybackStateModel _state = PlaybackStateModel(queue: []);

  bool _isPlaying = false;
  bool _isRestoring = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _bufferedPosition = Duration.zero;
  String? _lastError;
  Timer? _persistTimer;

  List<Song> get library => _library;
  PlaybackStateModel get state => _state;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  Duration get bufferedPosition => _bufferedPosition;
  String? get lastError => _lastError;

  List<Song> get playbackQueue => _songsFromQueueIds(_state.queue);

  int get currentIndex {
    if (playbackQueue.isEmpty) return -1;
    return _state.currentIndex.clamp(0, playbackQueue.length - 1);
  }

  Song? get currentSong {
    final queue = playbackQueue;
    if (queue.isEmpty || currentIndex == -1) return null;
    return queue[currentIndex];
  }

  List<Song> get upNext {
    final queue = playbackQueue;
    if (queue.isEmpty || currentIndex == -1) return const [];
    return queue.skip(currentIndex + 1).toList();
  }

  PlaybackProvider() {
    _crossfadeController = AudioCrossfadeController(
      onTrackChanged: (song, index) {
        final queue = playbackQueue;
        final safeIndex = queue.isEmpty
            ? index
            : index.clamp(0, queue.length - 1);
        _rememberTrack(song.id);
        _state = _state.copyWith(
          currentSongId: song.id,
          currentIndex: safeIndex,
          currentPosition: 0.0,
          isPlaying: true,
        );
        _currentPosition = Duration.zero;
        _bufferedPosition = Duration.zero;
        _persistPlaybackState(immediate: true);
        notifyListeners();
      },
      onPositionChanged: (position) {
        _currentPosition = position;
        _state = _state.copyWith(
          currentPosition: position.inMilliseconds / 1000.0,
        );
        _persistPlaybackState();
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
        _state = _state.copyWith(isPlaying: playing);
        _persistPlaybackState(immediate: true);
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
      final normalizedCrossfade = _normalizeCrossfadeDuration(
        savedState.crossfadeDuration,
      );
      _state = savedState.copyWith(crossfadeDuration: normalizedCrossfade);
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
    await restoreQueue();
    notifyListeners();
  }

  Future<void> loadLibrary() async {
    _library = await _db.readAllSongs();
    notifyListeners();
  }

  Future<bool> playSong(Song song, {List<Song>? contextQueue}) async {
    _lastError = null;

    final sourceSongs = contextQueue != null && contextQueue.isNotEmpty
        ? List<Song>.from(contextQueue)
        : List<Song>.from(_library);
    final queueSongs = _buildRotatedQueue(sourceSongs, song);
    if (queueSongs.isEmpty) {
      _lastError = 'No hay canciones disponibles para reproducir.';
      notifyListeners();
      return false;
    }

    final current = queueSongs.first;
    if (!File(current.filePath).existsSync()) {
      _lastError = 'Audio file not found on disk.';
      _isPlaying = false;
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(
      queue: queueSongs.map((s) => s.id).toList(),
      currentSongId: current.id,
      currentIndex: 0,
      currentPosition: 0.0,
      isPlaying: true,
    );
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;
    _bufferedPosition = Duration.zero;
    _rememberTrack(current.id);

    await _crossfadeController.setCrossfadeDuration(_state.crossfadeDuration);
    await _crossfadeController.setPlaylist(
      queueSongs,
      startIndex: 0,
      autoplay: true,
    );

    _isPlaying = _crossfadeController.isPlaying;
    await _db.savePlaybackState(_state.copyWith(isPlaying: _isPlaying));
    notifyListeners();
    return _isPlaying;
  }

  Future<void> restoreQueue() async {
    final queueSongs = _songsFromQueueIds(_state.queue);
    if (queueSongs.isEmpty) {
      return;
    }

    final restoredIndex = _resolveRestoredIndex(queueSongs);
    _state = _state.copyWith(
      queue: queueSongs.map((song) => song.id).toList(),
      currentIndex: restoredIndex,
      currentSongId: queueSongs[restoredIndex].id,
    );

    _isRestoring = true;
    try {
      await _crossfadeController.setPlaylist(
        queueSongs,
        startIndex: restoredIndex,
        autoplay: _state.isPlaying,
      );

      final savedPosition = Duration(
        milliseconds: (_state.currentPosition * 1000).round(),
      );
      if (savedPosition > Duration.zero) {
        await _crossfadeController.seek(savedPosition);
      }

      _currentPosition = savedPosition;
      _rememberTrack(queueSongs[restoredIndex].id);
      _isPlaying = _state.isPlaying;
    } finally {
      _isRestoring = false;
    }
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
    _currentPosition = position;
    _state = _state.copyWith(currentPosition: position.inMilliseconds / 1000.0);
    _persistPlaybackState(immediate: true);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    final enabled = !_state.shuffleEnabled;
    _state = _state.copyWith(shuffleEnabled: enabled);

    if (playbackQueue.isNotEmpty) {
      if (enabled) {
        await shuffleQueue();
      } else {
        await _rebuildQueueFromLibraryOrder();
      }
    } else {
      await _db.savePlaybackState(_state);
      notifyListeners();
    }
  }

  Future<void> shuffleQueue() async {
    final queue = playbackQueue;
    final song = currentSong;
    if (queue.isEmpty || song == null) return;

    final remaining = queue.where((item) => item.id != song.id).toList();
    final shuffled = _buildSmartShuffle(remaining);
    final newQueue = [song, ...shuffled];

    _state = _state.copyWith(
      queue: newQueue.map((item) => item.id).toList(),
      currentSongId: song.id,
      currentIndex: 0,
    );

    await _crossfadeController.updateQueue(newQueue, currentIndex: 0);
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

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    final queue = playbackQueue;
    if (queue.length <= 1 || currentIndex == -1) return;
    if (oldIndex <= currentIndex || newIndex <= currentIndex) return;
    if (oldIndex >= queue.length || newIndex > queue.length) return;

    final mutable = List<Song>.from(queue);
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = mutable.removeAt(oldIndex);
    mutable.insert(adjustedIndex, item);

    _state = _state.copyWith(
      queue: mutable.map((song) => song.id).toList(),
      currentSongId: mutable[currentIndex].id,
    );

    await _crossfadeController.updateQueue(mutable, currentIndex: currentIndex);
    await _db.savePlaybackState(_state);
    notifyListeners();
  }

  Future<void> jumpToQueueIndex(int index) async {
    final queue = playbackQueue;
    if (index < 0 || index >= queue.length) return;
    await _crossfadeController.jumpToIndex(index);
  }

  List<Song> _songsFromQueueIds(List<String> queueIds) {
    if (_library.isEmpty || queueIds.isEmpty) return const [];

    final songById = {for (final song in _library) song.id: song};
    return queueIds.map((id) => songById[id]).whereType<Song>().toList();
  }

  List<Song> _buildRotatedQueue(List<Song> sourceSongs, Song selectedSong) {
    final startIndex = sourceSongs.indexWhere(
      (song) => song.id == selectedSong.id,
    );
    if (startIndex == -1) return const [];

    return [...sourceSongs.skip(startIndex), ...sourceSongs.take(startIndex)];
  }

  int _resolveRestoredIndex(List<Song> queueSongs) {
    final byIndex = _state.currentIndex.clamp(0, queueSongs.length - 1);
    if (_state.currentSongId == null) {
      return byIndex;
    }

    final byId = queueSongs.indexWhere(
      (song) => song.id == _state.currentSongId,
    );
    return byId == -1 ? byIndex : byId;
  }

  List<Song> _buildSmartShuffle(List<Song> songs) {
    final random = Random();
    final pool = List<Song>.from(songs);
    final recent = Queue<String>.from(_recentTrackIds);
    final shuffled = <Song>[];

    while (pool.isNotEmpty) {
      final recentSet = recent.toSet();
      final eligible = pool
          .where((song) => !recentSet.contains(song.id))
          .toList();
      final candidates = eligible.isNotEmpty ? eligible : pool;
      final nextSong = candidates[random.nextInt(candidates.length)];
      shuffled.add(nextSong);
      pool.removeWhere((song) => song.id == nextSong.id);
      recent.add(nextSong.id);
      while (recent.length > _recentMemorySize) {
        recent.removeFirst();
      }
    }

    return shuffled;
  }

  Future<void> _rebuildQueueFromLibraryOrder() async {
    final song = currentSong;
    if (song == null || _library.isEmpty) return;

    final rebuiltQueue = _buildRotatedQueue(_library, song);
    if (rebuiltQueue.isEmpty) return;

    _state = _state.copyWith(
      queue: rebuiltQueue.map((item) => item.id).toList(),
      currentSongId: song.id,
      currentIndex: 0,
    );

    await _crossfadeController.updateQueue(rebuiltQueue, currentIndex: 0);
    await _db.savePlaybackState(_state);
    notifyListeners();
  }

  void _rememberTrack(String songId) {
    if (_recentTrackIds.isNotEmpty && _recentTrackIds.last == songId) {
      return;
    }

    _recentTrackIds.add(songId);
    while (_recentTrackIds.length > _recentMemorySize) {
      _recentTrackIds.removeFirst();
    }
  }

  void _persistPlaybackState({bool immediate = false}) {
    if (_isRestoring) return;

    _persistTimer?.cancel();
    if (immediate) {
      unawaited(_db.savePlaybackState(_state));
      return;
    }

    _persistTimer = Timer(const Duration(seconds: 1), () {
      unawaited(_db.savePlaybackState(_state));
    });
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
    _persistTimer?.cancel();
    unawaited(_db.savePlaybackState(_state));
    unawaited(_crossfadeController.dispose());
    super.dispose();
  }
}
