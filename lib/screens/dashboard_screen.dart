import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For shortcuts
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:excel/excel.dart' as excel_file;
import 'package:file_selector/file_selector.dart'; // Desktop file picker

import '../database.dart';
import '../theme/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/transaction_dialog.dart';
import '../widgets/manage_categories_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/summary_dialog.dart';

// New Widgets
import '../widgets/responsive_scaffold.dart';
import '../widgets/transaction_list.dart';
import '../widgets/transaction_form.dart';
import '../widgets/summary_card.dart';
import '../widgets/category_overflow_bar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  int? _selectedMainCategoryId;

  // Desktop State
  TransactionWithCategoryAndParent? _selectedTransaction;
  bool _showNewTransactionForm = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Shortcuts Intents ---
  void _handleNewTransactionShortcut() {
    setState(() {
      _selectedTransaction = null;
      _showNewTransactionForm = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionDao = Provider.of<TransactionDao>(context);
    final categoryDao = Provider.of<CategoryDao>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _handleNewTransactionShortcut,
      },
      child: Focus(
        autofocus: true,
        child: StreamBuilder<List<Category>>(
          stream: categoryDao.watchMainCategories(),
          builder: (context, catSnapshot) {
            final mainCategories = catSnapshot.data ?? [];

            return StreamBuilder<List<TransactionWithCategoryAndParent>>(
              stream: transactionDao.watchAllTransactions(),
              builder: (context, snapshot) {
                // ... Data Processing (Filter & Sort) ...
                final transactions = snapshot.data ?? [];
                double totalIncome = 0;
                double totalExpense = 0;

                final filteredTransactions = transactions.where((t) {
                  final matchDate = t.transaction.dateOfFinance.year == _selectedMonth.year &&
                      t.transaction.dateOfFinance.month == _selectedMonth.month;
                  if (!matchDate) return false;

                  if (_selectedMainCategoryId != null) {
                    final matchesCategory = t.category.id == _selectedMainCategoryId ||
                        t.category.parentId == _selectedMainCategoryId;
                    if (!matchesCategory) return false;
                  }

                  if (_searchQuery.isNotEmpty) {
                    final query = _searchQuery.toLowerCase();
                    final desc = t.transaction.description.toLowerCase();
                    final amount = t.transaction.amount.toString();
                    final cat = t.category.name.toLowerCase();
                    return desc.contains(query) || amount.contains(query) || cat.contains(query);
                  }
                  return true;
                }).toList();

                filteredTransactions.sort((a, b) => b.transaction.dateOfFinance.compareTo(a.transaction.dateOfFinance));

                for (var t in filteredTransactions) {
                  if (t.transaction.isIncome) {
                    totalIncome += t.transaction.amount;
                  } else {
                    totalExpense += t.transaction.amount;
                  }
                }
                double balance = totalIncome - totalExpense;

                return ResponsiveScaffold(
                  mobileLayout: _buildMobileLayout(
                    context, 
                    filteredTransactions, 
                    totalIncome, 
                    totalExpense, 
                    balance, 
                    mainCategories, 
                    themeProvider,
                    transactionDao,
                    categoryDao
                  ),
                  desktopLayout: _buildDesktopLayout(
                    context, 
                    filteredTransactions, 
                    totalIncome, 
                    totalExpense, 
                    balance, 
                    mainCategories, 
                    themeProvider,
                    transactionDao,
                    categoryDao
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ... (Mobile Layout is mostly the same as before, but using extracted widgets) ...
  Widget _buildMobileLayout(
      BuildContext context,
      List<TransactionWithCategoryAndParent> transactions,
      double income,
      double expense,
      double balance,
      List<Category> categories,
      ThemeProvider themeProvider,
      TransactionDao transactionDao,
      CategoryDao categoryDao
      ) {
      // Reconstituting the previous mobile layout using new widgets
      final theme = Theme.of(context);
      return Scaffold(
        body: CustomScrollView(
          slivers: [
             SliverAppBar.large(
               title: const Text('Financier'),
               actions: _buildAppBarActions(context, themeProvider, transactionDao, categoryDao, income, expense, balance),
             ),
             SliverToBoxAdapter(
               child: Padding(
                 padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                 child: Column(
                   children: [
                     _buildDateFilterRow(context, theme),
                     const SizedBox(height: 16),
                     SummaryCard(totalIncome: income, totalExpense: expense, balance: balance), // Reused
                     const SizedBox(height: 16),
                     _buildSearchBar(),
                   ],
                 ),
               ),
             ),
             TransactionList( // Reused
               transactions: transactions,
               onTransactionTap: (t) => _showTransactionDialog(context, transactionToEdit: t),
               onTransactionDelete: (t) => _deleteWithUndo(context, transactionDao, t),
               onTransactionDuplicate: (t) {
                   // Create a copy but with new ID (null) and current time? Or keep same date?
                   // Let's open the dialog with the data pre-filled but as a NEW transaction.
                   // We need to modify TransactionDialog/Form to accept a 'template' transaction.
                   // Or we can just pass it as 'transactionToEdit' but handle the save logic differently?
                   // Simpler: Just immediately insert a copy into DB and show snackbar.
                   _duplicateTransaction(context, transactionDao, t);
               },
             ),
             const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
          ],
        ),
        bottomNavigationBar: _buildCategoryTabs(context, categories, theme),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showTransactionDialog(context),
          heroTag: 'mobile_fab',
          icon: const Icon(LucideIcons.plus),
          label: const Text('Add'),
        ),
      );
  }

  // --- DESKTOP LAYOUT ---
  Widget _buildDesktopLayout(
      BuildContext context,
      List<TransactionWithCategoryAndParent> transactions,
      double income,
      double expense,
      double balance,
      List<Category> categories,
      ThemeProvider themeProvider,
      TransactionDao transactionDao,
      CategoryDao categoryDao
  ) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Row(
        children: [
          // 1. Navigation Rail (Collapsible-ish)
          NavigationRail(
            extended: false, // Could be toggleable
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(LucideIcons.home), 
                  label: Text('Home')
              ),
              NavigationRailDestination(
                  icon: Icon(LucideIcons.folderCog), 
                  label: Text('Categories')
              ),
              NavigationRailDestination(
                  icon: Icon(LucideIcons.settings), 
                  label: Text('Settings')
              ),
            ],
            selectedIndex: 0,
            onDestinationSelected: (index) {
               if (index == 1) _showManageCategoriesDialog(context);
               if (index == 2) _showSettingsDialog(context);
            },
            trailing: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: IconButton(
                icon: Icon(themeProvider.themeMode == ThemeMode.dark ? LucideIcons.sun : LucideIcons.moon),
                onPressed: () => themeProvider.toggleTheme(),
              ),
            ),
          ),
          const VerticalDivider(width: 1),

          // 2. Master View (List)
          Expanded(
            flex: 5,
            child: Column(
              children: [
                 // Top Bar in Master
                 Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     children: [
                       Wrap(
                         spacing: 16,
                         runSpacing: 16,
                         crossAxisAlignment: WrapCrossAlignment.center,
                         children: [
                           ConstrainedBox(
                             constraints: const BoxConstraints(minWidth: 200, maxWidth: 400),
                             child: _buildSearchBar(),
                           ),
                           InkWell(
                             onTap: () => _showMonthYearPicker(context),
                             borderRadius: BorderRadius.circular(12),
                             child: _buildDateButton(context, theme),
                           ),
                         ],
                       ),
                       const SizedBox(height: 16),
                       // Category Tabs (Responsive with Overflow)
                       if (categories.isNotEmpty)
                        CategoryOverflowBar(
                          categories: categories,
                          selectedCategoryId: _selectedMainCategoryId,
                          onCategorySelected: (id) {
                            setState(() {
                              _selectedMainCategoryId = id;
                            });
                          },
                        ),
                     ],
                   ),
                 ),
                 Expanded(
                   child: CustomScrollView(
                     slivers: [
                       TransactionList(
                         transactions: transactions,
                         onTransactionTap: (t) {
                           setState(() {
                             _selectedTransaction = t;
                             _showNewTransactionForm = false;
                           });
                         },
                         onTransactionDelete: (t) => _deleteWithUndo(context, transactionDao, t),
                         onTransactionDuplicate: (t) => _duplicateTransaction(context, transactionDao, t),
                         compactMode: true,
                       ),
                     ],
                   ),
                 ),
                 // Summary Footer in Master
                 Container(
                   decoration: BoxDecoration(
                     border: Border(top: BorderSide(color: theme.dividerColor)),
                     color: theme.colorScheme.surface,
                   ),
                   padding: const EdgeInsets.all(16),
                     child: SummaryCard(totalIncome: income, totalExpense: expense, balance: balance),
                 ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // 3. Detail View (Form)
          Expanded(
            flex: 4,
            child: Container(
              color: theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Details', style: theme.textTheme.headlineSmall),
                      FilledButton.icon(
                        // Open Dialog for New Transaction on Desktop
                        onPressed: () => _showTransactionDialog(context),
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('New Transaction'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _selectedTransaction != null
                            ? Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 600),
                                  child: TransactionForm(
                                      key: ValueKey(_selectedTransaction!.transaction.id),
                                      transactionToEdit: _selectedTransaction,
                                      onSaved: () {
                                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated!')));
                                      },
                                      onCancel: () {
                                         setState(() {
                                           _selectedTransaction = null; // Clear selection
                                         });
                                      },
                                  ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.mousePointerClick, size: 64, color: theme.colorScheme.outlineVariant),
                                    const SizedBox(height: 16),
                                    Text('Select a transaction to view details', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  List<Widget> _buildAppBarActions(BuildContext context, ThemeProvider themeProvider, TransactionDao dao, CategoryDao catDao, double income, double expense, double balance) {
    return [
      IconButton(
        icon: const Icon(LucideIcons.barChart2),
        tooltip: 'Summary',
        onPressed: () => _showSummaryDialog(context, income, expense, balance),
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
        onPressed: () => _exportToExcel(context, dao, catDao),
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildDateFilterRow(BuildContext context, ThemeData theme) {
     return Row(
       children: [
         Expanded(
           child: InkWell(
             onTap: () => _showMonthYearPicker(context),
             child: _buildDateButton(context, theme),
           ),
         ),
         const SizedBox(width: 12),
         IconButton.filledTonal(
           onPressed: () => _showManageCategoriesDialog(context),
           icon: const Icon(LucideIcons.folderCog),
           tooltip: 'Manage Categories',
         ),
       ],
     );
  }

  Widget _buildDateButton(BuildContext context, ThemeData theme) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.calendar),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMMM yyyy').format(_selectedMonth),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            const Icon(LucideIcons.chevronDown, size: 16),
          ],
        ),
      );
  }

  Widget _buildSearchBar() {
    return TextField(
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
    );
  }

  Widget _buildCategoryTabs(BuildContext context, List<Category> categories, ThemeData theme, {bool isDesktop = false}) {
     Widget content = SingleChildScrollView(
       scrollDirection: Axis.horizontal,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       child: Row(
         children: [
           _buildTabItem(context, 'All', LucideIcons.infinity, null, _selectedMainCategoryId == null),
           const SizedBox(width: 8),
           ...categories.map((cat) {
            IconData icon;
            if (cat.name.contains('Income')) icon = LucideIcons.coins;
            else if (cat.name.contains('Essential')) icon = LucideIcons.shoppingCart;
            else if (cat.name.contains('Personal')) icon = LucideIcons.coffee;
            else if (cat.name.contains('Leisure')) icon = LucideIcons.gamepad2;
            else if (cat.name.contains('Finance')) icon = LucideIcons.briefcase;
            else if (cat.name.contains('Optional')) icon = LucideIcons.sparkles;
            else icon = LucideIcons.folder;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _buildTabItem(context, cat.name, icon, cat.id, _selectedMainCategoryId == cat.id),
            );
           }),
         ],
       ),
     );
     
     if (isDesktop) return content;

     return Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: content,
     );
  }

  Widget _buildTabItem(BuildContext context, String label, IconData icon, int? id, bool isSelected) {
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final bg = isSelected ? theme.colorScheme.primaryContainer : Colors.transparent;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMainCategoryId = id;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Clean label
            ),
          ],
        ),
      ),
    );
  }

  // --- Logic Helpers ---

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
      helpText: 'Select Month',
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

  Future<void> _exportToExcel(BuildContext context, TransactionDao dao, CategoryDao categoryDao) async {
      try {
        final transactions = await dao.getAllTransactions();
        final excel = excel_file.Excel.createExcel();
        final sheetName = 'Transactions';
        final excel_file.Sheet sheet = excel[sheetName];

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
        
        if(excel.sheets.containsKey('Sheet1')) {
           excel.delete('Sheet1');
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          final fileName = 'financier_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
          
          // Use FileSelector for Desktop
          final FileSaveLocation? result = await getSaveLocation(
             suggestedName: fileName,
             acceptedTypeGroups: [const XTypeGroup(label: 'Excel', extensions: ['xlsx'])],
          );

          if (result != null) {
             final file = File(result.path);
             await file.writeAsBytes(fileBytes);

             if (!context.mounted) return;
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text('Exported to ${result.path}'), backgroundColor: Colors.green),
             );
          }
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
  }

  Future<void> _deleteWithUndo(BuildContext context, TransactionDao dao, TransactionWithCategoryAndParent t) async {
    await dao.deleteTransaction(t.transaction);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () async {
              await dao.addTransaction(
                  TransactionsCompanion.insert(
                    description: t.transaction.description,
                    amount: t.transaction.amount,
                    dateOfFinance: t.transaction.dateOfFinance,
                    categoryId: t.transaction.categoryId,
                    isIncome: Value(t.transaction.isIncome),
                    createdAt: Value(t.transaction.createdAt),
                  )
              );
            },
          ),
        ),
      );
    }
  }
  Future<void> _duplicateTransaction(BuildContext context, TransactionDao dao, TransactionWithCategoryAndParent original) async {
    final newT = TransactionsCompanion.insert(
      description: "${original.transaction.description} (Copy)",
      amount: original.transaction.amount,
      dateOfFinance: original.transaction.dateOfFinance,
      categoryId: original.transaction.categoryId,
      isIncome: Value(original.transaction.isIncome),
      createdAt: Value(DateTime.now()),
    );
    await dao.addTransaction(newT);
    if(context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction duplicated')));
    }
  }
}
