import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<double> _crossfadeOptions = [0, 1, 3, 5, 8, 12];

  String _labelForDuration(double duration) {
    if (duration <= 0) return 'OFF';
    return '${duration.toStringAsFixed(0)}s';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: Consumer<PlaybackProvider>(
          builder: (context, provider, child) {
            return CupertinoListSection.insetGrouped(
              header: const Text('Playback'),
              children: [
                CupertinoListTile(
                  title: const Text('Shuffle Enabled'),
                  trailing: CupertinoSwitch(
                    value: provider.state.shuffleEnabled,
                    onChanged: (val) => provider.toggleShuffle(),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Crossfade Duration'),
                  subtitle: Text(_labelForDuration(provider.state.crossfadeDuration)),
                  additionalInfo: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await showCupertinoModalPopup<void>(
                        context: context,
                        builder: (sheetContext) => CupertinoActionSheet(
                          title: const Text('Crossfade'),
                          message: const Text('Select transition duration'),
                          actions: _crossfadeOptions
                              .map(
                                (option) => CupertinoActionSheetAction(
                                  isDefaultAction: provider.state.crossfadeDuration == option,
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await provider.setCrossfadeDuration(option);
                                  },
                                  child: Text(_labelForDuration(option)),
                                ),
                              )
                              .toList(),
                          cancelButton: CupertinoActionSheetAction(
                            isDefaultAction: true,
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                      );
                    },
                    child: const Icon(CupertinoIcons.chevron_down_circle),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('Reset App State', style: TextStyle(color: CupertinoColors.destructiveRed)),
                  onTap: () {
                    // Logic to wipe database would go here
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
