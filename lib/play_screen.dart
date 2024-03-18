import 'dart:async';
import 'dart:ui';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';

import 'package:gap/gap.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:yume_jukebox/main.dart';
import 'package:yume_jukebox/with_atom.dart';

import 'stateful_button.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with AtomHelpers, SingleTickerProviderStateMixin {
  bool isPlaying = false;

  late Track track;
  late AssetsAudioPlayer player;
  late AnimationController controller;
  final subscriptions = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();

    player = AssetsAudioPlayer.newPlayer();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    final initialIndex = Track.currentTrackIndex();
    effect(() {
      debugPrint('init');
      final tracks = Track.repo();
      final playlist = tracks.map((track) {
        return Audio(
          track.assetPath,
          metas: Metas(
            title: track.name,
            artist: 'Unknown',
            album: 'Yume 2kki OST',
          ),
        );
      }).toList(growable: false);
      player.open(
        Playlist(audios: playlist, startIndex: initialIndex),
        loopMode: LoopMode.single,
        autoStart: false,
        showNotification: true,
        volume: .5,
      );
    });

    subscriptions.add(player.current.listen((current) {
      if (current != null) {
        Track.currentTrackIndex.set(current.index);
      }
    }));

    effect(() {
      final index = Track.currentTrackIndex();
      debugPrint('track changed to $index');
      setState(() {
        track = Track.repo()[index];
        _drivePlayPauseAnimation(isPlaying: true);
      });
      if (!player.current.hasValue || player.current.value?.index != index) {
        player.playlistPlayAtIndex(index);
      }
    });

    Future.wait([
      ColorScheme.fromImageProvider(
        provider: const AssetImage('images/bg.png'),
      ),
      ColorScheme.fromImageProvider(
        provider: const AssetImage('images/bg.png'),
        brightness: Brightness.dark,
      ),
    ]).then((data) {
      colorScheme.set((data[0], data[1]));
    });
  }

  void _drivePlayPauseAnimation({required bool isPlaying}) {
    this.isPlaying = isPlaying;
    if (isPlaying) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        SizedBox.expand(
          child: Image.asset(
            'images/bg.png',
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.srcOver,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withAlpha(0x44)
                : null,
          ),
        ),
        Positioned(
          bottom: 24,
          left: 18,
          width: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: _playerControls,
            ),
          ),
        ) // Positioned
      ]),
    );
  }

  Widget get _playerControls {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.background.withOpacity(.85),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextScroll(
            track.name,
            style: Theme.of(context).textTheme.headlineMedium,
            delayBefore: const Duration(seconds: 2),
            pauseBetween: const Duration(seconds: 2),
          ),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Icon(Icons.music_note),
            Text(
              'Blue Cactus Islands',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ]),
          const Gap(8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.outlined(
                  icon: const Icon(Icons.bedtime),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                ),
                const Gap(8),
                IconButton.outlined(
                  icon: const Icon(Icons.playlist_add),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {},
                ),
                const Gap(8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  child: !isPlaying ? const SizedBox.shrink() : _variantPicker,
                )
              ],
            ),
          ),
          const Gap(16),
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatefulButton(
                selected: AutoplayMode.repeat,
                iconSize: 32,
                stateChanged: (mode) => mode.nextState,
              ),
              const Gap(6),
              Tooltip(
                message: 'Previous',
                child: IconButton.outlined(
                  onPressed: () {
                    Track.setNextTrack(delta: -1, shuffle: player.shuffle);
                    _drivePlayPauseAnimation(isPlaying: true);
                  },
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 32,
                ),
              ),
              const Gap(6),
              IconButton.filled(
                onPressed: () {
                  player.playOrPause();
                  _drivePlayPauseAnimation(isPlaying: !isPlaying);
                },
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: controller,
                ),
                iconSize: 48,
              ),
              const Gap(6),
              IconButton.outlined(
                onPressed: () {
                  Track.setNextTrack(delta: 1, shuffle: player.shuffle);
                  _drivePlayPauseAnimation(isPlaying: true);
                },
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
              ),
              const Gap(6),
              StatefulButton(
                selected: ShuffleMode.sequential,
                iconSize: 32,
                stateChanged: (mode) {
                  player.shuffle = (mode.nextState == ShuffleMode.shuffle);
                  return mode.nextState;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget get _variantPicker {
    var active = 'A';
    return StatefulBuilder(
      builder: (context, $setState) {
        return Wrap(spacing: 2, children: [
          for (final variant in 'ABCDEF'.characters)
            ChoiceChip(
              label: Text(variant),
              selected: variant == active,
              visualDensity: VisualDensity.compact,
              onSelected: (selected) {
                if (selected) {
                  $setState(() => active = variant);
                }
              },
            )
        ]);
      },
    );
  }
}

enum AutoplayMode implements ButtonState<AutoplayMode> {
  repeat,
  autoplay;

  @override
  get state => switch (this) {
        repeat => const (
            icon: Icons.repeat_one,
            style: IconButtons.outlined,
            tooltip: 'Repeat',
          ),
        autoplay => const (
            icon: Icons.fast_forward,
            style: IconButtons.filledTonal,
            tooltip: 'Autoplay',
          ),
      };

  AutoplayMode get nextState => switch (this) {
        repeat => autoplay,
        autoplay => repeat,
      };
}

enum ShuffleMode implements ButtonState<ShuffleMode> {
  sequential,
  shuffle;

  @override
  get state => switch (this) {
        sequential => const (
            icon: Icons.arrow_forward,
            style: IconButtons.outlined,
            tooltip: 'Sequential',
          ),
        shuffle => const (
            icon: Icons.shuffle,
            style: IconButtons.filledTonal,
            tooltip: 'Shuffle',
          ),
      };

  ShuffleMode get nextState => switch (this) {
        sequential => shuffle,
        shuffle => sequential,
      };
}
