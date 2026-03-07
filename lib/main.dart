import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'state/playback_provider.dart';
import 'ui/screens/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlaybackProvider()),
      ],
      child: const FlowfadeApp(),
    ),
  );
}

class FlowfadeApp extends StatelessWidget {
  const FlowfadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Flowfade',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.activeBlue,
        scaffoldBackgroundColor: CupertinoColors.black,
      ),
      home: LibraryScreen(),
    );
  }
}
