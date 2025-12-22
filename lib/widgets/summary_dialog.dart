import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';

class SummaryDialog extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;

  const SummaryDialog({
    super.key,
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final currencyCode = Provider.of<CurrencyProvider>(context).currencyCode;
    final theme = Theme.of(context);


    return AlertDialog(
      title: const Text('Monthly Summary'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow(context, 'Income', income, Colors.green),
          const SizedBox(height: 8),
          _buildSummaryRow(context, 'Expenses', expense, Colors.red),
          const Divider(height: 24),
          _buildSummaryRow(context, 'Balance', balance, theme.colorScheme.primary, isTotal: true),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, double amount, Color color, {bool isTotal = false}) {
    final currencyCode = Provider.of<CurrencyProvider>(context, listen: false).currencyCode;
    final format = NumberFormat.simpleCurrency(name: currencyCode);
    final theme = Theme.of(context);

    // For non-totals, ensure amount is positive for display if it's logically positive (income/expense totals passed as positive usually)
    // But expense might be passed as positive or negative. Assuming passed as positive magnitude.

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
              : theme.textTheme.bodyLarge,
        ),
        Text(
          format.format(amount),
          style: (isTotal
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.bodyLarge)
              ?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
