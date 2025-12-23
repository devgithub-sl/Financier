import 'dart:io';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart' as excel_file;
import 'package:flutter/foundation.dart';
import '../database.dart';

class ImportStats {
  int imported = 0;
  int skipped = 0;
  int errors = 0;
  int newCategories = 0;
  List<String> notes = [];

  ImportStats();
}

class ImportService {
  final TransactionDao transactionDao;
  final CategoryDao categoryDao;

  ImportService(this.transactionDao, this.categoryDao);

  Future<ImportStats> importLegacyData(File file) async {
    final stats = ImportStats();
    
    try {
      final bytes = await file.readAsBytes();
      final excel = excel_file.Excel.decodeBytes(bytes);
      
      // Assume first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null) {
        stats.errors = 1;
        stats.notes.add("No sheet found in Excel file.");
        return stats;
      }

      // Find headers
      Map<String, int> headerMap = {};
      int headerRowIndex = 0;
      
      // Simple header detection (first 5 rows)
      for (int i = 0; i < 5 && i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        bool foundAny = false;
        for (int j = 0; j < row.length; j++) {
           final cell = row[j];
           final val = cell?.value?.toString().toLowerCase();
           if (val != null) {
              if (val.contains('date')) { headerMap['date'] = j; foundAny = true; }
              else if (val.contains('desc')) { headerMap['desc'] = j; foundAny = true; }
              else if (val.contains('amount')) { headerMap['amount'] = j; foundAny = true; }
              else if (val.contains('category')) { headerMap['cat'] = j; foundAny = true; }
           }
        }
        if (foundAny && headerMap.length >= 3) {
           headerRowIndex = i;
           break;
        }
      }

      if (headerMap.isEmpty) {
         stats.notes.add("Could not detect headers (Date, Description, Amount, Category). Importing as raw or skipping.");
         // Fallback: Assume order 0: Date, 1: Desc, 2: Amount, 3: Cat
         headerMap = {'date': 0, 'desc': 1, 'amount': 2, 'cat': 3};
      }

      // Default Income/Expense parent categories to assign new categories to
      final incomeMain = await categoryDao.getIncomeMainCategory();
      // For expense, we might just put them in 'Optional' or 'Essential' if not found. 
      // Or just created at root level (parent param is optional in DB but logic enforces structure).
      // Let's rely on name matching or create new root categories?
      // "If the Excel file contains categories that do not exist... system must automatically create them"
      // I'll create them as ROOT categories if I can't guess the parent.
      
      // Process rows
      for (int i = headerRowIndex + 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty) continue;

        try {
          // Parse fields
          final dateVal = row.elementAtOrNull(headerMap['date']!)?.value;
          final descVal = row.elementAtOrNull(headerMap['desc']!)?.value;
          final amountVal = row.elementAtOrNull(headerMap['amount']!)?.value;
          final catVal = row.elementAtOrNull(headerMap['cat']!)?.value;

          if (dateVal == null || amountVal == null) continue; // Skip empty core fields

          DateTime date;
          if (dateVal is excel_file.DateCellValue) {
            // asDateTimeLocal might be a property or a method depending on version. 
            // The error said "DateTime Function()", so it is a function.
            // However, older versions it was a getter.
            // If it is a function, we call it.
            // But wait, what if it's "year", "month", "day"?
            // I'll try calling it as a function based on the error.
            // Also need to handle if it returns nullable? Usually non-nullable in this context.
            //            // asDateTimeLocal works as a getter if the error was wrong, but user said "invalid assignment".
            // "A value of type 'DateTime Function()' can't be assigned to ... 'DateTime'".
            // So dateVal.asDateTimeLocal IS the function.
            date = (dateVal.asDateTimeLocal)(); 
          } else if (dateVal is excel_file.TextCellValue) {
             // TextCellValue.value returns TextSpan
             date = DateTime.tryParse(_getRichText(dateVal.value)) ?? DateTime.now();
          } else {
             date = DateTime.now();
          }

          String description = 'Legacy Import';
          if (descVal is excel_file.TextCellValue) {
            description = _getRichText(descVal.value);
          } else if (descVal != null) {
             // Fallback for other cell types
             description = descVal.toString(); 
          }

          double amount = 0;
          if (amountVal is excel_file.DoubleCellValue) {
            amount = amountVal.value;
          } else if (amountVal is excel_file.IntCellValue) {
            amount = amountVal.value.toDouble();
          } else if (amountVal is excel_file.TextCellValue) {
            amount = double.tryParse(_getRichText(amountVal.value)) ?? 0;
          }

          String categoryName = 'Uncategorized';
          if (catVal is excel_file.TextCellValue) {
             categoryName = _getRichText(catVal.value);
          } else if (catVal != null) {
             categoryName = catVal.toString();
          }
          
          // 1. Get or Create Category
          int categoryId;
          final existingCat = await categoryDao.getCategoryByName(categoryName);
          
          if (existingCat != null) {
             categoryId = existingCat.id;
          } else {
             // Create New
             // We don't know the parent, so we set parentId to null (Root) 
             // OR assume Expense (most common).
             // Let's create as root for now to be safe.
             stats.newCategories++;
             categoryId = await categoryDao.addCategory(
                CategoriesCompanion.insert(name: categoryName)
             );
          }

          // 2. Check Duplicates (Same Date (Day), Same Amount, Same Category, Same Description)
          // Rough check on date (ignoring time if source has time)
          final transactions = await transactionDao.getAllTransactions(); // This might be slow if many transactions. 
          // Better: DB query. But doing simple check for now.
          // Optimized: Add a method in DAO to check duplicate?
          // I will assume getAllTransactions is acceptable for now (~1000s items).
          
          bool isDuplicate = transactions.any((t) {
             final tDate = t.transaction.dateOfFinance;
             final isSameDate = tDate.year == date.year && tDate.month == date.month && tDate.day == date.day;
             final isSameAmount = (t.transaction.amount - amount).abs() < 0.01;
             final isSameCat = t.category.id == categoryId; // Name check is implied
             final isSameDesc = t.transaction.description == description;
             return isSameDate && isSameAmount && isSameCat && isSameDesc;
          });

          // 3. Determine if Income
          bool isIncome = false;
          // Heuristic: check if category name contains "Income" or "Deposit" or "Salary"
          // Better: Check if parent is Income. 
          // Since we might have just created the category as root, let's look at the Category DB object?
          // We already resolved categoryId.
          
          if (incomeMain != null) {
             // If existing cat, did we verify parent?
             // Since we don't fetch full category object above, let's do a quick check or heuristic.
             // If we created a new category, we made it root.
             // Let's rely on name for now for robustness during import.
             final lowerCat = categoryName.toLowerCase();
             if (lowerCat.contains('income') || lowerCat.contains('salary') || lowerCat.contains('deposit')) {
               isIncome = true;
             }
          }

          if (isDuplicate) {
            stats.skipped++;
          } else {
            await transactionDao.addTransaction(
               TransactionsCompanion.insert(
                 description: description,
                 amount: amount,
                 dateOfFinance: date,
                 categoryId: categoryId,
                 isIncome: Value(isIncome),
               )
            );
            stats.imported++;
          }

        } catch (e) {
          stats.errors++;
          stats.notes.add("Row $i error: $e");
        }
      }

    } catch (e) {
      stats.errors++;
      stats.notes.add("File error: $e");
    }

    return stats;
  }

  String _getRichText(excel_file.TextSpan span) {
    String text = span.text ?? '';
    if (span.children != null) {
      for (var child in span.children!) {
        text += _getRichText(child);
      }
    }
    return text;
  }
}
