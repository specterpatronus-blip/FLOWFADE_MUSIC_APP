import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';
import '../../utils/file_import_utils.dart';
import '../../models/song.dart';
import '../../services/database_helper.dart';
import 'now_playing_screen.dart';
import 'metadata_editor_screen.dart';
import '../widgets/mini_player.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlaybackProvider>().loadLibrary();
    });
  }

  Future<void> _importMusic() async {
    final importedSongs = await FileImportUtils.importMusicFiles(context);
    if (!mounted || importedSongs.isEmpty) return;

    final db = DatabaseHelper.instance;
    bool needsReload = false;

    for (var song in importedSongs) {
      if (song.isMetadataEdited) {
        // We hijacked this flag to mean "needs Edit" for new imports
        final songToEdit = song.copyWith(isMetadataEdited: false);
        final result = await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => MetadataEditorScreen(song: songToEdit, isNewImport: true),
          ),
        );
        if (result == true) {
            needsReload = true;
        }
      } else {
        await db.createSong(song);
        needsReload = true;
      }
    }

    if (!mounted || !needsReload) return;
    context.read<PlaybackProvider>().loadLibrary();
  }

  void _showContextMenu(BuildContext context, Song song) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(song.title),
        message: Text(song.artist),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Metadata Editor
            },
            child: const Text('Edit Metadata'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add to Playlist
            },
            child: const Text('Add to Playlist'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // TODO: Delete Song
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000), // Transparent
      navigationBar: CupertinoNavigationBar(
        backgroundColor: const Color(0x00000000), // Transparent
        border: null,
        middle: const Text('Library', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: CupertinoColors.white)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _importMusic,
          child: const Icon(CupertinoIcons.add, color: CupertinoColors.white),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
              child: Text(
                'Recent Discoveries',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Consumer<PlaybackProvider>(
                builder: (context, provider, child) {
                  if (provider.library.isEmpty) {
                    return const Center(child: Text('No music found.\nTap + to import.', textAlign: TextAlign.center, style: TextStyle(color: CupertinoColors.systemGrey)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: provider.library.length,
                    itemBuilder: (context, index) {
                      final song = provider.library[index];
                      return GestureDetector(
                        onLongPress: () => _showContextMenu(context, song),
                        onTap: () {
                          provider.playSong(song, contextQueue: provider.library);
                          Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const NowPlayingScreen()));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: const Color(0x1AFFFFFF), // Semi-transparent white
                            border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: CupertinoColors.black.withOpacity(0.3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: CupertinoColors.black.withOpacity(0.2),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      child: song.artworkPath != null 
                                          ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                                          : const Icon(CupertinoIcons.music_note, size: 28, color: CupertinoColors.systemGrey),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            song.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: CupertinoColors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            song.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: CupertinoColors.white.withOpacity(0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _showContextMenu(context, song),
                                      child: Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const MiniPlayerWidget(),
          ],
        ),
      ),
    );
  }
}
