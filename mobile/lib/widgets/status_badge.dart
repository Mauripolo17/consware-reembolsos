import 'package:flutter/material.dart';
import '../models/reimbursement.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ReimbursementStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;

    switch (status) {
      case ReimbursementStatus.approved:
        bg = AppTheme.approvedBg;
        border = AppTheme.approvedBorder;
        fg = AppTheme.approvedText;
        icon = Icons.check_circle_rounded;
      case ReimbursementStatus.rejected:
        bg = AppTheme.rejectedBg;
        border = AppTheme.rejectedBorder;
        fg = AppTheme.rejectedText;
        icon = Icons.cancel_rounded;
      case ReimbursementStatus.pending:
        bg = AppTheme.pendingBg;
        border = AppTheme.pendingBorder;
        fg = AppTheme.pendingText;
        icon = Icons.schedule_rounded;
    }

    return Semantics(
      label: 'Estado: ${status.spanishLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border.withValues(alpha: 0.55), width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status.spanishLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
