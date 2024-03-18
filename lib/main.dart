import 'dart:convert';
import 'dart:math';

import 'package:atom/atom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:yume_jukebox/with_atom.dart';

import 'play_screen.dart';

final colorScheme = atom((
  ColorScheme.fromSeed(seedColor: Colors.cyan),
  ColorScheme.fromSeed(seedColor: Colors.cyan, brightness: Brightness.dark),
));

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Track.updateTrackList();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(atom: colorScheme, (context, scheme) {
      final (lightScheme, darkScheme) = scheme;
      return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(colorScheme: lightScheme),
        darkTheme: ThemeData(colorScheme: darkScheme),
        debugShowCheckedModeBanner: false,
        home: const TrackListingScreen(),
      );
    });
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
    return AtomBuilder(atom: Track.repo, (context, value) {
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
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlayScreen()));
              },
            );
          },
        ),
      );
    });
  }
}

class Track {
  const Track({required this.assetPath});
  final String assetPath;

  static final repo = atom(<Track>[]);
  static final currentTrackIndex = atom(0);
  static setNextTrack({int? delta, bool shuffle = false}) {
    if (shuffle) {
      currentTrackIndex.set(Random().nextInt(repo().length));
      return;
    }

    if (delta != null) {
      currentTrackIndex.set((currentTrackIndex() + delta) % repo().length);
    }
  }

  String get name => p.basenameWithoutExtension(assetPath);

  static Future<void> updateTrackList() async {
    final manifest = await rootBundle.loadString('music/manifest.json');
    final trackManifest =
        (jsonDecode(manifest) as List).cast<Map<String, dynamic>>();
    Track.repo.mutate((tracks) {
      for (final {'name': String name} in trackManifest) {
        if (p.extension(name).isNotEmpty) {
          tracks.add(Track(assetPath: 'music/$name'));
        }
      }
    });
  }
}
