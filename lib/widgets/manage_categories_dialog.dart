import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:lucide_icons/lucide_icons.dart';

import '../database.dart';

class ManageCategoriesDialog extends StatefulWidget {
  const ManageCategoriesDialog({super.key});

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> {
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(LucideIcons.folderCog),
          SizedBox(width: 8),
          Text('Manage Categories'),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant)
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                            labelText: 'New Category Name',
                            prefixIcon: Icon(LucideIcons.tag),
                            border: OutlineInputBorder()
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      // Dropdown to select parent
                      StreamBuilder<List<Category>>(
                        stream: categoryDao.watchMainCategories(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }
                          final mainCategories = snapshot.data ?? [];

                          return DropdownButtonFormField<int?>(
                            value: _selectedParentId,
                            decoration: const InputDecoration(
                              labelText: 'Parent Category (Optional)',
                              prefixIcon: Icon(LucideIcons.folderOpen),
                              border: OutlineInputBorder(),
                            ),
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('Add Category'),
                        onPressed: () => _addCategory(context, categoryDao),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
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
                    return Center(
                        child: Text('No categories yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                            )
                        )
                    );
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final mainCat = categories[index];
                      return Card(
                         margin: const EdgeInsets.only(bottom: 8),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                         child: ExpansionTile(
                          shape: InputBorder.none,
                          collapsedShape: InputBorder.none,
                          leading: Icon(LucideIcons.folder, color: theme.colorScheme.primary),
                          title: Row(
                            children: [
                              Expanded(
                                  child: Text(mainCat.category.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 18),
                                color: theme.colorScheme.error,
                                onPressed: () => _deleteCategory(
                                    context, categoryDao, mainCat.category.id),
                              ),
                            ],
                          ),
                          children: mainCat.subcategories.map((sub) {
                            return ListTile(
                              contentPadding: const EdgeInsets.only(
                                  left: 32.0, right: 16.0),
                              leading: const Icon(LucideIcons.cornerDownRight, size: 16),
                              title: Text(sub.name),
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 16),
                                color: theme.colorScheme.error.withValues(alpha: 0.7),
                                onPressed: () =>
                                    _deleteCategory(context, categoryDao, sub.id),
                              ),
                            );
                          }).toList(),
                        ),
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
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Added "$name"'), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: Category "$name" may already exist.'),
              backgroundColor: Theme.of(context).colorScheme.error
          ),
        );
      }
    }
  }

  void _deleteCategory(
      BuildContext context, CategoryDao categoryDao, int id) async {
    try {
      await categoryDao.deleteCategory(id);
    } catch (e) {
       if (!mounted) return;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
             content: const Text(
                 'Error: Cannot delete. Category may be in use by transactions.'),
              backgroundColor: Theme.of(context).colorScheme.error
         ),
       );
    }
  }
}
