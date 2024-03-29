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
      appBar: AppBar(title: const Text('Sound Room')),
      body: ListView.builder(
        itemCount: value.length,
        itemBuilder: (context, index) {
          final track = value[index];
          return ListTile(
            title: Text(track.name),
            subtitle: track.event.isNotEmpty ? Text(track.event) : null,
            trailing: track.variants.isNotEmpty
                ? Text('■' * (track.variants.length + 1))
                : null,
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) {
                return PlayScreen(
                  baseTheme: Theme.of(context),
                  initialIndex: index,
                );
              }));
            },
          );
        },
      ),
    );
  }
}
