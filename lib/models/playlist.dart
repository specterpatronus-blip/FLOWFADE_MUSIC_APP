class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime dateCreated;

  Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.dateCreated,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      // songIds are stored in a relational table, not here directly, but we map it for basic handling
      'dateCreated': dateCreated.toIso8601String(),
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map, {List<String> songIds = const []}) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      songIds: songIds,
      dateCreated: DateTime.parse(map['dateCreated']),
    );
  }

  Playlist copyWith({
    String? name,
    List<String>? songIds,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      dateCreated: dateCreated,
    );
  }
}
