import '../localization/localized_material.dart';

class WeekdaySelector extends StatelessWidget {
  const WeekdaySelector({
    required this.selectedDay,
    required this.onChanged,
    this.dayKeyPrefix = 'weekday',
    super.key,
  });

  final int selectedDay;
  final ValueChanged<int> onChanged;
  final String dayKeyPrefix;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: List.generate(_days.length, (index) {
          final isSelected = selectedDay == index;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == _days.length - 1 ? 0 : 3,
              ),
              child: Semantics(
                button: true,
                selected: isSelected,
                label: context.tr(_days[index]),
                child: InkWell(
                  key: Key('$dayKeyPrefix-$index'),
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    key: isSelected
                        ? Key('$dayKeyPrefix-selected-$index')
                        : null,
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      _days[index],
                      maxLines: 1,
                      style: TextStyle(
                        color: isSelected
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
