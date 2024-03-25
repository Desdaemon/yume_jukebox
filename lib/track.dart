import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:path/path.dart' as p;

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

  static List<Track> get repo =>
      _manifest.toList(growable: false)..sort((a, b) => (a.entry ?? -1).compareTo(b.entry ?? -1));
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
}
