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
    return CupertinoApp(
      title: 'Flowfade',
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: CupertinoColors.white,
        scaffoldBackgroundColor: Color(0x00000000), // Transparent
        barBackgroundColor: Color(0x00000000), // Transparent NavBars
      ),
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B), // Deep Indigo
                Color(0xFF0F0E17), // Very Dark Blue/Black
                Color(0xFF000000), // Pure Black for depth
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: child,
        );
      },
      home: const LibraryScreen(),
    );
  }
}
