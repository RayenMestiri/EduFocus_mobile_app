import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Floating toast engine — glass, physics-driven, replaces plain SnackBars.
///
/// Three ready-made helpers cover the dashboard's feedback events:
///  · [showUndoToast]            — reversible action, shrinking countdown bar.
///  · [showSubjectCompletedToast] — top toast for "marked as done" + undo.
///  · [showDeletedBanner]        — final, non-reversible confirmation.
///
/// Invoke any of these from a widget's `onPressed`/`onTap`/`ref.listen`
/// callback — they only need a live [BuildContext] with an [Overlay] above
/// it (any screen under `MaterialApp.router` qualifies).
/// ═══════════════════════════════════════════════════════════════════════

enum ToastEdge { top, bottom }

typedef _ToastBuilder = Widget Function(BuildContext context, VoidCallback dismiss);

Future<void> _presentToast(
  BuildContext context, {
  required ToastEdge edge,
  required _ToastBuilder builder,
  VoidCallback? onSwipedAway,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastHost(
      edge: edge,
      builder: builder,
      onSwipedAway: onSwipedAway,
      onRemoved: () {
        entry.remove();
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.edge,
    required this.builder,
    required this.onRemoved,
    this.onSwipedAway,
  });

  final ToastEdge edge;
  final _ToastBuilder builder;
  final VoidCallback onRemoved;
  final VoidCallback? onSwipedAway;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  bool _removing = false;

  Future<void> _dismiss() async {
    if (_removing) return;
    _removing = true;
    await _c.reverse();
    widget.onRemoved();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = widget.edge == ToastEdge.top;
    final slide = Tween<Offset>(
      begin: Offset(0, top ? -1.3 : 1.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    final viewPadding = MediaQuery.of(context).padding;

    return Positioned(
      top: top ? viewPadding.top + 12 : null,
      bottom: top ? null : viewPadding.bottom + 88,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              final swipedAway = top ? v < -250 : v > 250;
              if (swipedAway) {
                widget.onSwipedAway?.call();
                _dismiss();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: widget.builder(context, _dismiss),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared frosted-glass shell for every toast card.
class _GlassToastShell extends StatelessWidget {
  const _GlassToastShell({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .3)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: .22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

/// Reversible-action toast with a shrinking countdown bar. Defer the actual
/// side effect until [onExpire] fires; [onUndo] fires instead if the user
/// taps the action label (or flings the toast away) before the timer ends.
Future<void> showUndoToast(
  BuildContext context, {
  required String message,
  String? subtitle,
  IconData icon = Icons.check_circle_rounded,
  Color? accentColor,
  String actionLabel = 'Annuler',
  Duration duration = const Duration(seconds: 4),
  VoidCallback? onUndo,
  VoidCallback? onExpire,
  ToastEdge edge = ToastEdge.bottom,
}) {
  final accent = accentColor ?? AppColors.accent;
  return _presentToast(
    context,
    edge: edge,
    onSwipedAway: onExpire,
    builder: (ctx, dismiss) => _UndoToastCard(
      message: message,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      actionLabel: actionLabel,
      duration: duration,
      dismiss: dismiss,
      onUndo: onUndo,
      onExpire: onExpire,
    ),
  );
}

/// Top floating toast for "task/subject marked as done" — vibrant badge,
/// glass backdrop, undo affordance in case the tap was accidental.
Future<void> showSubjectCompletedToast(
  BuildContext context, {
  required String itemName,
  VoidCallback? onUndo,
  VoidCallback? onExpire,
}) {
  return showUndoToast(
    context,
    edge: ToastEdge.top,
    message: '« $itemName » terminée',
    subtitle: 'Bravo, encore une étape franchie.',
    icon: Icons.task_alt_rounded,
    accentColor: AppColors.green,
    duration: const Duration(seconds: 4),
    onUndo: onUndo,
    onExpire: onExpire,
  );
}

/// Non-reversible confirmation banner — soft slide in, auto-fades on its own.
void showDeletedBanner(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_circle_rounded,
  Color? accentColor,
  Duration duration = const Duration(milliseconds: 2600),
}) {
  _presentToast(
    context,
    edge: ToastEdge.bottom,
    builder: (ctx, dismiss) => _AutoDismissCard(
      message: message,
      icon: icon,
      accent: accentColor ?? AppColors.textSecondary,
      duration: duration,
      dismiss: dismiss,
    ),
  );
}

class _UndoToastCard extends StatefulWidget {
  const _UndoToastCard({
    required this.message,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.duration,
    required this.dismiss,
    this.subtitle,
    this.onUndo,
    this.onExpire,
  });

  final String message;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final Duration duration;
  final VoidCallback dismiss;
  final VoidCallback? onUndo;
  final VoidCallback? onExpire;

  @override
  State<_UndoToastCard> createState() => _UndoToastCardState();
}

class _UndoToastCardState extends State<_UndoToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timer = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _timer.addStatusListener(_onStatus);
    _timer.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.dismiss();
      widget.onExpire?.call();
    }
  }

  void _handleUndo() {
    _timer.stop();
    widget.dismiss();
    widget.onUndo?.call();
  }

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassToastShell(
      accent: widget.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _IconBadge(icon: widget.icon, accent: widget.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: _handleUndo,
                style: TextButton.styleFrom(
                  foregroundColor: widget.accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  widget.actionLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: AnimatedBuilder(
              animation: _timer,
              builder: (context, _) => LinearProgressIndicator(
                value: 1 - _timer.value,
                minHeight: 3,
                backgroundColor: widget.accent.withValues(alpha: .14),
                valueColor: AlwaysStoppedAnimation(widget.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoDismissCard extends StatefulWidget {
  const _AutoDismissCard({
    required this.message,
    required this.icon,
    required this.accent,
    required this.duration,
    required this.dismiss,
  });

  final String message;
  final IconData icon;
  final Color accent;
  final Duration duration;
  final VoidCallback dismiss;

  @override
  State<_AutoDismissCard> createState() => _AutoDismissCardState();
}

class _AutoDismissCardState extends State<_AutoDismissCard> {
  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, widget.dismiss);
  }

  @override
  Widget build(BuildContext context) {
    return _GlassToastShell(
      accent: widget.accent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IconBadge(icon: widget.icon, accent: widget.accent),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              widget.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
