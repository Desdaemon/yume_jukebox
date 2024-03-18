import 'dart:async';

import 'package:flutter/material.dart';
// import 'package:yume_jukebox/main.dart';

enum IconButtons {
  normal,
  filled,
  filledTonal,
  outlined,
}

abstract interface class ButtonState<Self extends ButtonState<Self>> {
  ({IconData icon, IconButtons style, String tooltip, bool selectedStyle})
      get state;
}

class StatefulButton<T extends ButtonState<T>> extends StatefulWidget {
  const StatefulButton({
    super.key,
    required this.selected,
    FutureOr<T> Function(T)? stateChanged,
    this.iconSize,
  }) : onPressed = stateChanged ?? _identity;

  final T selected;
  final FutureOr<T> Function(T) onPressed;
  final double? iconSize;

  @protected
  FutureOr<T> erasedOnPressed(covariant T value) {
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
      isSelected: userState.state.selectedStyle,
      iconSize: widget.iconSize,
    );
  }

  void _onPressed() async {
    final newState = await Future.value(widget.erasedOnPressed(userState));
    setState(() => userState = newState as T);
  }
}
