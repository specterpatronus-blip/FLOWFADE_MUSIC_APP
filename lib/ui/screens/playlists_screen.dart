import 'package:flutter/cupertino.dart';
import '../../models/playlist.dart';
import '../../services/database_helper.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _playlists = [];
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final playlists = await _db.readAllPlaylists();
    setState(() {
      _playlists = playlists;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Playlists'),
      ),
      child: SafeArea(
        child: _playlists.isEmpty
            ? const Center(child: Text('No playlists yet', style: TextStyle(color: CupertinoColors.systemGrey)))
            : ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return CupertinoListTile(
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songIds.length} songs', style: const TextStyle(color: CupertinoColors.systemGrey)),
                    leading: const Icon(CupertinoIcons.music_albums),
                    onTap: () {
                      // Navigate to playlist detail
                    },
                  );
                },
              ),
      ),
    );
  }
}
