import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:duration_picker/duration_picker.dart';
import 'package:gap/gap.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:video_player/video_player.dart';
import 'package:native_video_player/native_video_player.dart';

import 'track.dart';
import 'stateful_button.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key, required this.baseTheme, required this.initialIndex});

  final ThemeData baseTheme;
  final int initialIndex;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  static const newTrackTransitionDuration = Duration(milliseconds: 700);

  bool get isPlaying => player.current.hasValue && player.current.value != null;

  ({int index, String background}) tombstone = defaultTombstone;
  static const defaultTombstone = (index: -1, background: Variant.fallbackBackground);
  String get activeBackground => _activeVariant?.background ?? _track.background;
  String get activeEvent => _activeVariant?.event ?? _track.event;

  late Track _track = Track.repo[widget.initialIndex];
  // VideoPlayerController? playerController;
  Track get track => _track;
  set track(Track track) {
    final backgroundChanged = track.background != activeBackground;
    _track = track;
    setState(() {
      _activeVariant = null;
    });
    activeVariantName = 'A';
    if (backgroundChanged) updateThemeColors();
  }

  Variant? _activeVariant;
  Variant? get activeVariant => _activeVariant;
  set activeVariant(Variant? variant) {
    final backgroundChanged = (variant?.background ?? _track.background) != activeBackground;
    setState(() {
      _activeVariant = variant;
    });
    if (backgroundChanged) updateThemeColors();
  }

  var activeVariantName = 'A';
  Duration? autoplayDuration;
  late AssetsAudioPlayer player;
  late int activeTrackIndex = -1;

  late final playPauseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final backgroundSlideController = ScrollController();

  final subscriptions = <StreamSubscription>[];
  Timer? sleepTimer;
  Timer? autoplayTimer;
  ThemeData? data;
  final playerOpened = Completer<void>();

  static void noop() {}

  @override
  void initState() {
    super.initState();

    player = AssetsAudioPlayer.newPlayer()
      ..open(
        Playlist(audios: Track.audios, startIndex: widget.initialIndex),
        loopMode: LoopMode.single,
        headPhoneStrategy: HeadPhoneStrategy.pauseOnUnplugPlayOnPlug,
        autoStart: false,
        showNotification: true,
        volume: .5,
      ).then((_) async {
        await player.playlistPlayAtIndex(widget.initialIndex);
        playerOpened.complete();
        // Set it back to 0, it uses this value to determine where to start
        // when at the end of the playlist
        player.playlist!.startIndex = 0;
        drivePlayPauseAnimation(toPlay: true);
      });

    subscriptions.add(player.isPlaying.listen((isPlaying) async {
      await playerOpened.future;
      if (!mounted) return;
      drivePlayPauseAnimation(toPlay: isPlaying);
    }));

    subscriptions.add(player.current.listen((current) async {
      await playerOpened.future;
      final index = current == null ? null : Track.audios.indexOf(current.audio.audio);
      if (!mounted || index == null || index == -1) return;

      if (index < Track.repo.length && index != activeTrackIndex) {
        tombstone = (index: activeTrackIndex, background: activeBackground);
        activeTrackIndex = index;
        final screenWidth = MediaQuery.of(context).size.width;
        final screens = (backgroundSlideController.offset / screenWidth).ceil();
        final timesWrapped = (screens / Track.repo.length).floor();
        (backgroundSlideController.animateTo)(
          screenWidth * (Track.repo.length * timesWrapped + index),
          duration: newTrackTransitionDuration,
          curve: Curves.easeInOut,
        ).then((_) {
          tombstone = defaultTombstone;
        });
        track = Track.repo[index];
        drivePlayPauseAnimation(toPlay: true);
      }
    }));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateThemeColors();
      backgroundSlideController.position.isScrollingNotifier.addListener(() {
        if (backgroundSlideController.position.isScrollingNotifier.value) return;
        tombstone = defaultTombstone;
        final index =
            (backgroundSlideController.offset / MediaQuery.of(context).size.width).round() % Track.repo.length;
        if (index != player.current.value?.index && index != activeTrackIndex) {
          player.playlistPlayAtIndex(index);
          resetAutoplay();
        }
      });
    });
  }

  void updateThemeColors() async {
    // debugPrint('Updating with $activeBackground');
    final scheme = await ColorScheme.fromImageProvider(
      provider: AssetImage(activeBackground),
      brightness: widget.baseTheme.brightness,
    );
    if (!mounted) return;
    setState(() => data = widget.baseTheme.copyWith(colorScheme: scheme));
  }

  void drivePlayPauseAnimation({required bool toPlay}) {
    if (toPlay) {
      playPauseController.forward();
    } else {
      playPauseController.reverse();
    }
  }

  @override
  void dispose() {
    super.dispose();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    // playerController?.dispose();
    sleepTimer?.cancel();
    autoplayTimer?.cancel();
    player.dispose();
    playPauseController.dispose();
    backgroundSlideController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        GestureDetector(
          onTap: handlePlayPause,
          child: ListView.builder(
            cacheExtent: 1, // 1 page forward, 1 page back
            scrollDirection: Axis.horizontal,
            controller: backgroundSlideController,
            itemExtent: MediaQuery.of(context).size.width,
            physics: const PageScrollPhysics(),
            itemBuilder: (context, index) {
              final wrappedIndex = index % Track.repo.length;
              final track = Track.repo[wrappedIndex];
              if (wrappedIndex == activeTrackIndex) {
                return AnimatedSwitcher(
                  duration: newTrackTransitionDuration,
                  child: SizedBox.expand(
                    key: ValueKey(activeBackground),
                    child: activeBackground.endsWith('.webm')
                        // ? VideoPlayer(videoController)
                        ? AspectRatio(
                            aspectRatio: 16 / 9,
                            child: NativeVideoPlayerView(
                              onViewReady: (controller) async {
                                final src = await VideoSource.init(path: activeBackground, type: VideoSourceType.asset);
                                await controller.loadVideoSource(src);
                                controller.onPlaybackEnded.addListener(controller.play);
                                await controller.setVolume(0);
                                await controller.play();
                                await player.play();
                              },
                            ))
                        : Image.asset(activeBackground, fit: BoxFit.cover),
                  ),
                );
              }
              if (wrappedIndex == tombstone.index) {
                return Image.asset(tombstone.background, fit: BoxFit.cover);
              }
              return Image.asset(track.background, fit: BoxFit.cover);
            },
          ),
        ),
        SizedBox(height: 64, child: AppBar(backgroundColor: Colors.transparent)),
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
                duration: newTrackTransitionDuration,
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
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Flexible(
              flex: 1,
              child: TextScroll(
                track.name,
                style: Theme.of(context).textTheme.headlineMedium,
                delayBefore: const Duration(seconds: 2),
                pauseBetween: const Duration(seconds: 2),
              ),
            ),
            if (track.entry != null) const Gap(8),
            if (track.entry case final entry?)
              Badge(label: Text(track.variants.isEmpty ? '$entry' : '$entry$activeVariantName')),
          ]),
          if (activeEvent.isNotEmpty) const Gap(2),
          if (activeEvent.isNotEmpty)
            GestureDetector(
              onTap: handleTapEvent,
              child: Wrap(spacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Icon(Icons.location_pin, size: 18),
                Text(activeEvent, style: Theme.of(context).textTheme.titleSmall),
              ]),
            ),
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
                const IconButton.outlined(
                  tooltip: 'Add to playlist',
                  icon: Icon(Icons.playlist_add),
                  visualDensity: VisualDensity.compact,
                  // TODO: add to playlist
                  onPressed: noop,
                ),
                const Gap(8),
                AnimatedSize(
                  duration: newTrackTransitionDuration,
                  alignment: Alignment.centerRight,
                  child: track.variants.isEmpty ? const SizedBox.shrink() : variantPicker,
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
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
                onPressed: () => handleAdvance(forward: false),
              ),
              const Gap(6),
              IconButton.filled(
                onPressed: handlePlayPause,
                iconSize: 48,
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  semanticLabel: isPlaying ? 'Pause' : 'Play',
                  progress: playPauseController,
                ),
              ),
              const Gap(6),
              IconButton.outlined(
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
                onPressed: () => handleAdvance(forward: true),
              ),
              const Gap(6),
              StatefulButton(
                selected: ShuffleMode.sequential,
                iconSize: 32,
                stateChanged: (mode) {
                  player.toggleShuffle();
                  return player.shuffle ? ShuffleMode.shuffle : ShuffleMode.sequential;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> handleAutoplay({required bool wantAutoplay}) async {
    if (autoplayTimer != null && !wantAutoplay) {
      autoplayTimer!.cancel();
      setState(() {
        autoplayDuration = null;
        autoplayTimer = null;
      });
      return false;
    }
    if (!wantAutoplay) return false;
    final delay = await showDurationPicker(
      context: context,
      initialTime: autoplayDuration ?? const Duration(minutes: 10),
    );
    if (!mounted || delay == null) return false;
    setState(() {
      autoplayDuration = delay;
      autoplayTimer = Timer.periodic(delay, doAutoplay);
    });
    return true;
  }

  void resetAutoplay() {
    if ((autoplayTimer, autoplayDuration) case (var timer?, var delay?)) {
      timer.cancel();
      autoplayTimer = Timer.periodic(delay, doAutoplay);
    }
  }

  void doAutoplay(Timer _) {
    if (!mounted || !player.isPlaying.value) return;
    handleAdvance(forward: true);
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
    if (variantIndex[variant] case final index?) {
      if (!isPlaying || variant.path != player.current.value?.audio.assetAudioPath) {
        player.playlistPlayAtIndex(index);
        drivePlayPauseAnimation(toPlay: true);
      }
      activeVariant = variant;
      return;
    }

    if (variant is Track) {
      final trackIndex = Track.repo.indexOf(variant);
      player.playlistPlayAtIndex(trackIndex);
      track = variant;
      return;
    }

    activeVariant = variant;

    if (variant.path == track.path) {
      if (variant.path != player.current.value?.audio.assetAudioPath) {
        player.playlistPlayAtIndex(activeTrackIndex);
        drivePlayPauseAnimation(toPlay: true);
      }
      return;
    }

    player.playlist!.add(Audio(
      variant.path,
      metas: Metas(
        title: track.name,
        album: 'Yume 2kki OST',
        image: MetasImage(
          path: variant.background ?? track.background,
          type: ImageType.asset,
        ),
      ),
    ));
    final index = player.playlist!.audios.length - 1;
    variantIndex[variant] = index;
    player.playlistPlayAtIndex(index);
    drivePlayPauseAnimation(toPlay: true);
  }

  void handlePlayPause() {
    player.playOrPause();
    drivePlayPauseAnimation(toPlay: !isPlaying);
  }

  void handleAdvance({required bool forward}) async {
    final current = player.current.value;
    final value = forward ? 1 : -1;
    (switch (current?.playlist.nextIndex) {
      final oob? when oob >= Track.repo.length =>
        await player.playlistPlayAtIndex((activeTrackIndex + value) % Track.repo.length),
      _ when activeVariant != null => player.playlistPlayAtIndex((activeTrackIndex + value) % Track.repo.length),
      _ => forward ? await player.next() : await player.previous(),
    });
    if (autoplayTimer case var timer?) {
      timer.cancel();
      resetAutoplay();
    }
    drivePlayPauseAnimation(toPlay: true);
  }

  void handleTapEvent() async {
    final searchPage = Uri.https('yume.wiki', '/index.php', {
      'search': activeEvent.replaceAll(' ', '+'),
      'title': 'Special%3ASearch',
      'profile': 'advanced',
      'fulltext': '1',
      'ns3002': '1', // Yume 2kki
    });
    await launchUrl(searchPage);
  }

  // VideoPlayerController get videoController {
  //   final player = VideoPlayerController.asset(activeBackground);
  //   playerController?.dispose();
  //   return playerController = player
  //     ..initialize()
  //     ..setLooping(true)
  //     ..play();
  // }
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
