import 'dart:async';
import 'dart:ui';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:text_scroll/text_scroll.dart';

import 'main.dart';
import 'with_atom.dart';
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
  Timer? sleepTimer;
  Timer? autoplayTimer;

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
      final tracks = Track.repo();
      final playlist = tracks.map((track) {
        return Audio(
          track.assetPath,
          metas: Metas(
            title: track.name,
            image: MetasImage(
              path: track.background,
              type: ImageType.asset,
            ),
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
      setState(() {
        track = Track.repo()[index];
        _drivePlayPauseAnimation(isPlaying: true);
      });
      Future.wait([
        ColorScheme.fromImageProvider(
          provider: AssetImage(track.background),
        ),
        ColorScheme.fromImageProvider(
          provider: AssetImage(track.background),
          brightness: Brightness.dark,
        ),
      ]).then((data) {
        if (!mounted) return;
        colorScheme.set((data[0], data[1]));
      });
      if (!player.current.hasValue || player.current.value?.index != index) {
        player.playlistPlayAtIndex(index);
      }
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
    sleepTimer?.cancel();
    autoplayTimer?.cancel();
    player.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        SizedBox.expand(
          child: Image.asset(
            track.background,
            key: ValueKey(track.background),
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
      color: Theme.of(context).colorScheme.background.withOpacity(.75),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextScroll(
            track.name,
            style: Theme.of(context).textTheme.headlineMedium,
            delayBefore: const Duration(seconds: 2),
            pauseBetween: const Duration(seconds: 2),
          ),
          if (track.gameEvent.isNotEmpty)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.location_pin),
              Text(
                track.gameEvent,
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
                  tooltip: 'Sleep timer',
                  icon: const Icon(Icons.bedtime),
                  isSelected: sleepTimer != null,
                  visualDensity: VisualDensity.compact,
                  onPressed: _handleSleep,
                ),
                const Gap(8),
                IconButton.outlined(
                  tooltip: 'Add to playlist',
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
                stateChanged: (mode) async {
                  final result = await _handleAutoplay(
                      wantAutoplay: mode.nextState == AutoplayMode.autoplay);
                  return result ? AutoplayMode.autoplay : AutoplayMode.repeat;
                },
              ),
              const Gap(6),
              IconButton.outlined(
                tooltip: 'Previous',
                onPressed: () {
                  Track.setNextTrack(
                      delta: -1, backInQueue: true, shuffle: false);
                  _drivePlayPauseAnimation(isPlaying: true);
                },
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
              ),
              const Gap(6),
              IconButton.filled(
                onPressed: () {
                  player.playOrPause();
                  _drivePlayPauseAnimation(isPlaying: !isPlaying);
                },
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  semanticLabel: isPlaying ? 'Pause' : 'Play',
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

  Future<bool> _handleAutoplay({bool wantAutoplay = true}) async {
    if (autoplayTimer != null && !wantAutoplay) {
      autoplayTimer!.cancel();
      setState(() {
        autoplayTimer = null;
      });
      return false;
    }
    if (!wantAutoplay) return false;
    final delay = await showDurationPicker(
      context: context,
      initialTime: const Duration(minutes: 2),
      baseUnit: BaseUnit.second,
    );
    if (!mounted || delay == null) return false;
    setState(() {
      autoplayTimer = Timer.periodic(delay, (_) {
        if (!mounted) return;
        Track.setNextTrack(delta: 1, shuffle: player.shuffle);
      });
    });
    return true;
  }

  void _handleSleep() async {
    if (sleepTimer != null) {
      sleepTimer!.cancel();
      setState(() {
        sleepTimer = null;
      });
      return;
    }

    final delay = await showDurationPicker(
      context: context,
      initialTime: const Duration(minutes: 20),
    );
    if (!mounted || delay == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Sleeping in $delay'),
    ));
    setState(() {
      sleepTimer = Timer(delay, player.stop);
    });
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
            selectedStyle: false,
          ),
        autoplay => const (
            icon: Icons.fast_forward,
            style: IconButtons.outlined,
            tooltip: 'Autoplay',
            selectedStyle: true,
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
            selectedStyle: false,
          ),
        shuffle => const (
            icon: Icons.shuffle,
            style: IconButtons.outlined,
            tooltip: 'Shuffle',
            selectedStyle: true,
          ),
      };

  ShuffleMode get nextState => switch (this) {
        sequential => shuffle,
        shuffle => sequential,
      };
}
