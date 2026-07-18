import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';
import 'connectivity_service.dart';

class OfflineBadge extends ConsumerWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    if (isOnline) return const SizedBox.shrink();

    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: palette.yellow.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: palette.yellow.withValues(alpha: .28),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.yellow.withValues(alpha: .04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 11, color: palette.yellow),
          const SizedBox(width: 4),
          Text(
            'HORS LIGNE',
            style: GoogleFonts.inter(
              color: palette.yellow,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
