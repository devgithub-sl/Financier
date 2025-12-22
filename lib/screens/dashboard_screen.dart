import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:excel/excel.dart' as excel_file;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../database.dart';
import '../theme/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/transaction_dialog.dart';
import '../widgets/manage_categories_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/summary_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  int? _incomeCategoryId;

  @override
  void initState() {
    super.initState();
    _loadIncomeCategory();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _loadIncomeCategory() async {
    final categoryDao = Provider.of<CategoryDao>(context, listen: false);
    final category = await categoryDao.getCategoryByName('Income');
    if (category != null) {
      if (!mounted) return;
      setState(() {
        _incomeCategoryId = category.id;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionDao = Provider.of<TransactionDao>(context);
    final categoryDao = Provider.of<CategoryDao>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final theme = Theme.of(context);

    // Formatters
    final currencyFormat = NumberFormat.simpleCurrency(name: currencyProvider.currencyCode);

    return Scaffold(
      body: StreamBuilder<List<Category>>(
        stream: categoryDao.watchMainCategories(),
        builder: (context, catSnapshot) {
          final mainCategories = catSnapshot.data ?? [];

          return StreamBuilder<List<TransactionWithCategoryAndParent>>(
            stream: transactionDao.watchAllTransactions(),
            builder: (context, snapshot) {
               // Calculate Summary
              double totalIncome = 0;
              double totalExpense = 0;
              final transactions = snapshot.data ?? [];

              final filteredTransactions = transactions.where((t) {
                final matchDate = t.transaction.dateOfFinance.year == _selectedMonth.year &&
                    t.transaction.dateOfFinance.month == _selectedMonth.month;
                if (!matchDate) return false;

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  final desc = t.transaction.description.toLowerCase();
                  final amount = t.transaction.amount.toString();
                  final cat = t.category.name.toLowerCase();
                  return desc.contains(query) || amount.contains(query) || cat.contains(query);
                }
                return true;
              }).toList();

              // Sort by date descending
              filteredTransactions.sort((a, b) => b.transaction.dateOfFinance.compareTo(a.transaction.dateOfFinance));

              for (var t in filteredTransactions) {
                // Determine if income or expense based on root category
                bool isIncome = false;
                if (_incomeCategoryId != null) {
                   if (t.parentCategory != null) {
                     if (t.parentCategory!.id == _incomeCategoryId) isIncome = true;
                   } else {
                     if (t.category.id == _incomeCategoryId) isIncome = true;
                   }
                }
                if (isIncome) {
                  totalIncome += t.transaction.amount;
                } else {
                  totalExpense += t.transaction.amount;
                }
              }
              double balance = totalIncome - totalExpense;

              return CustomScrollView(
                slivers: [
                  SliverAppBar.large(
                    title: const Text('Financier'),
                    centerTitle: false,
                    actions: [
                      IconButton(
                        icon: const Icon(LucideIcons.barChart2),
                        tooltip: 'Summary',
                        onPressed: () => _showSummaryDialog(context, totalIncome, totalExpense, balance),
                      ),
                      IconButton(
                         icon: const Icon(LucideIcons.settings),
                         tooltip: 'Settings',
                         onPressed: () => _showSettingsDialog(context),
                      ),
                      IconButton(
                        icon: Icon(themeProvider.themeMode == ThemeMode.dark ? LucideIcons.sun : LucideIcons.moon),
                        onPressed: () => themeProvider.toggleTheme(),
                        tooltip: 'Toggle Theme',
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.sheet),
                        tooltip: 'Export to Excel',
                        onPressed: () => _exportToExcel(context, transactionDao, categoryDao),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          // Date & Filter Row
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showMonthYearPicker(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: theme.colorScheme.outlineVariant),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(LucideIcons.calendar),
                                        const SizedBox(width: 12),
                                        Text(
                                          DateFormat('MMMM yyyy').format(_selectedMonth),
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        const Spacer(),
                                        const Icon(LucideIcons.chevronDown, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton.filledTonal(
                                onPressed: () => _showManageCategoriesDialog(context),
                                icon: const Icon(LucideIcons.folderCog),
                                tooltip: 'Manage Categories',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Summary Card
                          Container(
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
                                        Text('Total Balance', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
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
                                    Icon(LucideIcons.wallet, size: 32, color: theme.colorScheme.onPrimary.withValues(alpha: 0.5)),
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
                                        color: Colors.greenAccent.shade100, // Light for contrast on dark primary
                                        currencyFormat: currencyFormat,
                                      ),
                                    ),
                                    Container(
                                        width: 1, height: 40,
                                        color: theme.colorScheme.onPrimary.withValues(alpha: 0.2)
                                    ),
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
                          ),
                          const SizedBox(height: 16),
                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search transactions...',
                              prefixIcon: Icon(LucideIcons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (filteredTransactions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Icon(LucideIcons.ghost, size: 64, color: theme.colorScheme.outline),
                             const SizedBox(height: 16),
                             Text('No transactions found', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final t = filteredTransactions[index];
                           bool isIncome = false;
                           if (_incomeCategoryId != null) {
                             if (t.parentCategory != null) {
                               if (t.parentCategory!.id == _incomeCategoryId) isIncome = true;
                             } else {
                               if (t.category.id == _incomeCategoryId) isIncome = true;
                             }
                           }

                          return Dismissible(
                            key: ValueKey(t.transaction.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: theme.colorScheme.error,
                              child: const Icon(LucideIcons.trash2, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await _showDeleteConfirmationDialog(context, t.transaction, transactionDao);
                            },
                            child: RepaintBoundary(
                              child: Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showTransactionDialog(context, transactionToEdit: t),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isIncome ? theme.colorScheme.tertiaryContainer : theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                            isIncome ? LucideIcons.trendingUp : LucideIcons.receipt,
                                            color: isIncome ? theme.colorScheme.onTertiaryContainer : theme.colorScheme.onSecondaryContainer
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.transaction.description,
                                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Badge(
                                                  label: Text(t.category.name),
                                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                  textColor: theme.colorScheme.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  DateFormat.MMMd().format(t.transaction.dateOfFinance),
                                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${isIncome ? "+" : "-"}${currencyFormat.format(t.transaction.amount)}',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: isIncome ? Colors.green : theme.colorScheme.error,
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
                        childCount: filteredTransactions.length,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransactionDialog(context),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add'),
      ),
    );
  }

  // --- Helper Methods ---

  Future<void> _showMonthYearPicker(BuildContext context) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 5);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select Month (Day ignored)',
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _selectedMonth = picked;
      });
    }
  }

  void _showTransactionDialog(BuildContext context, {TransactionWithCategoryAndParent? transactionToEdit}) {
    showDialog(
      context: context,
      builder: (context) => TransactionDialog(transactionToEdit: transactionToEdit),
    );
  }

  void _showManageCategoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ManageCategoriesDialog(),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SettingsDialog(),
    );
  }

  void _showSummaryDialog(BuildContext context, double income, double expense, double balance) {
    showDialog(
      context: context,
      builder: (context) => SummaryDialog(income: income, expense: expense, balance: balance),
    );
  }

  Future<bool?> _showDeleteConfirmationDialog(
      BuildContext context, Transaction transaction, TransactionDao dao) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
               style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
               onPressed: () async {
                  await dao.deleteTransaction(transaction.id);
                  if (context.mounted) Navigator.of(context).pop(true);
               },
               child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToExcel(BuildContext context, TransactionDao dao,
      CategoryDao categoryDao) async {
      try {
        final transactions = await dao.getAllTransactions();
        final excel = excel_file.Excel.createExcel();
        final sheetName = 'Transactions';
        final excel_file.Sheet sheet = excel[sheetName];

        // Headers
        sheet.appendRow([
          excel_file.TextCellValue('ID'),
          excel_file.TextCellValue('Description'),
          excel_file.TextCellValue('Amount'),
          excel_file.TextCellValue('Category'),
          excel_file.TextCellValue('Parent Category'),
          excel_file.TextCellValue('Date'),
          excel_file.TextCellValue('Created At')
        ]);

        for (final t in transactions) {
          sheet.appendRow([
            excel_file.IntCellValue(t.transaction.id),
            excel_file.TextCellValue(t.transaction.description),
            excel_file.DoubleCellValue(t.transaction.amount),
            excel_file.TextCellValue(t.category.name),
            excel_file.TextCellValue(t.parentCategory?.name ?? ''),
            excel_file.TextCellValue(DateFormat('yyyy-MM-dd').format(t.transaction.dateOfFinance)),
            excel_file.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(t.transaction.createdAt)),
          ]);
        }
        
        // Remove default sheet if exists
        if(excel.sheets.containsKey('Sheet1')) {
           excel.delete('Sheet1');
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          final fileName = 'financier_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
          
          // Request path from user
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Excel File',
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (outputFile != null) {
             final file = File(outputFile);
             await file.writeAsBytes(fileBytes);

             if (!context.mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Exported to $outputFile'), backgroundColor: Colors.green),
             );
          } else {
            // User canceled
          }
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
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
             Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
           ],
        ),
        const SizedBox(height: 4),
        Text(
          currencyFormat.format(amount), // Use the passed format
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
