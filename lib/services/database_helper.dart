import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/playback_state.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('flowfade.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const doubleType = 'REAL NOT NULL';
    const integerType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE songs (
  id $idType,
  filePath $textType,
  originalFileName $textType,
  title $textType,
  artist $textType,
  artworkPath $textNullable,
  duration $doubleType,
  dateAdded $textType,
  isMetadataEdited $integerType
)
''');

    await db.execute('''
CREATE TABLE playlists (
  id $idType,
  name $textType,
  dateCreated $textType
)
''');

    await db.execute('''
CREATE TABLE playlist_songs (
  playlistId $textNullable,
  songId $textNullable,
  position $integerType,
  FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
  FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE playback_state (
  id INTEGER PRIMARY KEY,
  currentSongId $textNullable,
  currentPosition $doubleType,
  queue $textNullable,
  shuffleEnabled $integerType,
  crossfadeDuration $doubleType
)
''');
  }

  // --- CRUD Songs ---
  Future<void> createSong(Song song) async {
    final db = await instance.database;
    await db.insert('songs', song.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Song?> readSong(String id) async {
    final db = await instance.database;
    final maps = await db.query('songs',
        columns: ['id', 'filePath', 'originalFileName', 'title', 'artist', 'artworkPath', 'duration', 'dateAdded', 'isMetadataEdited'],
        where: 'id = ?',
        whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Song.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Song>> readAllSongs() async {
    final db = await instance.database;
    const orderBy = 'title ASC';
    final result = await db.query('songs', orderBy: orderBy);
    return result.map((json) => Song.fromMap(json)).toList();
  }

  Future<void> updateSong(Song song) async {
    final db = await instance.database;
    await db.update('songs', song.toMap(), where: 'id = ?', whereArgs: [song.id]);
  }

  Future<void> deleteSong(String id) async {
    final db = await instance.database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  // --- CRUD Playlists ---
  Future<void> createPlaylist(Playlist playlist) async {
    final db = await instance.database;
    await db.insert('playlists', playlist.toMap());
    for (int i = 0; i < playlist.songIds.length; i++) {
        await db.insert('playlist_songs', {
            'playlistId': playlist.id,
            'songId': playlist.songIds[i],
            'position': i
        });
    }
  }

  Future<List<Playlist>> readAllPlaylists() async {
    final db = await instance.database;
    final playlistsMap = await db.query('playlists', orderBy: 'dateCreated DESC');
    
    List<Playlist> playlists = [];
    for (var pMap in playlistsMap) {
        final id = pMap['id'] as String;
        final songsMap = await db.query('playlist_songs', where: 'playlistId = ?', whereArgs: [id], orderBy: 'position ASC');
        final songIds = songsMap.map((s) => s['songId'] as String).toList();
        playlists.add(Playlist.fromMap(pMap, songIds: songIds));
    }
    return playlists;
  }

  Future<void> deletePlaylist(String id) async {
    final db = await instance.database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  // --- Playback State ---
  Future<PlaybackStateModel?> readPlaybackState() async {
    final db = await instance.database;
    final result = await db.query('playback_state', where: 'id = ?', whereArgs: [1]);
    if (result.isNotEmpty) {
      return PlaybackStateModel.fromMap(result.first);
    }
    return null;
  }

  Future<void> savePlaybackState(PlaybackStateModel state) async {
    final db = await instance.database;
    final exist = await readPlaybackState();
    if (exist != null) {
      await db.update('playback_state', state.toMap(), where: 'id = ?', whereArgs: [1]);
    } else {
      await db.insert('playback_state', state.toMap());
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
