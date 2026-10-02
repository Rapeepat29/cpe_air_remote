import 'dart:async';

import '../localization/localized_material.dart';

import '../theme/app_theme.dart';

/// นาฬิกานับถอยหลังก่อนระบบสั่งปิดแอร์เพราะห้องว่าง
///
/// Backend ส่งมาแค่ `เวลาที่จะสั่งปิด` วิดเจ็ตนี้เดินนาฬิกาเองทุกวินาที
/// จึงเห็นตัวเลขลดลงต่อเนื่องโดยไม่ต้องยิงคำขอถี่ ๆ
class AutoOffCountdown extends StatefulWidget {
  const AutoOffCountdown({
    required this.deadline,
    this.attempts = 0,
    this.maxAttempts = 5,
    this.inClass = false,
    this.compact = false,
    super.key,
  });

  final DateTime? deadline;
  final int attempts;
  final int maxAttempts;
  final bool inClass;

  /// แบบย่อใช้ในการ์ดรายการห้อง แบบเต็มใช้ในหน้าควบคุม
  final bool compact;

  @override
  State<AutoOffCountdown> createState() => _AutoOffCountdownState();
}

class _AutoOffCountdownState extends State<AutoOffCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AutoOffCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final needsTicker = widget.deadline != null;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!needsTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    if (deadline == null) return const SizedBox.shrink();

    final remaining = deadline.difference(DateTime.now());
    final seconds = remaining.inSeconds;
    final isCommanding = widget.attempts > 0 || seconds <= 0;

    final label = isCommanding
        ? '${context.tr('Sending the off command')} '
              '(${widget.attempts}/${widget.maxAttempts})'
        : '${context.tr('Empty room · switching off in')} '
              '${formatCountdown(seconds)}';

    final color = isCommanding ? AppColors.red : AppColors.orange;
    final icon = isCommanding
        ? Icons.settings_remote_rounded
        : Icons.timer_outlined;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCommanding
                      ? context.tr(
                          'Retrying every 20 seconds until the power draw '
                          'drops.',
                        )
                      : (widget.inClass
                            ? context.tr(
                                'A class is scheduled now, so the wait is '
                                'longer. Anyone entering cancels it.',
                              )
                            : context.tr(
                                'Anyone entering the room cancels this.',
                              )),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 125 -> '02:05'
String formatCountdown(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = (safe ~/ 60).toString().padLeft(2, '0');
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}
