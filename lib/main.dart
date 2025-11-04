// [File: main.dart]

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'database.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart'; // For number input formatter

late AppDatabase database;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  database = AppDatabase();
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => database),
        Provider<CategoryDao>(create: (_) => database.categoryDao),
        Provider<TransactionDao>(create: (_) => database.transactionDao),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // --- NEW APP TITLE ---
      title: 'Financier v2',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        dialogBackgroundColor: Colors.white,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Colors.teal,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  DateTime _selectedDate = DateTime.now();
  int _selectedPageIndex = 0; // 0="All"

  // --- NEW: State for Search Bar ---
  String _searchQuery = '';
  final _searchController = TextEditingController();

  Category? _incomeMainCategory;

  @override
  void initState() {
    super.initState();
    _loadIncomeCategory();

    // --- NEW: Listener for search bar ---
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // Don't forget to dispose
    super.dispose();
  }

  Future<void> _loadIncomeCategory() async {
    final categoryDao = Provider.of<CategoryDao>(context, listen: false);
    _incomeMainCategory = await categoryDao.getIncomeMainCategory();
    setState(() {
      // Re-build now that we have this
    });
  }


  @override
  Widget build(BuildContext context) {
    final transactionDao = Provider.of<TransactionDao>(context, listen: false);
    final categoryDao = Provider.of<CategoryDao>(context, listen: false);

    return StreamBuilder<List<Category>>(
      stream: categoryDao.watchMainCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || _incomeMainCategory == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final mainCategories = snapshot.data ?? [];

        final navBarItems = <BottomNavigationBarItem>[
          const BottomNavigationBarItem(
            icon: Icon(Icons.all_inclusive),
            label: 'All',
          ),
          ...mainCategories.map((cat) => BottomNavigationBarItem(
            icon: Icon(cat.name.startsWith('💰') ? Icons.arrow_circle_up : Icons.arrow_circle_down),
            label: cat.name,
          )),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
                'Financier v2 - ${DateFormat.yMMMM().format(_selectedDate)}'),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            actions: [
              IconButton(
                icon: const Icon(Icons.summarize_outlined),
                tooltip: 'Generate Summary',
                onPressed: () => _showSummaryDialog(
                  context,
                  transactionDao,
                  categoryDao,
                  mainCategories,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                tooltip: 'Select Month',
                onPressed: _showMonthYearPicker,
              ),
              IconButton(
                icon: const Icon(Icons.category),
                tooltip: 'Manage Categories',
                onPressed: () => _showManageCategoriesDialog(context),
              ),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export to Excel',
                onPressed: () => _exportToExcel(
                    context, transactionDao, categoryDao),
              ),
            ],
          ),
          // --- MODIFIED: Body is now a Column ---
          body: Column(
            children: [
              // --- NEW: Search Bar Widget ---
              _buildSearchBar(),
              // --- NEW: Expanded list ---
              Expanded(
                child: _buildPageBody(transactionDao, categoryDao, mainCategories),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showTransactionDialog(context),
            tooltip: 'Add Transaction',
            child: const Icon(Icons.add),
          ),
          bottomNavigationBar: BottomNavigationBar(
            items: navBarItems,
            currentIndex: _selectedPageIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() {
                _selectedPageIndex = index;
              });
            },
          ),
        );
      },
    );
  }

  // --- NEW: Search Bar Widget ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search descriptions...',
          prefixIcon: const Icon(Icons.search),
          // Add a clear button
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
      ),
    );
  }

  // --- MODIFIED: Passes search query to streams ---
  Widget _buildPageBody(TransactionDao transactionDao,
      CategoryDao categoryDao, List<Category> mainCategories) {

    // Page 0: All
    if (_selectedPageIndex == 0) {
      return StreamBuilder<List<TransactionWithCategoryAndParent>>(
        // --- PASS SEARCH QUERY ---
        stream: transactionDao.watchTransactionsInMonth(_selectedDate,
            searchQuery: _searchQuery),
        builder: (context, snapshot) {
          // --- FIX: Pass mainCategories ---
          return _buildTransactionContent(context, snapshot, transactionDao, mainCategories);
        },
      );
    }

    // All other pages (Income, Expenses, etc.)
    final selectedMainCategory = mainCategories[_selectedPageIndex - 1];

    return FutureBuilder<List<int>>(
      future: categoryDao.getCategoryIdsForMain(selectedMainCategory),
      builder: (context, idSnapshot) {
        if (!idSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categoryIds = idSnapshot.data ?? [];

        return StreamBuilder<List<TransactionWithCategoryAndParent>>(
          // --- PASS SEARCH QUERY ---
          stream: transactionDao.watchTransactionsInMonthForCategories(
              _selectedDate, categoryIds,
              searchQuery: _searchQuery),
          builder: (context, transactionSnapshot) {
            // --- FIX: Pass mainCategories ---
            return _buildTransactionContent(context, transactionSnapshot, transactionDao, mainCategories);
          },
        );
      },
    );
  }

  // --- FIX: Definition now accepts mainCategories ---
  Widget _buildTransactionContent(
      BuildContext context,
      AsyncSnapshot<List<TransactionWithCategoryAndParent>> snapshot,
      TransactionDao dao,
      List<Category> mainCategories, // <-- FIX
      ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }
    final transactions = snapshot.data ?? [];

    if (transactions.isEmpty) {
      // --- MODIFIED: Show different message if searching ---
      final message = _searchQuery.isNotEmpty
          ? 'No transactions found matching "$_searchQuery".'
          : 'No transactions for this month.\nClick the "+" button to add one.';
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    final int incomeCatId = _incomeMainCategory!.id;
    double totalIncome = 0;
    double totalExpense = 0;

    for (final twc in transactions) {
      if (twc.category.id == incomeCatId || twc.category.parentId == incomeCatId) {
        totalIncome += twc.transaction.amount;
      } else {
        totalExpense += twc.transaction.amount;
      }
    }

    final double netTotal = totalIncome - totalExpense;

    String title;
    double displayTotal;
    Color displayColor;

    // --- MODIFIED: Logic to determine if current page is Income page ---
    bool isIncomePage = false;
    if (_selectedPageIndex != 0) {
      // --- FIX: Use the passed-in mainCategories list ---
      final selectedMainCategory = mainCategories[_selectedPageIndex - 1];
      if (selectedMainCategory.id == incomeCatId) {
        isIncomePage = true;
      }
    }

    if (_selectedPageIndex == 0) { // All
      title = 'Page Net Total';
      displayTotal = netTotal;
      displayColor = netTotal < 0 ? Colors.red : Colors.green;
    } else if (isIncomePage) { // Income
      title = 'Page Income Total';
      displayTotal = totalIncome;
      displayColor = Colors.green;
    } else { // Expenses
      title = 'Page Expense Total';
      displayTotal = totalExpense;
      displayColor = Colors.red;
    }


    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '$title (LKR): ${displayTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: displayColor,
            ),
          ),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        Expanded(
          child: _buildTransactionTable(context, transactions, dao),
        ),
      ],
    );
  }

  // --- Transaction Table (Unchanged) ---
  Widget _buildTransactionTable(BuildContext context,
      List<TransactionWithCategoryAndParent> transactions, TransactionDao dao) {

    final int incomeCatId = _incomeMainCategory!.id;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Category')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Actions')),
          ],
          rows: transactions.map((twc) {
            final transaction = twc.transaction;
            final category = twc.category;
            final parentCategory = twc.parentCategory;

            final bool isIncome = (category.id == incomeCatId || category.parentId == incomeCatId);

            String categoryName;
            if (parentCategory != null) {
              categoryName = "${parentCategory.name} > ${category.name}";
            } else {
              categoryName = category.name;
            }

            return DataRow(
              cells: [
                DataCell(
                    Text(DateFormat.yMd().format(transaction.dateOfFinance))),
                DataCell(Text(transaction.description)),
                DataCell(Text(categoryName)),
                DataCell(Text(
                  transaction.amount.toStringAsFixed(2),
                  style: TextStyle(
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                )),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: 'Edit',
                        onPressed: () {
                          _showTransactionDialog(context,
                              transactionToEdit: twc);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete',
                        onPressed: () {
                          _showDeleteConfirmationDialog(
                              context, transaction, dao);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Delete Confirmation Dialog (Unchanged) ---
  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, Transaction transaction, TransactionDao dao) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Transaction?'),
          content: Text(
              'Are you sure you want to delete this transaction:\n"${transaction.description}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                dao.deleteTransaction(transaction.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction deleted'),
                      backgroundColor: Colors.red),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // --- Month Picker (Unchanged) ---
  Future<void> _showMonthYearPicker() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (newDate != null) {
      setState(() {
        _selectedDate = newDate;
        _selectedPageIndex = 0; // Reset to "All" page
      });
    }
  }

  // --- Show Transaction Dialog (Unchanged) ---
  void _showTransactionDialog(BuildContext context,
      {TransactionWithCategoryAndParent? transactionToEdit}) {
    showDialog(
      context: context,
      builder: (_) =>
          _TransactionDialog(
            transactionToEdit: transactionToEdit,
          ),
    );
  }

  // --- Show Manage Categories Dialog (Unchanged) ---
  void _showManageCategoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ManageCategoriesDialog(),
    );
  }

  // --- Summary Dialog Logic (Unchanged) ---
  Future<void> _showSummaryDialog(
      BuildContext context,
      TransactionDao transactionDao,
      CategoryDao categoryDao,
      List<Category> mainCategories, // Pass main categories
      ) async {
    String pageName;
    Stream<List<TransactionWithCategoryAndParent>> dataStream;

    if (_selectedPageIndex == 0) {
      pageName = 'All Transactions';
      dataStream = transactionDao.watchTransactionsInMonth(_selectedDate,
          searchQuery: _searchQuery);
    } else {
      final selectedMainCategory = mainCategories[_selectedPageIndex - 1];
      pageName = selectedMainCategory.name;
      final categoryIds = await categoryDao.getCategoryIdsForMain(selectedMainCategory);
      dataStream = transactionDao.watchTransactionsInMonthForCategories(
          _selectedDate, categoryIds,
          searchQuery: _searchQuery);
    }

    final transactions = await dataStream.first;

    // Calculate stats
    final int itemCount = transactions.length;
    final double totalAmount =
    transactions.fold(0.0, (sum, twc) => sum + twc.transaction.amount);
    final String dateCreated =
    DateFormat.yMd().add_jm().format(DateTime.now());

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Page Summary'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Page: $pageName'),
                if (_searchQuery.isNotEmpty) Text('Search: "$_searchQuery"'),
                const SizedBox(height: 8),
                Text('Item Count: $itemCount'),
                Text('Total Amount: ${totalAmount.toStringAsFixed(2)} LKR'),
                const SizedBox(height: 8),
                Text('Generated: $dateCreated'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  // --- Export to Excel (Unchanged) ---
  Future<void> _exportToExcel(BuildContext context, TransactionDao dao,
      CategoryDao categoryDao) async {

    final transactions =
    await dao.watchTransactionsInMonth(_selectedDate).first;
    final categoryGroups =
    await categoryDao.watchCategoriesWithSubcategories().first;
    final incomeMainCategory = await categoryDao.getIncomeMainCategory();

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this month.')),
      );
      return;
    }

    final excel = Excel.createExcel();

    excel.rename(excel.getDefaultSheet()!, 'All Transactions');
    final sheet = excel['All Transactions'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Description'),
      TextCellValue('Category'),
      TextCellValue('Parent Category'),
      TextCellValue('Type'), // We'll derive this
      TextCellValue('Amount'),
      TextCellValue('Date Created'),
      TextCellValue('Date Modified'),
    ]);

    double grandTotalIncome = 0;
    double grandTotalExpense = 0;

    for (final twc in transactions) {
      final bool isIncome = (twc.category.id == incomeMainCategory.id || twc.category.parentId == incomeMainCategory.id);
      if (isIncome) {
        grandTotalIncome += twc.transaction.amount;
      } else {
        grandTotalExpense += twc.transaction.amount;
      }

      sheet.appendRow([
        TextCellValue(
            DateFormat.yMd().format(twc.transaction.dateOfFinance)),
        TextCellValue(twc.transaction.description),
        TextCellValue(twc.category.name),
        TextCellValue(twc.parentCategory?.name ?? ''),
        TextCellValue(isIncome ? 'Income' : 'Expense'), // <-- Derived Type
        DoubleCellValue(twc.transaction.amount),
        TextCellValue(DateFormat.yMd().format(twc.transaction.createdAt)),
        TextCellValue(DateFormat.yMd().format(twc.transaction.modifiedAt)),
      ]);
    }

    final summarySheet = excel['Summary by Category'];
    summarySheet.appendRow([
      TextCellValue('Category'),
      TextCellValue('Sub-Category'),
      TextCellValue('Total'),
    ]);

    // --- Income Total ---
    summarySheet.appendRow([
      TextCellValue('Total Income'),
      TextCellValue(''),
      DoubleCellValue(grandTotalIncome),
    ]);
    summarySheet.appendRow([TextCellValue(''), TextCellValue(''), TextCellValue('')]); // Spacer

    // --- Expense Totals ---
    for (final group in categoryGroups) {
      // Skip the main Income category
      if (group.category.id == incomeMainCategory.id) continue;

      double mainCategoryTotal = 0;
      final allCategoryIds = [
        group.category.id,
        ...group.subcategories.map((s) => s.id)
      ];
      final categoryTransactions = transactions
          .where((t) => allCategoryIds.contains(t.category.id))
          .toList();

      summarySheet.appendRow([
        TextCellValue(group.category.name),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      for (final subCat in group.subcategories) {
        final subCatTransactions =
        transactions.where((t) => t.category.id == subCat.id);
        final total = subCatTransactions.fold(
            0.0, (sum, t) => sum + t.transaction.amount);
        summarySheet.appendRow([
          TextCellValue(''),
          TextCellValue(subCat.name),
          DoubleCellValue(total),
        ]);
        mainCategoryTotal += total;
      }

      // Add transactions categorized *directly* under a main expense category (if any)
      final directExpenseTransactions = transactions.where((t) => t.category.id == group.category.id);
      final directTotal = directExpenseTransactions.fold(0.0, (sum, t) => sum + t.transaction.amount);
      if (directTotal > 0) {
        summarySheet.appendRow([
          TextCellValue(''),
          TextCellValue('Uncategorized'),
          DoubleCellValue(directTotal),
        ]);
        mainCategoryTotal += directTotal;
      }

      summarySheet.appendRow([
        TextCellValue('Total ${group.category.name}'),
        TextCellValue(''),
        DoubleCellValue(mainCategoryTotal),
      ]);
      summarySheet.appendRow(
          [TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    }

    summarySheet.appendRow(
        [TextCellValue(''), TextCellValue(''), TextCellValue('')]);
    summarySheet.appendRow([
      TextCellValue('NET TOTAL'),
      TextCellValue(''),
      DoubleCellValue(grandTotalIncome - grandTotalExpense),
    ]);


    // Save the file
    final bytes = excel.save();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error creating Excel file.')),
      );
      return;
    }
    final MimeType type = MimeType.microsoftExcel;
    final String fileName =
        'Finances_v2_${DateFormat('yyyy-MM').format(_selectedDate)}.xlsx';
    try {
      String? savedPath = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: type,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(savedPath != null
                ? 'File saved to $savedPath'
                : 'Save cancelled.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }
}

// --- Transaction Dialog (Unchanged) ---
class _TransactionDialog extends StatefulWidget {
  final TransactionWithCategoryAndParent? transactionToEdit;

  const _TransactionDialog({
    this.transactionToEdit,
  });

  @override
  State<_TransactionDialog> createState() => _TransactionDialogState();
}

class _TransactionDialogState extends State<_TransactionDialog> {
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

    return AlertDialog(
      title: Text(_isEditMode ? 'Edit Transaction' : 'Add Transaction'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) =>
                value == null || value.isEmpty ? 'Required' : null,
              ),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
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

              StreamBuilder<List<CategoryWithSubcategories>>(
                stream: categoryDao.watchCategoriesWithSubcategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final categoryGroups = snapshot.data ?? [];

                  final items = <DropdownMenuItem<int>>[];
                  for (final group in categoryGroups) {
                    items.add(DropdownMenuItem<int>(
                      value: group.category.id,
                      child: Text(
                        group.category.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                    decoration: const InputDecoration(labelText: 'Category'),
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

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Date: ${DateFormat.yMd().format(_selectedDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final newDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (newDate != null) {
                    setState(() {
                      _selectedDate = newDate;
                    });
                  }
                },
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
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              if (_selectedCategoryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please select a category'),
                      backgroundColor: Colors.red),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction updated'),
                      backgroundColor: Colors.green),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Transaction added'),
                      backgroundColor: Colors.green),
                );
              }
              Navigator.of(context).pop();
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// --- Manage Categories Dialog (Unchanged) ---
class _ManageCategoriesDialog extends StatefulWidget {
  const _ManageCategoriesDialog();

  @override
  State<_ManageCategoriesDialog> createState() =>
      _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<_ManageCategoriesDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int? _selectedParentId; // null means it's a main category

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryDao = Provider.of<CategoryDao>(context, listen: false);

    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration:
                    const InputDecoration(labelText: 'New Category Name'),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
                  ),
                  // Dropdown to select parent
                  StreamBuilder<List<Category>>(
                    stream: categoryDao.watchMainCategories(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final mainCategories = snapshot.data ?? [];

                      return DropdownButtonFormField<int?>(
                        value: _selectedParentId,
                        decoration:
                        const InputDecoration(labelText: 'Parent Category'),
                        hint: const Text('None (Main Category)'),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('None (Main Category)'),
                          ),
                          ...mainCategories.map((cat) {
                            return DropdownMenuItem<int?>(
                              value: cat.id,
                              child: Text(cat.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedParentId = value;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    child: const Text('Add Category'),
                    onPressed: () => _addCategory(context, categoryDao),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            // List of existing categories
            Expanded(
              child: StreamBuilder<List<CategoryWithSubcategories>>(
                stream: categoryDao.watchCategoriesWithSubcategories(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty) {
                    return const Center(child: Text('No categories yet.'));
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final mainCat = categories[index];
                      return ExpansionTile(
                        title: Row(
                          children: [
                            Expanded(
                                child: Text(mainCat.category.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold))),
                            IconButton(
                              icon:
                              const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCategory(
                                  context, categoryDao, mainCat.category.id),
                            ),
                          ],
                        ),
                        children: mainCat.subcategories.map((sub) {
                          return ListTile(
                            contentPadding: const EdgeInsets.only(
                                left: 32.0, right: 16.0),
                            title: Text(sub.name),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () =>
                                  _deleteCategory(context, categoryDao, sub.id),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  void _addCategory(BuildContext context, CategoryDao categoryDao) async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text;
      try {
        await categoryDao.addCategory(CategoriesCompanion.insert(
          name: name,
          parentId: Value(_selectedParentId),
        ));
        _nameController.clear();
        setState(() {
          _selectedParentId = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: Category "$name" may already exist.')),
        );
      }
    }
  }

  void _deleteCategory(
      BuildContext context, CategoryDao categoryDao, int id) async {
    try {
      await categoryDao.deleteCategory(id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Error: Cannot delete. Category may be in use by transactions.')),
      );
    }
  }
}