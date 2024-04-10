// ignore_for_file: non_constant_identifier_names

part of 'main.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Future<MyGame> game;

  @override
  void initState() {
    super.initState();
    game = MyGame.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: game,
      builder: (context, snapshot) => switch (snapshot.data) {
        null => const Center(child: CircularProgressIndicator()),
        var game => GestureDetector(
            onPanUpdate: (info) => game.updateAnchor(info.delta),
            onTap: () => debugPrint('fuck'),
            child: Container(alignment: Alignment.topLeft, color: Colors.black, child: GameWidget(game)),
          ),
      },
    );
  }
}

class MyGame extends Game {
  MyGame._();
  final cache = ImageAssetCache(basePath: 'images/');
  var static = <Sprite>[];
  var paused = false;
  late List<AnimatedSprite> animated;
  double counter = 0;
  final drawLimit = 0.3;
  var needsDraw = true;
  ui.Picture? lastFrame;

  static Future<MyGame> load() async {
    final game = MyGame._();
    await game.initSprites();
    return game;
  }

  Future<void> initSprites() async {
    const shiningBlobs = <Map<String, dynamic>>[
      {
        "transform": {
          "anchor": [-50, -50]
        },
        "frames": [
          {
            "sprite": {
              "rect": [246, 18, 12, 12]
            },
            "duration": 0.3
          },
          {
            "sprite": {
              "rect": [246, 50, 12, 12],
            },
            "duration": 0.3
          },
          {
            "sprite": {
              "rect": [246, 82, 12, 12],
            },
            "duration": 0.3
          },
          {
            "sprite": {
              "rect": [246, 50, 12, 12],
            },
            "duration": 0.3
          },
        ]
      }
    ];
    final animatedFutures = <Future<AnimatedSprite>>[];
    for (final blob in shiningBlobs) {
      final sprite = AnimatedSprite.fromJson({"imagePath": "CharSet/moriwo_chara_01.png"}..addAll(blob));
      animatedFutures.add(sprite.loadImages(cache));
    }

    animated = await Future.wait(animatedFutures);
    for (final anim in animated) {
      for (final frame in anim.frames) {
        frame.sprite.color = Colors.black;
      }
    }
    static = await Future.wait([
      Sprite(imagePath: 'Panorama/moriwo_panorama_04.png', transform: Transform2D(), color: Colors.black)
          .loadImage(cache),
      Sprite(imagePath: 'Picture/moriwo_picture_05.png', transform: Transform2D(), color: Colors.black)
          .loadImage(cache),
      Sprite(imagePath: 'Picture/moriwo_picture_05+.png', transform: Transform2D(), color: const Color(0x22000000))
          .loadImage(cache),
      Sprite(imagePath: 'Picture/moriwo_picture_05++.png', transform: Transform2D(), color: const Color(0x44000000))
          .loadImage(cache),
    ]);
  }

  @override
  void update(double dt) {
    if (paused) return;
    counter += dt;
    if (counter >= drawLimit) {
      counter = 0;
      needsDraw = true;
    }
    for (final animated in animated) {
      animated.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    if (paused) return;
    if (!needsDraw) {
      canvas.drawPicture(lastFrame!);
      return;
    }
    needsDraw = false;
    lastFrame?.dispose();
    final recorder = ui.PictureRecorder();
    final bufferCanvas = Canvas(recorder);

    final batches = SpriteBatchMap();
    batches.addAll(static);
    for (final animated in animated) {
      batches.add(animated.sprite..color = const Color(0xBB000000));
    }
    bufferCanvas.save();
    for (final batch in batches.spriteBatchMap.values) {
      batch.render(bufferCanvas, blendMode: BlendMode.srcIn);
    }
    bufferCanvas.restore();
    canvas.drawPicture(lastFrame = recorder.endRecording());
  }

  @override
  void resize(size) {
    needsDraw = true;
    const srcHeight = 240;
    const srcWidth = 320;
    // final ratio = min(size.width / srcWidth, size.height / srcHeight);
    final ratio = size.height / srcHeight;
    final dx = (size.width - srcWidth * ratio) / 2;
    final dy = (size.height - srcHeight * ratio) / 2;
    for (final sprite in static) {
      sprite.transform.scale = ratio;
      sprite.transform.translate = Offset(dx, dy);
    }
    for (final sprite in animated) {
      sprite.transform.scale = ratio;
      sprite.transform.translate = Offset(dx, dy);
    }
  }

  @override
  void lifecycleStateChange(state) {
    paused = state == AppLifecycleState.paused;
  }

  void updateAnchor(Offset delta) {
    needsDraw = true;
    for (final sprite in static) {
      sprite.transform.anchor += delta;
    }
    for (final sprite in animated) {
      sprite.transform.anchor += delta;
    }
  }
}
