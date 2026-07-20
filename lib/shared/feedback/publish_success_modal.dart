import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import 'confetti_burst.dart';

/// Celebration shown right after a study pack/note/QCM is published — badge
/// burst, shareable link/code preview, and one-tap clipboard copy.
Future<void> showPublishSuccessModal(
  BuildContext context, {
  required String itemTitle,
  required String shareLink,
  String? shareCode,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Publié',
    barrierColor: Colors.black.withValues(alpha: .55),
    transitionDuration: const Duration(milliseconds: 460),
    pageBuilder: (_, _, _) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, _, _) {
      final scale = CurvedAnimation(
        parent: anim,
        curve: Curves.elasticOut,
      ).drive(Tween(begin: .82, end: 1.0));
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0, .4)),
        child: ScaleTransition(
          scale: scale,
          child: _PublishCard(
            itemTitle: itemTitle,
            shareLink: shareLink,
            shareCode: shareCode,
          ),
        ),
      );
    },
  );
}

class _PublishCard extends StatefulWidget {
  const _PublishCard({
    required this.itemTitle,
    required this.shareLink,
    this.shareCode,
  });

  final String itemTitle;
  final String shareLink;
  final String? shareCode;

  @override
  State<_PublishCard> createState() => _PublishCardState();
}

class _PublishCardState extends State<_PublishCard> {
  bool _copiedLink = false;
  bool _copiedCode = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.shareLink));
    if (!mounted) return;
    setState(() => _copiedLink = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copiedLink = false);
    });
  }

  Future<void> _copyCode() async {
    if (widget.shareCode == null) return;
    await Clipboard.setData(ClipboardData(text: widget.shareCode!));
    if (!mounted) return;
    setState(() => _copiedCode = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copiedCode = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                top: -50,
                child: SizedBox(
                  width: 320,
                  height: 220,
                  child: ConfettiBurst(particleCount: 50),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.yellow.withValues(alpha: .4),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.yellow.withValues(alpha: .25),
                          blurRadius: 36,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.yellow, AppColors.accent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.yellow.withValues(alpha: .5),
                                blurRadius: 26,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Publié avec succès !',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                            letterSpacing: -.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '« ${widget.itemTitle} » est maintenant visible dans le Study Hub communautaire.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.link_rounded,
                                    size: 16,
                                    color: AppColors.accentText,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.shareLink,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: _copyLink,
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          _copiedLink ? Icons.check_rounded : Icons.copy_rounded,
                                          size: 16,
                                          color: _copiedLink ? AppColors.green : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.shareCode != null) ...[
                                const Divider(height: 12, thickness: 1, indent: 4, endIndent: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.qr_code_rounded,
                                      size: 16,
                                      color: AppColors.accentText,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        widget.shareCode!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _copyCode,
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            _copiedCode ? Icons.check_rounded : Icons.copy_rounded,
                                            size: 16,
                                            color: _copiedCode ? AppColors.green : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _copyLink,
                            icon: Icon(
                              _copiedLink ? Icons.check_rounded : Icons.copy_rounded,
                              size: 18,
                            ),
                            label: Text(_copiedLink ? 'Lien copié !' : 'Copier le lien'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _copiedLink
                                  ? AppColors.green
                                  : AppColors.accent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Fermer',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
