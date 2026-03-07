import 'dart:convert';
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
  static const String _assetsDeployedKey = 'flowfade_assets_deployed_v1';

  static Future<void> deployBundledAssets() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasDeployed = prefs.getBool(_assetsDeployedKey) ?? false;

    if (hasDeployed) {
      debugPrint('AssetImportUtils: Assets already deployed on previous launch. Skipping.');
      return;
    }

    debugPrint('AssetImportUtils: First launch detected! Extracting pre-bundled assets...');
    try {
      // 1. Read the AssetManifest to find all files in assets/musica/
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      
      final List<String> audioAssetPaths = manifestMap.keys
          .where((String key) => key.startsWith('assets/musica/') && 
                (key.endsWith('.mp3') || key.endsWith('.m4a') || key.endsWith('.wav') || key.endsWith('.flac')))
          .toList();

      if (audioAssetPaths.isEmpty) {
        debugPrint('AssetImportUtils: No audio assets found in assets/musica/.');
        await prefs.setBool(_assetsDeployedKey, true); // Don't keep trying if empty
        return;
      }

      debugPrint('AssetImportUtils: Found ${audioAssetPaths.length} bundled tracks.');

      // 2. Prepare Sandbox Directory
      final docDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${docDir.path}/audio');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      final audioHandler = AudioHandler();
      final db = DatabaseHelper.instance;

      // 3. Extract and Process Each Asset
      for (var assetPath in audioAssetPaths) {
        debugPrint('AssetImportUtils: Processing $assetPath ...');
        
        // Load bytes from bundle
        final ByteData data = await rootBundle.load(assetPath);
        final List<int> bytes = data.buffer.asUint8List();

        // Generate sandbox path
        final filename = assetPath.split('/').last;
        final extension = filename.split('.').last;
        final String id = const Uuid().v4();
        final newPath = '${audioDir.path}/$id.$extension';
        
        // Write to physical file so iOS AVAsset can read it
        final file = File(newPath);
        await file.writeAsBytes(bytes, flush: true);
        debugPrint('AssetImportUtils: Extracted to $newPath');

        // Extract metadata natively
        final metadata = await audioHandler.extractMetadata(newPath);
        
        final String actualTitle = metadata['title'] ?? filename.split('.').first;
        final String actualArtist = metadata['artist'] ?? 'Unknown Artist (Bundled)';
        
        double duration = 0.0;
        if (metadata['duration'] != null) {
          if (metadata['duration'] is int) {
              duration = (metadata['duration'] as int).toDouble();
          } else if (metadata['duration'] is double) {
              duration = metadata['duration'] as double;
          }
        }

        final song = Song(
          id: id,
          filePath: newPath,
          originalFileName: filename,
          title: actualTitle,
          artist: actualArtist,
          artworkPath: metadata['artworkPath'],
          duration: duration,
          dateAdded: DateTime.now(),
          isMetadataEdited: false, // Bundled shouldn't prompt edit
        );

        await db.createSong(song);
        debugPrint('AssetImportUtils: Saved ${song.title} to database.');
      }

      // Mark as deployed
      await prefs.setBool(_assetsDeployedKey, true);
      debugPrint('AssetImportUtils: All assets deployed successfully.');
      
    } catch (e, stack) {
      debugPrint('AssetImportUtils: FATAL ERROR expanding assets -> $e');
      debugPrint(stack.toString());
    }
  }
}
