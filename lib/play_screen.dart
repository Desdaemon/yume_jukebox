import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:gap/gap.dart';
import 'package:text_scroll/text_scroll.dart';

import 'track.dart';
import 'with_atom.dart';
import 'stateful_button.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.baseTheme});

  final ThemeData baseTheme;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with AtomHelpers, SingleTickerProviderStateMixin {
  bool isPlaying = false;

  late Track _track;
  Track get track => _track;
  set track(Track track) {
    _track = track;
    activeVariant = null;
    activeVariantName = 'A';
  }

  Variant? _activeVariant;
  Variant? get activeVariant => _activeVariant;
  set activeVariant(Variant? variant) {
    final hasDifferentBackground =
        (variant?.background ?? track.background) != info.background;
    _activeVariant = variant;
    if (hasDifferentBackground) updateThemeColors();
  }

  var activeVariantName = 'A';
  late AssetsAudioPlayer player;

  ({String background, String gameEvent}) get info => (
        background: activeVariant?.background ?? track.background,
        gameEvent: activeVariant?.gameEvent ?? track.gameEvent,
      );

  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  final subscriptions = <StreamSubscription>[];
  Timer? sleepTimer;
  Timer? autoplayTimer;
  ThemeData? data;

  static void noop() {}

  @override
  void initState() {
    super.initState();

    player = AssetsAudioPlayer.newPlayer()
      ..open(
        Playlist(audios: Track.audios, startIndex: Track.currentTrackIndex()),
        loopMode: LoopMode.single,
        headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplugPlayOnPlug,
        autoStart: false,
        showNotification: true,
        volume: .5,
      );

    subscriptions.add(player.current.listen((current) {
      if (current != null) {
        Track.currentTrackIndex.set(current.index);
      }
    }));

    effect(() async {
      final index = Track.currentTrackIndex();
      final needsThemeUpdate = !player.current.hasValue ||
          info.background != Track.repo[index].background;
      setState(() {
        track = Track.repo[index];
        drivePlayPauseAnimation(isPlaying: true);
      });
      if (needsThemeUpdate) updateThemeColors();
      if (!player.current.hasValue || player.current.value?.index != index) {
        debugPrint('Setting track speed to ${track.speed}');
        await player.setPlaySpeed(track.speed);
        await player.setPitch(track.speed);
        player.playlistPlayAtIndex(index);
      }
    });
  }

  void updateThemeColors() async {
    debugPrint('Updating with ${info.background}');
    final scheme = await ColorScheme.fromImageProvider(
      provider: AssetImage(info.background),
      brightness: widget.baseTheme.brightness,
    );
    if (!mounted) return;
    setState(() => data = widget.baseTheme.copyWith(colorScheme: scheme));
  }

  void drivePlayPauseAnimation({required bool isPlaying}) {
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

  static const transitionDuration = Duration(milliseconds: 700);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        AnimatedSwitcher(
          duration: transitionDuration,
          child: SizedBox.expand(
            key: ValueKey(info.background),
            child: Image.asset(
              info.background,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.srcOver,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withAlpha(0x44)
                  : null,
            ),
          ),
        ),
        // SizedBox.expand(
        //   child: ParallaxRain(
        //     key: const ValueKey(true),
        //     numberOfDrops: 100,
        //     dropFallSpeed: 20,
        //     dropColors: const [Colors.grey],
        //   ),
        // ),
        AppBar(backgroundColor: Colors.transparent),
        Positioned(
          bottom: 24,
          left: 18,
          width: 320,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: AnimatedTheme(
                data: data ?? Theme.of(context),
                duration: transitionDuration,
                child: playerControls,
              ),
            ),
          ),
        )
      ]),
    );
  }

  Widget get playerControls {
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
          if (info.gameEvent.isNotEmpty)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Icon(Icons.location_pin),
              Text(
                info.gameEvent,
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
                  onPressed: handleSleep,
                ),
                const Gap(8),
                // TODO
                const IconButton.outlined(
                  tooltip: 'Add to playlist',
                  icon: Icon(Icons.playlist_add),
                  visualDensity: VisualDensity.compact,
                  onPressed: noop,
                ),
                const Gap(8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  child: track.variants.isEmpty ? null : variantPicker,
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
                  final result = await handleAutoplay(
                    wantAutoplay: mode.nextState == AutoplayMode.autoplay,
                  );
                  return result ? AutoplayMode.autoplay : AutoplayMode.repeat;
                },
              ),
              const Gap(6),
              IconButton.outlined(
                tooltip: 'Previous',
                onPressed: () {
                  Track.setNextTrack(delta: -1, shuffle: false);
                  drivePlayPauseAnimation(isPlaying: true);
                },
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
              ),
              const Gap(6),
              IconButton.filled(
                onPressed: () {
                  player.playOrPause();
                  setState(() {
                    drivePlayPauseAnimation(isPlaying: !isPlaying);
                  });
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
                  drivePlayPauseAnimation(isPlaying: true);
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

  Future<bool> handleAutoplay({bool wantAutoplay = true}) async {
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
      initialTime: const Duration(minutes: 10),
    );
    if (!mounted || delay == null) return false;
    setState(() {
      autoplayTimer = Timer.periodic(delay, (_) {
        if (!mounted || !isPlaying) return;
        Track.setNextTrack(delta: 1, shuffle: player.shuffle);
      });
    });
    return true;
  }

  void handleSleep() async {
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
      sleepTimer = Timer(delay, () {
        Navigator.of(context).pop();
      });
    });
  }

  Widget get variantPicker {
    return Wrap(spacing: 2, children: [
      ChoiceChip(
        key: const ValueKey('A'),
        label: const Text('A'),
        selected: activeVariantName == 'A',
        visualDensity: VisualDensity.compact,
        onSelected: (selected) {
          if (selected) selectVariant(track);
          setState(() => activeVariantName = 'A');
        },
      ),
      for (final (name, variant) in track.namedVariants)
        ChoiceChip(
          key: ValueKey(name),
          label: Text(name),
          selected: name == activeVariantName,
          visualDensity: VisualDensity.compact,
          onSelected: (selected) {
            if (selected) selectVariant(variant);
            setState(() => activeVariantName = name);
          },
        )
    ]);
  }

  final variantIndex = WeakMap<Variant, int>();
  void selectVariant(Variant variant) async {
    await player.setPlaySpeed(variant.speed);
    await player.setPitch(variant.speed);

    if (variantIndex[variant] case final index?) {
      if (!isPlaying) {
        player.playlistPlayAtIndex(index);
        drivePlayPauseAnimation(isPlaying: true);
      }
      setState(() {
        activeVariant = variant;
      });
      return;
    }

    if (variant is Track) {
      if (!isPlaying) {
        Track.currentTrackIndex.set(Track.repo.indexOf(variant));
        return;
      }
      setState(() {
        activeVariant = null;
      });
      return;
    }

    setState(() {
      activeVariant = variant;
    });

    if (variant.path == null || variant.path == track.path) {
      return;
    }

    final index = player.playlist!.audios.length - 1;
    player.playlist!.add(Audio(
      variant.path!,
      playSpeed: variant.speed,
      pitch: variant.speed,
      metas: Metas(
        title: variant.name ?? track.name,
        album: 'Yume 2kki OST',
        image: MetasImage(
          path: variant.background ?? track.background,
          type: ImageType.asset,
        ),
      ),
    ));
    variantIndex[variant] = index;
    player.playlistPlayAtIndex(index);
    setState(() {
      drivePlayPauseAnimation(isPlaying: true);
    });
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
