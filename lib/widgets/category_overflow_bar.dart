import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../database.dart';

class CategoryOverflowBar extends StatelessWidget {
  final List<Category> categories;
  final int? selectedCategoryId;
  final Function(int?) onCategorySelected;

  const CategoryOverflowBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = Theme.of(context);
        // Estimate width of each tab (icon + text + padding)
        // Increased safety margin to prevent overflow if calculation is slightly off
        const double averageTabWidth = 160.0; 
        const double moreButtonWidth = 110.0;
        
        final availableWidth = constraints.maxWidth;
        // Ensure at least 0 tabs if very narrow
        final maxVisibleTabs = ((availableWidth - moreButtonWidth) / averageTabWidth).floor().clamp(0, categories.length);

        final visibleCategories = categories.take(maxVisibleTabs).toList();
        final overflowCategories = categories.skip(maxVisibleTabs).toList();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "All" Tab
            _buildTab(
              context, 
              label: 'All', 
              icon: LucideIcons.layoutGrid, 
              isSelected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            ),
            const SizedBox(width: 8),

            // Visible Categories (Safe Scroll)
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: visibleCategories.map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildTab(
                      context,
                      label: c.name,
                      icon: c.name == '💰 Income' ? LucideIcons.wallet : LucideIcons.tag, 
                      isSelected: selectedCategoryId == c.id,
                      onTap: () => onCategorySelected(c.id),
                    ),
                  )).toList(),
                ),
              ),
            ),

            // Overflow Dropdown
            if (overflowCategories.isNotEmpty) ...[

              PopupMenuButton<int>(
                tooltip: 'More Categories',
                onSelected: (id) => onCategorySelected(id),
                itemBuilder: (context) => overflowCategories.map((c) {
                  return PopupMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.name == '💰 Income' ? LucideIcons.wallet : LucideIcons.tag, 
                             size: 16, color: theme.colorScheme.onSurface),
                        const SizedBox(width: 12),
                        Text(c.name, style: TextStyle(
                           fontWeight: selectedCategoryId == c.id ? FontWeight.bold : FontWeight.normal,
                           color: selectedCategoryId == c.id ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        )),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: overflowCategories.any((c) => c.id == selectedCategoryId) 
                        ? theme.colorScheme.primaryContainer 
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: overflowCategories.any((c) => c.id == selectedCategoryId)
                          ? theme.colorScheme.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        overflowCategories.any((c) => c.id == selectedCategoryId) 
                            ? (overflowCategories.firstWhere((c) => c.id == selectedCategoryId).name)
                            : 'More',
                        style: TextStyle(
                            color: overflowCategories.any((c) => c.id == selectedCategoryId)
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.chevronDown, size: 16, 
                           color: overflowCategories.any((c) => c.id == selectedCategoryId)
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              ],
          ],
        );
      },
    );
  }

  Widget _buildTab(BuildContext context, {
    required String label, 
    required IconData icon, 
    required bool isSelected, 
    required VoidCallback onTap
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != LucideIcons.tag || isSelected) ...[
                Icon(icon, size: 16, color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
