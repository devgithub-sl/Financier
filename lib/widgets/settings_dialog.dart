import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../database.dart';
import '../services/import_service.dart';
import '../providers/currency_provider.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  Future<void> _importLegacyData(BuildContext context) async {
     try {
       final result = await FilePicker.platform.pickFiles(
         type: FileType.custom,
         allowedExtensions: ['xlsx', 'xls'],
       );

       if (result != null && result.files.single.path != null) {
         if (!context.mounted) return;
         
         // Show loading
         showDialog(
           context: context, 
           barrierDismissible: false,
           builder: (c) => const Center(child: CircularProgressIndicator())
         );

         final file = File(result.files.single.path!);
         final transactionDao = Provider.of<TransactionDao>(context, listen: false);
         final categoryDao = Provider.of<CategoryDao>(context, listen: false);
         final importService = ImportService(transactionDao, categoryDao);
         
         final stats = await importService.importLegacyData(file);

         if (!context.mounted) return;
         Navigator.of(context).pop(); // Close loading

         // Show result
         showDialog(
           context: context,
           builder: (c) => AlertDialog(
             title: const Text('Import Complete'),
             content: Text('Imported: ${stats.imported}\nSkipped (Duplicates): ${stats.skipped}\nNew Categories: ${stats.newCategories}\nErrors: ${stats.errors}'),
             actions: [
               TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))
             ],
           ),
         );
       }
     } catch (e) {
       if (context.mounted) {
         Navigator.of(context).pop(); // Close loading if open (this might be risky if loading wasn't open, but acceptable for now)
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error picking file: $e'), backgroundColor: Colors.red),
         );
       }
     }
  }

  @override
  Widget build(BuildContext context) {
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final theme = Theme.of(context);

    // Common currencies list
    final currencies = ['USD', 'EUR', 'GBP', 'JPY', 'LKR', 'AUD', 'CAD', 'CHF', 'CNY', 'INR'];

    return AlertDialog(
      title: const Text('Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Currency', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: currencyProvider.currencyCode,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: currencies.map((code) => DropdownMenuItem(
              value: code,
              child: Text(code),
            )).toList(),
            onChanged: (value) {
              if (value != null) {
                currencyProvider.setCurrency(value);
              }
            },
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text('Data Management', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file),
            title: const Text('Import Legacy Excel'),
            subtitle: const Text('Migrate old data to new database'),
            onTap: () => _importLegacyData(context),
          ),
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
}
