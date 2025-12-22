import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:lucide_icons/lucide_icons.dart';

import '../database.dart';

class TransactionDialog extends StatefulWidget {
  final TransactionWithCategoryAndParent? transactionToEdit;

  const TransactionDialog({
    super.key,
    this.transactionToEdit,
  });

  @override
  State<TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<TransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final transaction = widget.transactionToEdit!.transaction;
      _isEditMode = true;
      _descController.text = transaction.description;
      _amountController.text = transaction.amount.toString();
      _selectedDate = transaction.dateOfFinance;
      _selectedCategoryId = transaction.categoryId;
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryDao = Provider.of<CategoryDao>(context, listen: false);
    final transactionDao = Provider.of<TransactionDao>(context, listen: false);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
              _isEditMode ? LucideIcons.pencil : LucideIcons.plusCircle,
              color: theme.colorScheme.primary
          ),
          const SizedBox(width: 8),
          Text(_isEditMode ? 'Edit Transaction' : 'New Transaction', style: theme.textTheme.titleLarge),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(LucideIcons.text),
                ),
                validator: (value) =>
                value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(LucideIcons.dollarSign),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (double.tryParse(value) == null) return 'Invalid number';
                  if (double.parse(value) <= 0) return 'Must be positive';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<CategoryWithSubcategories>>(
                stream: categoryDao.watchCategoriesWithSubcategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const LinearProgressIndicator();
                  }
                  final categoryGroups = snapshot.data ?? [];

                  final items = <DropdownMenuItem<int>>[];
                  for (final group in categoryGroups) {
                    items.add(DropdownMenuItem<int>(
                      value: group.category.id,
                      child: Text(
                        group.category.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary
                        ),
                      ),
                    ));
                    for (final subCat in group.subcategories) {
                      items.add(DropdownMenuItem<int>(
                        value: subCat.id,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(subCat.name),
                        ),
                      ));
                    }
                  }

                  if (_selectedCategoryId != null &&
                      !items.any((item) => item.value == _selectedCategoryId)) {
                    _selectedCategoryId = null;
                  }

                  return DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(LucideIcons.tag),
                    ),
                    items: items,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    validator: (value) =>
                    value == null ? 'Required' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (newDate != null) {
                    if (!mounted) return;
                    setState(() {
                      _selectedDate = newDate;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(LucideIcons.calendar),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (_selectedCategoryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: const Text('Please select a category'),
                      backgroundColor: theme.colorScheme.error),
                );
                return;
              }

              final amount = double.parse(_amountController.text);

              if (_isEditMode) {
                final updatedTransaction = TransactionsCompanion(
                  id: Value(widget.transactionToEdit!.transaction.id),
                  description: Value(_descController.text),
                  amount: Value(amount),
                  dateOfFinance: Value(_selectedDate),
                  categoryId: Value(_selectedCategoryId!),
                );
                await transactionDao.updateTransaction(updatedTransaction);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction updated'),
                      behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                final newTransaction = TransactionsCompanion(
                  description: Value(_descController.text),
                  amount: Value(amount),
                  dateOfFinance: Value(_selectedDate),
                  categoryId: Value(_selectedCategoryId!),
                  createdAt: Value(DateTime.now()),
                );
                await transactionDao.addTransaction(newTransaction);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction added'),
                      behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              if (mounted) Navigator.of(context).pop();
            }
          },
          icon: const Icon(LucideIcons.save, size: 16),
          label: Text(_isEditMode ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}
