import 'package:festi_buvette_app/features/products/data/models/category.dart';
import 'package:festi_buvette_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Horizontal scrollable row of category filter chips.
///
/// Shows an "All" chip first, then one chip per category.
/// When [hasUncategorized] is true, appends an "Uncategorized" chip at the end.
/// Use [CategoryFilterBar.uncategorizedId] (-1) as the sentinel for that chip.
class CategoryFilterBar extends StatelessWidget {
  /// Sentinel value passed to [onSelect] when the "Uncategorized" chip is tapped.
  static const int uncategorizedId = -1;

  final List<Category> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelect;
  final bool hasUncategorized;

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
    this.hasUncategorized = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (categories.isEmpty && !hasUncategorized) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _CategoryChip(
            label: l10n.allCategories,
            selected: selectedCategoryId == null,
            onSelected: () => onSelect(null),
          ),
          ...categories.map(
            (c) => _CategoryChip(
              label: c.name,
              selected: c.id == selectedCategoryId,
              onSelected: () => onSelect(c.id),
            ),
          ),
          if (hasUncategorized)
            _CategoryChip(
              label: l10n.noCategory,
              selected: selectedCategoryId == uncategorizedId,
              onSelected: () => onSelect(uncategorizedId),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
