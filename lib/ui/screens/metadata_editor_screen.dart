import 'package:flutter/cupertino.dart';
import '../../models/song.dart';
import '../../services/database_helper.dart';

class MetadataEditorScreen extends StatefulWidget {
  final Song song;
  const MetadataEditorScreen({super.key, required this.song});

  @override
  State<MetadataEditorScreen> createState() => _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends State<MetadataEditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  final DatabaseHelper _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    super.dispose();
  }

  Future<void> _saveMetadata() async {
    final updatedSong = widget.song.copyWith(
      title: _titleController.text.trim(),
      artist: _artistController.text.trim(),
      isMetadataEdited: true,
    );
    await _db.updateSong(updatedSong);
    if (!mounted) return;
    Navigator.pop(context, true); // true indicates successful change
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Edit Metadata'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saveMetadata,
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Title', style: TextStyle(color: CupertinoColors.systemGrey)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _titleController,
                placeholder: 'Song Title',
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 24),
              const Text('Artist', style: TextStyle(color: CupertinoColors.systemGrey)),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _artistController,
                placeholder: 'Artist Name',
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('Artwork editing requires picking a new image via ImagePicker (Not implemented in scaffold).',
                    textAlign: TextAlign.center, style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
