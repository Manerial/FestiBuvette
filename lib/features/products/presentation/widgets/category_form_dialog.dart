import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/features/products/data/models/category.dart';
import 'package:ludo_pay_app/features/products/providers/categories_provider.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';

/// Opens the add or edit category dialog.
/// [category] == null → Add mode, otherwise → Edit mode.
Future<void> showCategoryFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Category? category,
}) {
  return showDialog(
    context: context,
    builder: (_) => CategoryFormDialog(category: category, ref: ref),
  );
}

class CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final WidgetRef ref;

  const CategoryFormDialog({super.key, this.category, required this.ref});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _loading = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameCtrl.text.trim();
    try {
      if (_isEdit) {
        await widget.ref
            .read(categoriesProvider.notifier)
            .edit(widget.category!.copyWith(name: name));
      } else {
        await widget.ref.read(categoriesProvider.notifier).add(name);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(_isEdit ? l10n.editCategory : l10n.newCategory),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l10n.categoryNameLabel,
            hintText: l10n.categoryNameHint,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return l10n.nameRequired;
            if (v.trim().length > 30) return l10n.maximumCharacters(30);
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? l10n.save : l10n.add),
        ),
      ],
    );
  }
}
