import 'dart:collection';
import 'dart:math';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:atom/atom.dart';
import 'package:path/path.dart' as p;

// Copy manifest.dart.example to manifest.dart and put in your own files
part 'manifest.dart';

class Variant {
  final String? path;
  final String gameEvent;
  final String? background;
  final double speed;
  final String? title;

  static const fallbackBackground = 'images/bg.png';

  @override
  String toString() => 'Variant($path, event:$gameEvent)';

  const Variant({
    this.path,
    this.title,
    this.gameEvent = '',
    this.background,
    this.speed = 1.0,
  });

  String? get name =>
      title ?? (path != null ? p.basenameWithoutExtension(path!) : path);
}

class Track extends Variant {
  const Track({
    required String path,
    super.title,
    super.gameEvent,
    String background = Variant.fallbackBackground,
    super.speed,
    this.variants = const [],
  })  : _path = path,
        _background = background;

  @override
  String get name => super.name!;

  final String _path;
  @override
  String get path => _path;

  final String _background;
  @override
  String get background => _background;

  final List<Variant> variants;

  Iterable<(String, Variant)> get namedVariants sync* {
    var char = 'B'.codeUnitAt(0);
    for (final variant in variants) {
      yield (String.fromCharCode(char++), variant);
    }
  }

  static List<Track> get repo => _manifest;
  static List<Audio> audios = repo.map((track) {
    return Audio(
      track.path,
      playSpeed: track.speed,
      pitch: track.speed,
      metas: Metas(
        title: track.name,
        album: 'Yume 2kki OST',
        image: MetasImage(
          path: track.background,
          type: ImageType.asset,
        ),
      ),
    );
  }).toList(growable: false);
  static final currentTrackIndex = atom(0);
  static final playHistory = Queue<int>();
  static void setNextTrack({int? delta, bool shuffle = false}) {
    if (shuffle) {
      playHistory.add(currentTrackIndex.value);
      currentTrackIndex.set(Random().nextInt(repo.length));
      return;
    }

    if (playHistory.isNotEmpty && shuffle) {
      currentTrackIndex.set(playHistory.removeFirst());
      return;
    }

    if (delta != null) {
      if (shuffle) playHistory.add(currentTrackIndex.value);
      currentTrackIndex.set((currentTrackIndex() + delta) % repo.length);
    }
  }
}
