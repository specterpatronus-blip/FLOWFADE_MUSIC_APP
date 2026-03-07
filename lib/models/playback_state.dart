class PlaybackStateModel {
  final String? currentSongId;
  final double currentPosition;
  final List<String> queue;
  final bool shuffleEnabled;
  final double crossfadeDuration;

  PlaybackStateModel({
    this.currentSongId,
    this.currentPosition = 0.0,
    required this.queue,
    this.shuffleEnabled = false,
    this.crossfadeDuration = 6.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // Single row state
      'currentSongId': currentSongId,
      'currentPosition': currentPosition,
      'queue': queue.join(','),
      'shuffleEnabled': shuffleEnabled ? 1 : 0,
      'crossfadeDuration': crossfadeDuration,
    };
  }

  factory PlaybackStateModel.fromMap(Map<String, dynamic> map) {
    return PlaybackStateModel(
      currentSongId: map['currentSongId'],
      currentPosition: map['currentPosition'] ?? 0.0,
      queue: (map['queue'] as String? ?? '').split(',').where((e) => e.isNotEmpty).toList(),
      shuffleEnabled: map['shuffleEnabled'] == 1,
      crossfadeDuration: map['crossfadeDuration'] ?? 6.0,
    );
  }

  PlaybackStateModel copyWith({
    String? currentSongId,
    double? currentPosition,
    List<String>? queue,
    bool? shuffleEnabled,
    double? crossfadeDuration,
  }) {
    return PlaybackStateModel(
      currentSongId: currentSongId ?? this.currentSongId,
      currentPosition: currentPosition ?? this.currentPosition,
      queue: queue ?? this.queue,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      crossfadeDuration: crossfadeDuration ?? this.crossfadeDuration,
    );
  }
}
