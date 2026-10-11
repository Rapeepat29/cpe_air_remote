import '../localization/localized_material.dart';
import '../models/air_conditioner.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';

/// ป้ายบอกยี่ห้อแอร์และวิธีที่บอร์ดสั่งแอร์ เช่น "Daikin · สายแอร์" หรือ "Haier · รีโมต IR"
///
/// ผู้ใช้จะรู้ได้ว่าเครื่องนี้ต่อสายแอร์แทนรีโมตติดผนัง (ฟังก์ชันน้อยกว่า)
/// หรือยิง IR เหมือนรีโมตมือถือ
class AirControlBadge extends StatelessWidget {
  const AirControlBadge({required this.protocol, super.key});

  final String protocol;

  @override
  Widget build(BuildContext context) {
    final wired = airControlTypeOf(protocol) == 'wired';
    final brand = airBrandOf(protocol);
    final type = context.tr(wired ? 'Wired' : 'IR remote');
    return Tooltip(
      message: context.tr(
        wired
            ? 'Controlled through the air-conditioner cable in place of the wall remote'
            : 'Controlled by infrared, like a handheld remote',
      ),
      child: StatusPill(
        label: brand.isEmpty ? type : '$brand · $type',
        color: wired ? AppColors.blue : AppColors.textSecondary,
        icon: wired ? Icons.cable_rounded : Icons.settings_remote_rounded,
      ),
    );
  }
}
