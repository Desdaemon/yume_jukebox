import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:text_scroll/text_scroll.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Yume 2kki Jukebox'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool hasVariants = false;

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
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
      color: Theme.of(context).colorScheme.background.withAlpha(0xDA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextScroll(
            "123A・kappa_01_2",
            style: Theme.of(context).textTheme.headlineMedium,
            delayBefore: const Duration(seconds: 2),
            pauseBetween: const Duration(seconds: 2),
          ),
          const Gap(8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(Icons.bedtime),
                  visualDensity: VisualDensity.compact,
                ),
                const Gap(8),
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(Icons.playlist_add),
                  visualDensity: VisualDensity.compact,
                ),
                const Gap(8),
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  child: !hasVariants
                      ? const SizedBox.shrink()
                      : SegmentedButton(
                          selected: const {'A'},
                          segments: [
                            const ButtonSegment(
                              value: 'A',
                              label: Text('A'),
                              enabled: true,
                            ),
                            for (final letter in 'BCDEFG'.characters)
                              ButtonSegment(value: letter, label: Text(letter))
                          ],
                          onSelectionChanged: (selection) {
                            debugPrint('$selection');
                          },
                        ),
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
                  onPressed: () {},
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 32,
                ),
              ),
              const Gap(6),
              IconButton.filled(
                onPressed: () {
                  setState(() {
                    hasVariants = !hasVariants;
                  });
                },
                icon: const Icon(Icons.pause),
                iconSize: 48,
              ),
              const Gap(6),
              IconButton.outlined(
                onPressed: () {},
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
              ),
              const Gap(6),
              StatefulButton(
                selected: ShuffleMode.sequential,
                iconSize: 32,
                stateChanged: (mode) => mode.nextState,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum IconButtons {
  normal,
  filled,
  filledTonal,
  outlined,
}

abstract interface class ButtonState<Self extends ButtonState<Self>> {
  ({IconData icon, IconButtons style, String tooltip}) get state;
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

class StatefulButton<T extends ButtonState<T>> extends StatefulWidget {
  const StatefulButton({
    super.key,
    required this.selected,
    T Function(T)? stateChanged,
    this.iconSize,
  }) : onPressed = stateChanged ?? _identity;

  final T selected;
  final T Function(T) onPressed;
  final double? iconSize;

  @protected
  T erasedOnPressed(covariant T value) {
    return onPressed(value);
  }

  static T _identity<T>(T value) => value;

  @override
  State<StatefulButton> createState() => _StatefulButtonState<T>();
}

class _StatefulButtonState<T extends ButtonState<T>>
    extends State<StatefulButton> {
  late T userState;

  @override
  void initState() {
    super.initState();
    userState = widget.selected as T;
  }

  @override
  Widget build(BuildContext context) {
    final builder = switch (userState.state.style) {
      IconButtons.normal => IconButton.new,
      IconButtons.filled => IconButton.filled,
      IconButtons.filledTonal => IconButton.filledTonal,
      IconButtons.outlined => IconButton.outlined,
    };

    return builder(
      onPressed: _onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        child: Icon(userState.state.icon, key: ValueKey(userState)),
        transitionBuilder: (widget, lerp) =>
            ScaleTransition(scale: lerp, child: widget),
      ),
      tooltip: userState.state.tooltip,
      iconSize: widget.iconSize,
    );
  }

  void _onPressed() {
    final newState = widget.erasedOnPressed(userState) as T;
    setState(() => userState = newState);
  }
}
