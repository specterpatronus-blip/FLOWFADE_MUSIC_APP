import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../audio/audio_handler.dart';
import '../services/database_helper.dart';

class FileImportUtils {
  static Future<void> importMusicFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'flac'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final docDir = await getApplicationDocumentsDirectory();
    final audioHandler = AudioHandler();
    final db = DatabaseHelper.instance;

    for (var file in result.files) {
      if (file.path == null) continue;

      final originalFile = File(file.path!);
      final filename = file.name;
      final newPath = '${docDir.path}/$filename';

      // Copy to sandbox if not exists
      if (!File(newPath).existsSync()) {
        await originalFile.copy(newPath);
      }

      // Extract metadata
      final metadata = await audioHandler.extractMetadata(newPath);

      final String title = metadata['title'] ?? filename.split('.').first;
      final String artist = metadata['artist'] ?? 'Unknown Artist';
      final double duration = metadata['duration'] ?? 0.0;
      final String? artworkPath = metadata['artworkPath'];

      final String id = const Uuid().v4();

      final song = Song(
        id: id,
        filePath: newPath,
        originalFileName: filename,
        title: title,
        artist: artist,
        artworkPath: artworkPath,
        duration: duration,
        dateAdded: DateTime.now(),
        isMetadataEdited: metadata['title'] == null, 
      );

      await db.createSong(song);
    }
  }
}
