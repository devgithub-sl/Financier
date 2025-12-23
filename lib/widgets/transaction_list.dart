import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../database.dart';
import '../providers/currency_provider.dart';

class TransactionList extends StatelessWidget {
  final List<TransactionWithCategoryAndParent> transactions;
  final Function(TransactionWithCategoryAndParent) onTransactionTap;
  final Function(TransactionWithCategoryAndParent) onTransactionDelete;
  final Function(TransactionWithCategoryAndParent)? onTransactionDuplicate;
  final bool compactMode; // For tighter desktop lists if needed

  const TransactionList({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
    required this.onTransactionDelete,
    this.onTransactionDuplicate,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final curProvider = Provider.of<CurrencyProvider>(context);
    final currencyFormat = NumberFormat.simpleCurrency(name: curProvider.currencyCode);
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.ghost, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('No transactions found',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final t = transactions[index];
          final isIncome = t.transaction.isIncome;

          return Dismissible(
            key: ValueKey(t.transaction.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: theme.colorScheme.error,
              child: const Icon(LucideIcons.trash2, color: Colors.white),
            ),
            onDismissed: (direction) => onTransactionDelete(t),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Transaction?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
            child: RepaintBoundary(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.4))),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTransactionTap(t),
                  onSecondaryTapUp: (details) {
                    final position = details.globalPosition;
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
                      items: [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [Icon(LucideIcons.pencil, size: 16), SizedBox(width: 8), Text('Edit')]),
                        ),
                        const PopupMenuItem(
                          value: 'duplicate',
                          child: Row(children: [Icon(LucideIcons.copy, size: 16), SizedBox(width: 8), Text('Duplicate')]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                        ),
                      ],
                    ).then((value) {
                       if (value == 'edit') {
                         onTransactionTap(t);
                       } else if (value == 'delete') {
                          onTransactionDelete(t);
                       } else if (value == 'duplicate') {
                          // Handle duplicate - we need a callback or logic here.
                          // For now, let's treat it as a new transaction with same data?
                          // The onTransactionTap handles 'edit', but for duplicate we might want to pre-fill form as new.
                          // Since I don't have a direct 'onDuplicate' callback in the props, I'll allow the list to handle it or just ignore for now if not strictly critical,
                          // simpler: call onTransactionTap but we need to signal it's a copy. 
                          // Actually, let's just trigger onTransactionTap, the user can then save as new? 
                          // No, onTransactionTap opens it in Edit mode.
                          
                          // Let's add onTransactionDuplicate callback to the widget.
                          if (onTransactionDuplicate != null) onTransactionDuplicate!(t);
                       }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isIncome
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                              isIncome
                                  ? LucideIcons.trendingUp
                                  : LucideIcons.trendingDown,
                              color: isIncome
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.transaction.description,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Badge(
                                    label: Text(t.category.name),
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    textColor:
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat.MMMd()
                                        .format(t.transaction.dateOfFinance),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!compactMode) ...[
                             IconButton(
                              icon: Icon(LucideIcons.trash2,
                                  size: 20,
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.6)),
                              onPressed: () async {
                                 // We use the Dismissible logic, but here we can confirm too
                                 // For now let's just trigger delete callback directly?
                                 // Ideally reusing the delete logic
                                 final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Transaction?'),
                                      content: const Text('This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                              backgroundColor: theme.colorScheme.error),
                                          onPressed: () => Navigator.of(ctx).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                 );
                                 if (confirm == true) {
                                   onTransactionDelete(t);
                                 }
                              },
                            ),
                            const SizedBox(width: 8),
                        ],
                        Text(
                          '${isIncome ? "+" : "-"}${currencyFormat.format(t.transaction.amount)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: isIncome
                                ? Colors.green
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        childCount: transactions.length,
      ),
    );
  }
}
