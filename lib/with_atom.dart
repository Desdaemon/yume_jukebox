import 'package:atom/atom.dart' as atom;
import 'package:flutter/material.dart';

mixin AtomHelpers<T extends StatefulWidget> on State<T> {
  final _effects = <atom.Effect>[];

  void effect(void Function() effect) {
    _effects.add(atom.effect(effect));
  }

  // void once(void Function() effect) {
  //   atom.Effect? effect_;
  //   try {
  //     effect_ = atom.effect(effect);
  //   } finally {
  //     effect_?.cancel();
  //   }
  // }

  @override
  void dispose() {
    for (final effect in _effects) {
      effect.cancel();
    }
    _effects.clear();
    super.dispose();
  }
}

class AtomBuilder<T> extends StatelessWidget {
  const AtomBuilder(this.buildWith, {super.key, required atom.Atom<T> atom})
      : _atom = atom;

  final atom.Atom<T> _atom;

  final Widget Function(BuildContext context, T value) buildWith;

  @override
  Widget build(BuildContext context) {
    void Function(void Function()) setState_;
    return StatefulBuilder(
      builder: (context, $setState) {
        setState_ = $setState;
        atom.Effect? effect;
        effect = atom.effect(() {
          _atom();
          if (!context.mounted) return;
          setState_(() {
            effect?.cancel();
          });
        });
        return buildWith(context, _atom.value);
      },
    );
  }
}
