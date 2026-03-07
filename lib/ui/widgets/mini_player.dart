import 'dart:io';
import 'dart:ui';
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const NowPlayingScreen()));
            },
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: const Color(0x2AFFFFFF), // Slightly more opaque for the mini player
                border: Border.all(color: const Color(0x33FFFFFF), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      // Circular Artwork thumbnail
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.black.withOpacity(0.4),
                          boxShadow: [
                             BoxShadow(
                               color: CupertinoColors.black.withOpacity(0.3),
                               blurRadius: 8,
                               offset: const Offset(0, 4),
                             )
                          ]
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: song.artworkPath != null
                            ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                            : const Icon(CupertinoIcons.music_note, color: CupertinoColors.systemGrey, size: 24),
                      ),
                      const SizedBox(width: 16),
                      
                      // Track Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: CupertinoColors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: CupertinoColors.white.withOpacity(0.7), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                      // Play/Pause Button
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        onPressed: provider.isPlaying ? provider.pause : provider.resume,
                        child: Icon(
                          provider.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                          size: 32,
                          color: CupertinoColors.white,
                        ),
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
  }
}
