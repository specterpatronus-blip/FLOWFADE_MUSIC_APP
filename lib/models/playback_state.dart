class PlaybackStateModel {
  final String? currentSongId;
  final int currentIndex;
  final double currentPosition;
  final List<String> queue;
  final bool shuffleEnabled;
  final double crossfadeDuration;
  final bool isPlaying;

  PlaybackStateModel({
    this.currentSongId,
    this.currentIndex = 0,
    this.currentPosition = 0.0,
    required this.queue,
    this.shuffleEnabled = false,
    this.crossfadeDuration = 5.0,
    this.isPlaying = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // Single row state
      'currentSongId': currentSongId,
      'currentIndex': currentIndex,
      'currentPosition': currentPosition,
      'queue': queue.join(','),
      'shuffleEnabled': shuffleEnabled ? 1 : 0,
      'crossfadeDuration': crossfadeDuration,
      'isPlaying': isPlaying ? 1 : 0,
    };
  }

  factory PlaybackStateModel.fromMap(Map<String, dynamic> map) {
    return PlaybackStateModel(
      currentSongId: map['currentSongId'],
      currentIndex: map['currentIndex'] ?? 0,
      currentPosition: map['currentPosition'] ?? 0.0,
      queue: (map['queue'] as String? ?? '')
          .split(',')
          .where((e) => e.isNotEmpty)
          .toList(),
      shuffleEnabled: map['shuffleEnabled'] == 1,
      crossfadeDuration: map['crossfadeDuration'] ?? 5.0,
      isPlaying: map['isPlaying'] == 1,
    );
  }

  PlaybackStateModel copyWith({
    String? currentSongId,
    int? currentIndex,
    double? currentPosition,
    List<String>? queue,
    bool? shuffleEnabled,
    double? crossfadeDuration,
    bool? isPlaying,
  }) {
    return PlaybackStateModel(
      currentSongId: currentSongId ?? this.currentSongId,
      currentIndex: currentIndex ?? this.currentIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      queue: queue ?? this.queue,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}
