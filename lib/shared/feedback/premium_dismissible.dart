import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';

/// Swipe-to-delete wrapper with a crimson gradient reveal, a trash icon that
/// expands elastically as the swipe progresses, and a haptic tick at the
/// commit threshold. Pair with [showUndoToast] in [onDismissed] so the
/// underlying deletion can still be cancelled for a few seconds.
class PremiumDismissible extends StatefulWidget {
  const PremiumDismissible({
    required super.key,
    required this.child,
    required this.onDismissed,
    this.direction = DismissDirection.endToStart,
  });

  final Widget child;
  final VoidCallback onDismissed;
  final DismissDirection direction;

  @override
  State<PremiumDismissible> createState() => _PremiumDismissibleState();
}

class _PremiumDismissibleState extends State<PremiumDismissible> {
  double _progress = 0;
  bool _hapticFired = false;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: widget.key!,
      direction: widget.direction,
      onUpdate: (details) {
        setState(() => _progress = details.progress);
        if (details.progress > .45 && !_hapticFired) {
          _hapticFired = true;
          HapticFeedback.mediumImpact();
        } else if (details.progress < .3 && _hapticFired) {
          _hapticFired = false;
        }
      },
      onDismissed: (_) => widget.onDismissed(),
      background: _buildBackground(alignEnd: false),
      secondaryBackground: _buildBackground(alignEnd: true),
      child: widget.child,
    );
  }

  Widget _buildBackground({required bool alignEnd}) {
    final scale = (.6 + _progress * .9).clamp(.6, 1.5);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          end: alignEnd ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            AppColors.red.withValues(alpha: .85),
            AppColors.red.withValues(alpha: .5),
          ],
        ),
      ),
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
