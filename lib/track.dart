import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:path/path.dart' as p;
import 'package:radix_tree/radix_tree.dart';

// Copy manifest.dart.example to manifest.dart and put in your own files
part 'manifest.dart';

class Variant {
  final String path;
  final String event;
  final String? background;
  final String? title;

  static const fallbackBackground = 'images/bg.png';

  @override
  String toString() => 'Variant($path, event:$event)';

  const Variant({
    required this.path,
    this.title,
    this.event = '',
    this.background,
  });
}

class Track extends Variant {
  const Track({
    required super.path,
    super.title,
    this.entry,
    super.event,
    String background = Variant.fallbackBackground,
    this.variants = const [],
  })  : _path = path,
        _background = background;

  String get name => title ?? p.basenameWithoutExtension(path);

  final String _path;
  @override
  String get path => _path;

  final String _background;
  @override
  String get background => _background;

  final List<Variant> variants;
  final int? entry;

  Iterable<(String, Variant)> get namedVariants sync* {
    var char = 'B'.codeUnitAt(0);
    for (final variant in variants) {
      yield (String.fromCharCode(char++), variant);
    }
  }

  static List<Track> get repo => _manifest.toList(growable: false)
    ..sort((a, b) => (a.entry ?? -1).compareTo(b.entry ?? -1));
  static List<Audio> audios = repo.map((track) {
    return Audio(
      track.path,
      metas: Metas(
        title: track.name,
        album: 'Yume 2kki OST',
        image: MetasImage(
          path: track.background,
          type: ImageType.asset,
        ),
      ),
    );
  }).toList();

  static RadixTree<Set<int>> audiosByEvent = _audiosByEvent;
  static RadixTree<Set<int>> get _audiosByEvent {
    final tree = RadixTree<Set<int>>();
    for (final (idx, track) in repo.indexed) {
      if (track.event.isNotEmpty) {
        tree.putIfAbsent(track.event.toLowerCase(), Set.new)!.add(idx);
      }
      for (final variant in track.variants) {
        if (variant.event.isNotEmpty) {
          tree.putIfAbsent(variant.event.toLowerCase(), Set.new)!.add(idx);
        }
      }
    }
    return tree;
  }
}
