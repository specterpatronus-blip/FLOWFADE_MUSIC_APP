import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../state/playback_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  subtitle: Text('${provider.state.crossfadeDuration.toStringAsFixed(1)}s'),
                  additionalInfo: SizedBox(
                    width: 150,
                    child: CupertinoSlider(
                      value: provider.state.crossfadeDuration,
                      min: 1.0,
                      max: 12.0,
                      divisions: 11,
                      onChanged: provider.setCrossfadeDuration,
                    ),
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
