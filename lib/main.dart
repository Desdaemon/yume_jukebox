import 'package:flutter/material.dart';

import 'track.dart';
import 'with_atom.dart';
import 'play_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Music Room',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const TrackListingScreen(),
    );
  }
}

class TrackListingScreen extends StatefulWidget {
  const TrackListingScreen({super.key});

  @override
  State<StatefulWidget> createState() => _TrackListingScreen();
}

class _TrackListingScreen extends State<StatefulWidget> with AtomHelpers {
  @override
  Widget build(BuildContext context) {
    final value = Track.repo;
    return Scaffold(
      appBar: AppBar(title: const Text('Yume 2kki Jukebox')),
      body: ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, idx) {
          final item = value[idx];
          return ListTile(
            title: Text(item.name),
            onTap: () {
              Track.currentTrackIndex.set(idx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) {
                return PlayScreen(
                  baseTheme: Theme.of(context),
                );
              }));
            },
          );
        },
      ),
    );
  }
}
