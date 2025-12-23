import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/currency_provider.dart';

class SummaryCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curProvider = Provider.of<CurrencyProvider>(context);
    final currencyFormat = NumberFormat.simpleCurrency(name: curProvider.currencyCode);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Page Net Total',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimary
                              .withValues(alpha: 0.8))),
                  const SizedBox(height: 4),
                  Text(
                    currencyFormat.format(balance),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(LucideIcons.wallet,
                  size: 32,
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Income',
                  amount: totalIncome,
                  icon: LucideIcons.arrowUpCircle,
                  color: Colors.greenAccent.shade100,
                  currencyFormat: currencyFormat,
                ),
              ),
              Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.2)),
              Expanded(
                child: _SummaryItem(
                  label: 'Expense',
                  amount: totalExpense,
                  icon: LucideIcons.arrowDownCircle,
                  color: Colors.redAccent.shade100,
                  currencyFormat: currencyFormat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final NumberFormat currencyFormat;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(amount),
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
