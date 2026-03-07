import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../audio/audio_handler.dart';
import '../services/database_helper.dart';

class FileImportUtils {
  static Future<List<Song>> importMusicFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'flac'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return [];

    final docDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    
    final audioHandler = AudioHandler();
    List<Song> importedSongs = [];

    for (var file in result.files) {
      if (file.path == null) continue;

      final originalFile = File(file.path!);
      final filename = file.name;
      final extension = filename.split('.').last;
      
      final String id = const Uuid().v4();
      final newPath = '${audioDir.path}/$id.$extension';

      // Copy to sandbox destination
      await originalFile.copy(newPath);

      // Extract metadata natively
      final metadata = await audioHandler.extractMetadata(newPath);

      final String actualTitle = metadata['title'] ?? filename.split('.').first;
      final String actualArtist = metadata['artist'] ?? 'Unknown Artist';
      
      // Parse duration safely from different formats
      double duration = 0.0;
      if (metadata['duration'] != null) {
        if (metadata['duration'] is int) {
            duration = (metadata['duration'] as int).toDouble();
        } else if (metadata['duration'] is double) {
            duration = metadata['duration'] as double;
        }
      }

      final String? artworkPath = metadata['artworkPath'];

      // We mark isMetadataEdited as true if core metadata was missing,
      // so the UI knows to intercept this song before DB saving.
      final bool needsEdit = (metadata['title'] == null || metadata['artist'] == null);

      final song = Song(
        id: id,
        filePath: newPath,
        originalFileName: filename,
        title: actualTitle,
        artist: actualArtist,
        artworkPath: artworkPath,
        duration: duration,
        dateAdded: DateTime.now(),
        // We temporarily hijack this flag to signal the UI it needs editing
        isMetadataEdited: needsEdit, 
      );

      importedSongs.add(song);
    }
    
    return importedSongs;
  }
}
