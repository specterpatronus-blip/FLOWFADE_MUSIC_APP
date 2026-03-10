import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView;
import 'package:provider/provider.dart';

import '../../models/song.dart';
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
        middle: Text(
          'NOW PLAYING',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
            letterSpacing: 2.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Consumer<PlaybackProvider>(
          builder: (context, provider, child) {
            final song = provider.currentSong;

            if (song == null) {
              return const Center(
                child: Text(
                  'Nothing is playing',
                  style: TextStyle(color: CupertinoColors.systemGrey),
                ),
              );
            }

            final queue = provider.playbackQueue;
            final currentIndex = provider.currentIndex;
            final upNextEntries = <({int index, Song song})>[
              for (int i = currentIndex + 1; i < queue.length; i++)
                (index: i, song: queue[i]),
            ];

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.28),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0x33FFFFFF),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: song.artworkPath != null
                            ? Image.file(
                                File(song.artworkPath!),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: const Color(0xFF1E1B4B),
                                child: const Icon(
                                  CupertinoIcons.music_note,
                                  size: 100,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    song.artist.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CupertinoColors.white.withValues(alpha: 0.5),
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  _ProgressSection(
                    isSeeking: _isSeeking,
                    seekValue: _seekValue,
                    currentPosition: provider.currentPosition,
                    totalDuration: provider.totalDuration > Duration.zero
                        ? provider.totalDuration
                        : Duration(
                            milliseconds: (song.duration * 1000).round(),
                          ),
                    onSeekStart: (value) {
                      setState(() {
                        _isSeeking = true;
                        _seekValue = value;
                      });
                    },
                    onSeekChanged: (value) {
                      setState(() {
                        _seekValue = value;
                      });
                    },
                    onSeekEnd: (value) async {
                      await provider.seek(
                        Duration(milliseconds: value.round()),
                      );
                      if (!mounted) return;
                      setState(() {
                        _isSeeking = false;
                      });
                    },
                    formatDuration: _formatDuration,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.toggleShuffle,
                        child: Icon(
                          CupertinoIcons.shuffle,
                          color: provider.state.shuffleEnabled
                              ? const Color(0xFF818CF8)
                              : CupertinoColors.systemGrey,
                          size: 24,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.previous,
                        child: const Icon(
                          CupertinoIcons.backward_fill,
                          size: 36,
                          color: CupertinoColors.white,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.45),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.all(16),
                          onPressed: provider.isPlaying
                              ? provider.pause
                              : provider.resume,
                          child: Icon(
                            provider.isPlaying
                                ? CupertinoIcons.pause_fill
                                : CupertinoIcons.play_fill,
                            size: 40,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: provider.next,
                        child: const Icon(
                          CupertinoIcons.forward_fill,
                          size: 36,
                          color: CupertinoColors.white,
                        ),
                      ),
                      Text(
                        '${upNextEntries.length} up next',
                        style: TextStyle(
                          color: CupertinoColors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _UpNextSection(
                      entries: upNextEntries,
                      onTap: provider.jumpToQueueIndex,
                      onReorder: (oldIndex, newIndex) async {
                        final actualOldIndex = upNextEntries[oldIndex].index;
                        final adjustedNewIndex = newIndex > oldIndex
                            ? newIndex - 1
                            : newIndex;
                        final actualNewIndex =
                            currentIndex + 1 + adjustedNewIndex;
                        await provider.moveQueueItem(
                          actualOldIndex,
                          actualNewIndex,
                        );
                      },
                    ),
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

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.isSeeking,
    required this.seekValue,
    required this.currentPosition,
    required this.totalDuration,
    required this.onSeekStart,
    required this.onSeekChanged,
    required this.onSeekEnd,
    required this.formatDuration,
  });

  final bool isSeeking;
  final double seekValue;
  final Duration currentPosition;
  final Duration totalDuration;
  final ValueChanged<double> onSeekStart;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final shownPosition = isSeeking
        ? Duration(milliseconds: seekValue.round())
        : currentPosition;
    final maxMs = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final clampedShown = shownPosition.inMilliseconds
        .clamp(0, maxMs.round())
        .toDouble();

    return Column(
      children: [
        CupertinoSlider(
          value: clampedShown,
          max: maxMs,
          activeColor: const Color(0xFF818CF8),
          thumbColor: CupertinoColors.white,
          onChangeStart: onSeekStart,
          onChanged: onSeekChanged,
          onChangeEnd: onSeekEnd,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatDuration(shownPosition),
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatDuration(totalDuration),
                style: TextStyle(
                  color: CupertinoColors.white.withValues(alpha: 0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection({
    required this.entries,
    required this.onTap,
    required this.onReorder,
  });

  final List<({int index, Song song})> entries;
  final Future<void> Function(int index) onTap;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x14FFFFFF),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Up Next',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Drag to reorder or tap any track to jump instantly.',
            style: TextStyle(
              color: CupertinoColors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text(
                      'The queue wraps automatically once this track finishes.',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: entries.length,
                    onReorder: (oldIndex, newIndex) {
                      onReorder(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Container(
                        key: ValueKey(entry.song.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: const Color(0x1AFFFFFF),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          onPressed: () => onTap(entry.index),
                          child: Row(
                            children: [
                              Text(
                                '${index + 1}'.padLeft(2, '0'),
                                style: TextStyle(
                                  color: CupertinoColors.white.withValues(
                                    alpha: 0.45,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.song.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      entry.song.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: CupertinoColors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  CupertinoIcons.line_horizontal_3,
                                  color: CupertinoColors.white.withValues(
                                    alpha: 0.45,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
