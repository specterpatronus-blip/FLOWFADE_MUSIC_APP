import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../audio/audio_handler.dart';
import '../services/database_helper.dart';

class AssetImportUtils {
  static const String _assetsDeployedKey = 'flowfade_assets_deployed_v2';

  // ── HARDCODED LIST OF BUNDLED TRACKS ──
  // These must exactly match the filenames inside assets/musica/
  static const List<String> _bundledTracks = [
    'Blinding Lights.mp3',
    'End of Beginning.mp3',
  ];

  static Future<void> deployBundledAssets() async {
    debugPrint('AssetImportUtils: deployBundledAssets() called.');

    final prefs = await SharedPreferences.getInstance();
    final bool hasDeployed = prefs.getBool(_assetsDeployedKey) ?? false;

    if (hasDeployed) {
      debugPrint('AssetImportUtils: Assets already deployed. Skipping.');
      return;
    }

    debugPrint('AssetImportUtils: First launch detected! Deploying ${_bundledTracks.length} bundled tracks...');

    try {
      // 1. Prepare Sandbox Directory
      final docDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docDir.path}/audio');
      if (!await audioDir.exists()) {
        debugPrint('AssetImportUtils: Creating audio directory...');
        await audioDir.create(recursive: true);
      }
      debugPrint('AssetImportUtils: Audio dir -> ${audioDir.path}');

      final db = DatabaseHelper.instance;

      // 2. Process each hardcoded track
      for (var filename in _bundledTracks) {
        debugPrint('AssetImportUtils: --- Processing "$filename" ---');

        try {
          // Load bytes from the Flutter asset bundle
          final assetKey = 'assets/musica/$filename';
          debugPrint('AssetImportUtils: Loading asset key: $assetKey');
          final ByteData data = await rootBundle.load(assetKey);
          final List<int> bytes = data.buffer.asUint8List();
          debugPrint('AssetImportUtils: Loaded ${bytes.length} bytes from bundle.');

          // Generate a UUID-based path in the sandbox
          final extension_ = filename.split('.').last;
          final String id = const Uuid().v4();
          final newPath = '${audioDir.path}/$id.$extension_';

          // Write to physical file
          final file = File(newPath);
          await file.writeAsBytes(bytes, flush: true);
          debugPrint('AssetImportUtils: Written to $newPath');

          // Verify file exists
          if (!file.existsSync()) {
            debugPrint('AssetImportUtils: ERROR - File was not created at $newPath');
            continue;
          }
          debugPrint('AssetImportUtils: File confirmed on disk. Size: ${file.lengthSync()} bytes');

          // Use filename as the default title (strip extension)
          String title = filename.split('.').first;
          String artist = 'Unknown Artist';
          double duration = 0.0;
          String? artworkPath;

          // Try extracting metadata via native, but don't block if it fails
          try {
            debugPrint('AssetImportUtils: Attempting native metadata extraction...');
            final audioHandler = AudioHandler();
            final metadata = await audioHandler.extractMetadata(newPath)
                .timeout(const Duration(seconds: 5));
            debugPrint('AssetImportUtils: Metadata result -> $metadata');

            if (metadata['title'] != null && (metadata['title'] as String).isNotEmpty) {
              title = metadata['title'] as String;
            }
            if (metadata['artist'] != null && (metadata['artist'] as String).isNotEmpty) {
              artist = metadata['artist'] as String;
            }
            if (metadata['duration'] != null) {
              if (metadata['duration'] is int) {
                duration = (metadata['duration'] as int).toDouble();
              } else if (metadata['duration'] is double) {
                duration = metadata['duration'] as double;
              }
            }
            if (metadata['artworkPath'] != null) {
              artworkPath = metadata['artworkPath'] as String;
            }
          } catch (metaError) {
            debugPrint('AssetImportUtils: Metadata extraction failed (non-fatal): $metaError');
            // Continue with defaults - the song will still be playable
          }

          // Create Song object and save to SQLite
          final song = Song(
            id: id,
            filePath: newPath,
            originalFileName: filename,
            title: title,
            artist: artist,
            artworkPath: artworkPath,
            duration: duration,
            dateAdded: DateTime.now(),
            isMetadataEdited: false,
          );

          await db.createSong(song);
          debugPrint('AssetImportUtils: ✅ Saved "$title" by "$artist" to database.');

        } catch (fileError, fileStack) {
          debugPrint('AssetImportUtils: ERROR processing "$filename": $fileError');
          debugPrint('$fileStack');
          // Continue to next file even if one fails
        }
      }

      // Mark as deployed so we don't repeat
      await prefs.setBool(_assetsDeployedKey, true);
      debugPrint('AssetImportUtils: ✅ All assets deployed successfully!');

    } catch (e, stack) {
      debugPrint('AssetImportUtils: FATAL ERROR during deployment -> $e');
      debugPrint('$stack');
    }
  }
}
