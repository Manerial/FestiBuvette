import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_pay_app/l10n/app_localizations.dart';
import 'package:ludo_pay_app/features/products/data/models/product.dart';
import 'package:ludo_pay_app/features/products/providers/products_provider.dart';

/// Opens the add or edit product dialog.
/// [product] == null → Add mode, otherwise → Edit mode.
Future<void> showProductFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Product? product,
}) {
  return showDialog(
    context: context,
    builder: (_) => ProductFormDialog(product: product, ref: ref),
  );
}

class ProductFormDialog extends StatefulWidget {
  final Product? product;
  final WidgetRef ref;

  const ProductFormDialog({super.key, this.product, required this.ref});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  bool _loading = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _priceCtrl = TextEditingController(
      text: widget.product != null
          ? widget.product!.price.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  double? _parsePrice(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _nameCtrl.text.trim();
    final price = _parsePrice(_priceCtrl.text)!;
    try {
      if (_isEdit) {
        await widget.ref
            .read(productsProvider.notifier)
            .edit(widget.product!.copyWith(name: name, price: price));
      } else {
        await widget.ref.read(productsProvider.notifier).add(name, price);
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
      title: Text(_isEdit ? l10n.editProduct : l10n.newProduct),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.productNameLabel,
                hintText: l10n.productNameHint,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.nameRequired;
                if (v.trim().length > 50) return l10n.maximumCharacters(50);
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                labelText: l10n.priceLabel,
                hintText: l10n.priceHint,
                suffixText: '€',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l10n.priceRequired;
                final parsed = _parsePrice(v);
                if (parsed == null) return l10n.invalidPrice;
                if (parsed <= 0) return l10n.priceMustBePositive;
                return null;
              },
            ),
          ],
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
