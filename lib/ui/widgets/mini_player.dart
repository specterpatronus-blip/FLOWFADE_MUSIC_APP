import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';
import '../screens/now_playing_screen.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackProvider>(
      builder: (context, provider, child) {
        final song = provider.currentSong;
        if (song == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const NowPlayingScreen()));
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              border: Border(top: BorderSide(color: CupertinoColors.systemGrey.withOpacity(0.3), width: 0.5)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                // Artwork thumbnail
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: CupertinoColors.systemGrey4,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: song.artworkPath != null
                      ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                      : const Icon(CupertinoIcons.music_note, color: CupertinoColors.systemGrey),
                ),
                const SizedBox(width: 12),
                
                // Track Info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                    ],
                  ),
                ),
                
                // Play/Pause Button
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: provider.isPlaying ? provider.pause : provider.resume,
                  child: Icon(
                    provider.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                    size: 30,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
