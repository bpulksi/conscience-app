import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/native_bridge.dart';

class AvatarView extends StatelessWidget {
  final AvatarStage stage;
  final double size;

  const AvatarView({super.key, required this.stage, this.size = 180});

  String get _asset {
    switch (stage) {
      case AvatarStage.impatient:
        return 'assets/avatars/brain/impatient.json';
      case AvatarStage.furious:
        return 'assets/avatars/brain/furious.json';
      case AvatarStage.zen:
        return 'assets/avatars/brain/zen.json';
    }
  }

  Color get _tint {
    switch (stage) {
      case AvatarStage.impatient:
        return Colors.amber;
      case AvatarStage.furious:
        return Colors.redAccent;
      case AvatarStage.zen:
        return Colors.tealAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        _asset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _Fallback(tint: _tint, size: size),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final Color tint;
  final double size;
  const _Fallback({required this.tint, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.15),
        border: Border.all(color: tint, width: 3),
      ),
      child: Icon(Icons.psychology_alt_rounded, size: size * 0.5, color: tint),
    );
  }
}
