import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import '../models/playback_state.dart';
import '../services/database_helper.dart';
import '../audio/audio_handler.dart';
import '../utils/asset_import_utils.dart';

class PlaybackProvider extends ChangeNotifier {
  final AudioHandler _audioHandler = AudioHandler();
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<Song> _library = [];
  List<Song> get library => _library;

  PlaybackStateModel _state = PlaybackStateModel(queue: []);
  PlaybackStateModel get state => _state;

  Song? get currentSong {
    if (_state.currentSongId == null) return null;
    try {
      return _library.firstWhere((s) => s.id == _state.currentSongId);
    } catch (_) {
      return null;
    }
  }

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  PlaybackProvider() {
    _init();
  }

  Future<void> _init() async {
    // 1. Unpack assets on first run before reading from SQLite
    await AssetImportUtils.deployBundledAssets();
    
    // 2. Load the library into memory
    await loadLibrary();
    
    // 3. Restore last playback state
    final savedState = await _db.readPlaybackState();
    if (savedState != null) {
      _state = savedState;
      _audioHandler.setCrossfadeDuration(_state.crossfadeDuration);
      notifyListeners();
    }
  }

  Future<void> loadLibrary() async {
    _library = await _db.readAllSongs();
    notifyListeners();
  }

  Future<void> playSong(Song song, {List<Song>? contextQueue}) async {
    if (contextQueue != null) {
      _state = _state.copyWith(
        queue: contextQueue.map((s) => s.id).toList(),
      );
    }

    _state = _state.copyWith(
      currentSongId: song.id,
      currentPosition: 0.0,
    );
    
    _isPlaying = true;
    notifyListeners();
    
    await _db.savePlaybackState(_state);
    await _audioHandler.play(song.filePath);
  }

  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    await _audioHandler.pause();
    // In a real implementation we would get the position from the native engine
  }

  Future<void> resume() async {
    if (currentSong == null) return;
    _isPlaying = true;
    notifyListeners();
    await _audioHandler.resume();
  }

  Future<void> next() async {
    if (_state.queue.isEmpty || currentSong == null) return;
    
    int currentIndex = _state.queue.indexOf(currentSong!.id);
    if (currentIndex == -1 || currentIndex == _state.queue.length - 1) {
       // Stop if it's the end of the queue, or loop back.
       if (_state.queue.isNotEmpty) {
           _playNextFromId(_state.queue.first);
       }
       return;
    }

    if (_state.shuffleEnabled) {
      _playNextShuffle(currentIndex);
    } else {
      _playNextFromId(_state.queue[currentIndex + 1]);
    }
  }

  Future<void> previous() async {
     if (_state.queue.isEmpty || currentSong == null) return;
     int currentIndex = _state.queue.indexOf(currentSong!.id);
     
     if (currentIndex <= 0) {
        // Go to start
        if (_state.queue.isNotEmpty) {
            _playNextFromId(_state.queue.last);
        }
        return;
     }

     _playNextFromId(_state.queue[currentIndex - 1]);
  }

  void _playNextFromId(String id) {
     final song = _library.firstWhere((s) => s.id == id, orElse: () => _library.first);
     playSong(song);
  }

  void _playNextShuffle(int currentIndex) {
      // Basic shuffle: pick a random song that is not the current one.
      // Advanced: avoid recent artists. Keeping it simple here for scaffolding.
      final random = Random();
      int nextIndex;
      do {
        nextIndex = random.nextInt(_state.queue.length);
      } while (nextIndex == currentIndex && _state.queue.length > 1);
      
      _playNextFromId(_state.queue[nextIndex]);
  }

  Future<void> toggleShuffle() async {
    _state = _state.copyWith(shuffleEnabled: !_state.shuffleEnabled);
    notifyListeners();
    await _db.savePlaybackState(_state);
  }

  Future<void> setCrossfadeDuration(double duration) async {
    _state = _state.copyWith(crossfadeDuration: duration);
    notifyListeners();
    await _audioHandler.setCrossfadeDuration(duration);
    await _db.savePlaybackState(_state);
  }
}
