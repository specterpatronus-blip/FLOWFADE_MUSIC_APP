import 'dart:io';
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Library'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _importMusic,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Consumer<PlaybackProvider>(
                builder: (context, provider, child) {
                  if (provider.library.isEmpty) {
                    return const Center(child: Text('No music found.\nTap + to import.', textAlign: TextAlign.center, style: TextStyle(color: CupertinoColors.systemGrey)));
                  }

                  return ListView.builder(
                    itemCount: provider.library.length,
                    itemBuilder: (context, index) {
                      final song = provider.library[index];
                      return GestureDetector(
                        onLongPress: () => _showContextMenu(context, song),
                        child: CupertinoListTile(
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CupertinoColors.systemGrey)),
                          leading: song.artworkPath != null 
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.file(File(song.artworkPath!), width: 40, height: 40, fit: BoxFit.cover))
                              : const Icon(CupertinoIcons.music_note, size: 30, color: CupertinoColors.systemGrey),
                          onTap: () {
                            provider.playSong(song, contextQueue: provider.library);
                            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const NowPlayingScreen()));
                          },
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
