import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Now Playing'),
      ),
      child: SafeArea(
        child: Consumer<PlaybackProvider>(
          builder: (context, provider, child) {
            final song = provider.currentSong;
            
            if (song == null) {
              return const Center(child: Text('Nothing is playing'));
            }

            return Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Artwork
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: CupertinoColors.systemGrey6,
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: song.artworkPath != null
                          ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                          : const Icon(CupertinoIcons.music_note, size: 100, color: CupertinoColors.systemGrey),
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Title & Artist
                  Text(
                    song.title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist,
                    style: const TextStyle(fontSize: 18, color: CupertinoColors.systemGrey),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Progress Bar (Mocked for scaffolding, would sync with engine in real implementation)
                  CupertinoSlider(
                    value: provider.state.currentPosition,
                    max: song.duration > 0 ? song.duration : 1.0,
                    onChanged: (val) {
                       // Seek functionality would go here
                    },
                  ),
                  
                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.toggleShuffle,
                        child: Icon(
                          CupertinoIcons.shuffle,
                          color: provider.state.shuffleEnabled ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
                          size: 28,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.previous,
                        child: const Icon(CupertinoIcons.backward_fill, size: 40, color: CupertinoColors.white),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.isPlaying ? provider.pause : provider.resume,
                        child: Icon(
                          provider.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                          size: 60,
                          color: CupertinoColors.white,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.next,
                        child: const Icon(CupertinoIcons.forward_fill, size: 40, color: CupertinoColors.white),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {}, // Repeat placeholder
                        child: const Icon(CupertinoIcons.repeat, size: 28, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
