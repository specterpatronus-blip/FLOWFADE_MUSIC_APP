import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../audio/audio_handler.dart';

class FileImportUtils {
  static Future<List<Song>> importMusicFiles(BuildContext context) async {
    debugPrint('FileImportUtils: Starting importMusicFiles...');
    try {
      debugPrint('FileImportUtils: Calling FilePicker.platform.pickFiles...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'flac'],
        allowMultiple: true,
      );

      if (result == null) {
        debugPrint('FileImportUtils: FilePicker returned null (user canceled).');
        return [];
      }
      
      if (result.files.isEmpty) {
        debugPrint('FileImportUtils: FilePicker returned an empty list of files.');
        return [];
      }

      debugPrint('FileImportUtils: FilePicker returned ${result.files.length} file(s).');

      final docDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docDir.path}/audio');
      debugPrint('FileImportUtils: Audio directory path -> ${audioDir.path}');
      
      if (!await audioDir.exists()) {
        debugPrint('FileImportUtils: Creating audio directory...');
        await audioDir.create(recursive: true);
      }
      
      final audioHandler = AudioHandler();
      List<Song> importedSongs = [];

      for (var file in result.files) {
        debugPrint('FileImportUtils: Processing file -> name: ${file.name}, path: ${file.path}');
        
        if (file.path == null) {
          debugPrint('FileImportUtils: WARNING - file.path is null for ${file.name}!');
          continue;
        }

        final originalFile = File(file.path!);
        if (!originalFile.existsSync()) {
          debugPrint('FileImportUtils: WARNING - original file does not exist at ${file.path!}');
          continue;
        }

        final filename = file.name;
        final extension = filename.split('.').last;
        
        final String id = const Uuid().v4();
        final newPath = '${audioDir.path}/$id.$extension';
        debugPrint('FileImportUtils: Generated new sandbox path -> $newPath');

        // Copy to sandbox destination
        debugPrint('FileImportUtils: Copying file to sandbox...');
        await originalFile.copy(newPath);
        debugPrint('FileImportUtils: File copied successfully.');

        // Extract metadata natively
        debugPrint('FileImportUtils: Calling AudioHandler.extractMetadata...');
        final metadata = await audioHandler.extractMetadata(newPath);
        debugPrint('FileImportUtils: Metadata extracted -> $metadata');

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
        debugPrint('FileImportUtils: Song needsEdit? $needsEdit');

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
        debugPrint('FileImportUtils: Successfully processed ${file.name}.');
      }
      
      debugPrint('FileImportUtils: Finished processing all files. Returning ${importedSongs.length} songs.');
      return importedSongs;
    } catch (e, stacktrace) {
      debugPrint('FileImportUtils: FATAL ERROR during import -> $e');
      debugPrint('FileImportUtils: STACKTRACE -> $stacktrace');
      return [];
    }
  }
}
