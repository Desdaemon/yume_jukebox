import 'dart:math';

import 'package:asset_cache/asset_cache.dart';
import 'package:flim/flim.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'track.dart';
import 'with_atom.dart';
import 'play_screen.dart';

part 'game.dart';

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
      // home: const GameScreen(),
    );
  }
}

class TrackListingScreen extends StatefulWidget {
  const TrackListingScreen({super.key});

  @override
  State<StatefulWidget> createState() => _TrackListingScreen();
}

class _TrackListingScreen extends State<StatefulWidget> with AtomHelpers {
  var searching = false;

  List<int>? filtered;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          key: ValueKey(searching),
          duration: const Duration(milliseconds: 1000),
          child: searchBar,
        ),
        actions: [
          IconButton(icon: searching ? const Icon(Icons.close) : const Icon(Icons.search), onPressed: handleSearch),
          IconButton(
              icon: const Icon(Icons.photo),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
              }),
        ],
      ),
      body: ListView.builder(
        itemCount: filtered?.length ?? Track.repo.length,
        itemBuilder: (context, filterIndex) {
          final index = switch (filtered) {
            null => filterIndex,
            var filtered => filtered[filterIndex],
          };
          final track = Track.repo[index];
          return ListTile(
            key: ValueKey(track),
            title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(track.name),
              if (track.entry case var entry?) Badge(label: Text('$entry')),
              if (track.background.endsWith('.webp') || track.background.endsWith('.gif'))
                const Icon(Icons.movie, size: 16)
            ]),
            subtitle: track.event.isNotEmpty ? Text(track.event) : null,
            trailing: track.variants.isNotEmpty ? Text('■' * (track.variants.length + 1)) : null,
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

  Widget get searchBar {
    if (!searching) return const Text('Sound Room');
    return TextFormField(
      autofocus: true,
      decoration: const InputDecoration.collapsed(hintText: 'Search by location/event'),
      onChanged: (needle) {
        if (needle.isEmpty) {
          setState(() => filtered = null);
          return;
        }
        final filter = Track.audiosByEvent.getValuesWithPrefix(needle.toLowerCase()).expand((list) => list);
        setState(() {
          filtered = filter.toList(growable: false);
        });
      },
    );
  }

  void handleSearch() {
    setState(() {
      searching = !searching;
      if (!searching) filtered = null;
    });
  }
}
