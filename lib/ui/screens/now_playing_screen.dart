import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _isSeeking = false;
  double _seekValue = 0.0;

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0x00000000),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: Color(0x00000000),
        border: null,
        middle: Text('NOW PLAYING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey, letterSpacing: 2.0)),
      ),
      child: SafeArea(
        child: Consumer<PlaybackProvider>(
          builder: (context, provider, child) {
            final song = provider.currentSong;

            if (song == null) {
              return const Center(child: Text('Nothing is playing', style: TextStyle(color: CupertinoColors.systemGrey)));
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // Artwork with glow effect
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0x33FFFFFF), width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: song.artworkPath != null
                            ? Image.file(File(song.artworkPath!), fit: BoxFit.cover)
                            : Container(
                                color: const Color(0xFF1E1B4B),
                                child: const Icon(CupertinoIcons.music_note, size: 100, color: CupertinoColors.systemGrey),
                              ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Title & Artist
                  Text(
                    song.title,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: CupertinoColors.white),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist.toUpperCase(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: CupertinoColors.white.withOpacity(0.5), letterSpacing: 1.5),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 32),

                  // Progress Bar
                  Builder(
                    builder: (context) {
                      final fallbackTotal = Duration(milliseconds: (song.duration * 1000).round());
                      final totalDuration = provider.totalDuration > Duration.zero
                          ? provider.totalDuration
                          : fallbackTotal;
                      final livePosition = provider.currentPosition;
                      final shownPosition = _isSeeking
                          ? Duration(milliseconds: _seekValue.round())
                          : livePosition;

                      final maxMs = totalDuration.inMilliseconds > 0 ? totalDuration.inMilliseconds.toDouble() : 1.0;
                      final clampedShown = shownPosition.inMilliseconds.clamp(0, maxMs.round()).toDouble();

                      return Column(
                        children: [
                          CupertinoSlider(
                            value: clampedShown,
                            max: maxMs,
                            activeColor: const Color(0xFF818CF8),
                            thumbColor: CupertinoColors.white,
                            onChangeStart: (val) {
                              setState(() {
                                _isSeeking = true;
                                _seekValue = val;
                              });
                            },
                            onChanged: (val) {
                              setState(() {
                                _seekValue = val;
                              });
                            },
                            onChangeEnd: (val) async {
                              await provider.seek(Duration(milliseconds: val.round()));
                              if (!mounted) return;
                              setState(() {
                                _isSeeking = false;
                              });
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(shownPosition),
                                  style: TextStyle(
                                    color: CupertinoColors.white.withOpacity(0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatDuration(totalDuration),
                                  style: TextStyle(
                                    color: CupertinoColors.white.withOpacity(0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),

                  // Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.toggleShuffle,
                        child: Icon(
                          CupertinoIcons.shuffle,
                          color: provider.state.shuffleEnabled ? const Color(0xFF818CF8) : CupertinoColors.systemGrey,
                          size: 24,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.previous,
                        child: const Icon(CupertinoIcons.backward_fill, size: 36, color: CupertinoColors.white),
                      ),
                      // Large Play/Pause with glow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(16),
                          onPressed: provider.isPlaying ? provider.pause : provider.resume,
                          child: Icon(
                            provider.isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                            size: 40,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.next,
                        child: const Icon(CupertinoIcons.forward_fill, size: 36, color: CupertinoColors.white),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {},
                        child: const Icon(CupertinoIcons.repeat, size: 24, color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
