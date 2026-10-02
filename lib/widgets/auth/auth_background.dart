import '../../localization/localized_material.dart';

import '../../theme/app_theme.dart';

class AuthBackground extends StatelessWidget {
  const AuthBackground({
    required this.child,
    this.showBackButton = false,
    super.key,
  });

  final Widget child;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    Color(0xFF12241A),
                    Color(0xFF0F1B15),
                    Color(0xFF0D1511),
                  ]
                : const [
                    Color(0xFFE8F5EC),
                    Color(0xFFF7FAF7),
                    Colors.white,
                  ],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _EnergyBackgroundPainter()),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 32, 22, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 440,
                          minHeight: constraints.maxHeight - 60,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            // ต้องอยู่ท้ายสุดของ Stack เพื่อให้รับการกดได้
            // ถ้าวางก่อนเนื้อหา SingleChildScrollView ที่กินพื้นที่เต็มจอ
            // จะทับปุ่มนี้ไว้ ทำให้เห็นปุ่มแต่กดไม่ได้
            if (showBackButton)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: colors.surface.withValues(alpha: 0.9),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: context.tr('Back'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EnergyBrand extends StatelessWidget {
  const EnergyBrand({
    this.compact = false,
    super.key,
  });

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 76.0 : 96.0;
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surface,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.energy_savings_leaf_rounded,
            size: compact ? 44 : 56,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        Text(
          'RMUTT Save Energy',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.primary,
            fontSize: compact ? 24 : 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.tr('Building 16 Energy Management System'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EnergyBackgroundPainter extends CustomPainter {
  const _EnergyBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pale = Paint()..color = const Color(0x2216834B);
    final lighter = Paint()..color = const Color(0x1043B86F);

    final topShape = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.72, 0)
      ..lineTo(size.width * 0.26, size.height * 0.42)
      ..lineTo(0, size.height * 0.58)
      ..close();
    canvas.drawPath(topShape, lighter);

    final rightShape = Path()
      ..moveTo(size.width, size.height * 0.12)
      ..lineTo(size.width, size.height * 0.62)
      ..lineTo(size.width * 0.58, size.height * 0.48)
      ..close();
    canvas.drawPath(rightShape, pale);

    final bottomShape = Path()
      ..moveTo(0, size.height * 0.84)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomShape, lighter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
