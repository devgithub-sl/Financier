import 'package:flutter/material.dart';
import '../database.dart';
import 'transaction_form.dart';

class TransactionDialog extends StatelessWidget {
  final TransactionWithCategoryAndParent? transactionToEdit;

  const TransactionDialog({
    super.key,
    this.transactionToEdit,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: TransactionForm(
            transactionToEdit: transactionToEdit,
            onSaved: () {
               if (context.mounted) {
                 Navigator.of(context).pop();
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(
                     content: Text('Transaction saved'),
                     behavior: SnackBarBehavior.floating,
                   ),
                 );
               }
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
