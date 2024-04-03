import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

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
          IconButton(icon: searching ? const Icon(Icons.close) : const Icon(Icons.search), onPressed: handleSearch)
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
            title: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(track.name),
              const Gap(8),
              if (track.entry case var entry?) Badge(label: Text('$entry')),
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
