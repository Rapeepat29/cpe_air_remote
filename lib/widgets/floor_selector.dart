import '../localization/localized_material.dart';

class FloorSelector extends StatelessWidget {
  const FloorSelector({
    required this.selectedFloor,
    required this.onChanged,
    this.floors = const [1, 2, 3],
    super.key,
  });

  final int selectedFloor;
  final ValueChanged<int> onChanged;
  final List<int> floors;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleFloors = floors.isEmpty ? const [0] : floors;

    return Container(
      height: 50,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 5.0;
          final totalGap = gap * (visibleFloors.length - 1);
          final fittedWidth =
              (constraints.maxWidth - totalGap) / visibleFloors.length;
          final itemWidth = fittedWidth < 88 ? 88.0 : fittedWidth;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visibleFloors.length,
            separatorBuilder: (_, __) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final floor = visibleFloors[index];
              final isSelected = selectedFloor == floor;
              return SizedBox(
                width: itemWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(floor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      // -1 คือตัวเลือก `ทุกชั้น` ที่หน้าสถิติใช้
                      floor < 0
                          ? 'All floors'
                          : floor == 0
                          ? 'Special'
                          : 'Floor $floor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
