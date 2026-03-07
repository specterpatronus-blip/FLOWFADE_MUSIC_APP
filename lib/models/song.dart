class Song {
  final String id;
  final String filePath;
  final String originalFileName;
  final String title;
  final String artist;
  final String? artworkPath;
  final double duration;
  final DateTime dateAdded;
  final bool isMetadataEdited;

  Song({
    required this.id,
    required this.filePath,
    required this.originalFileName,
    required this.title,
    required this.artist,
    this.artworkPath,
    required this.duration,
    required this.dateAdded,
    this.isMetadataEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'originalFileName': originalFileName,
      'title': title,
      'artist': artist,
      'artworkPath': artworkPath,
      'duration': duration,
      'dateAdded': dateAdded.toIso8601String(),
      'isMetadataEdited': isMetadataEdited ? 1 : 0,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      filePath: map['filePath'],
      originalFileName: map['originalFileName'],
      title: map['title'],
      artist: map['artist'],
      artworkPath: map['artworkPath'],
      duration: map['duration'],
      dateAdded: DateTime.parse(map['dateAdded']),
      isMetadataEdited: map['isMetadataEdited'] == 1,
    );
  }

  Song copyWith({
    String? title,
    String? artist,
    String? artworkPath,
    bool? isMetadataEdited,
  }) {
    return Song(
      id: id,
      filePath: filePath,
      originalFileName: originalFileName,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkPath: artworkPath ?? this.artworkPath,
      duration: duration,
      dateAdded: dateAdded,
      isMetadataEdited: isMetadataEdited ?? this.isMetadataEdited,
    );
  }
}
