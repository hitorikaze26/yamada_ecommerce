import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/products_api.dart';
import '../../../data/services/seller_products_api.dart';

class SellerEditProductPage extends ConsumerStatefulWidget {
  final String productId;

  const SellerEditProductPage({super.key, required this.productId});

  @override
  ConsumerState<SellerEditProductPage> createState() =>
      _SellerEditProductPageState();
}

class _SellerEditProductPageState extends ConsumerState<SellerEditProductPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _variations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final product = await ProductsApi.getProductById(widget.productId);
      _nameCtrl.text = product.name;
      _descCtrl.text = product.description;
      _priceCtrl.text = product.price.toStringAsFixed(0);
      _qtyCtrl.text = '${product.totalStock}';
      _variations = product.variations
          .map(
            (v) => {
              'size': v.size,
              'colors': v.color.isNotEmpty ? [v.color] : [],
              'stock': v.inventory,
              'sku': v.sku,
            },
          )
          .toList();
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Failed to load product: $e',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
      await SellerProductsApi.updateProduct(
        productId: int.parse(widget.productId),
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: price,
        quantity: qty,
        variations: _variations,
      );
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Product updated',
          variant: AlertVariant.success,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AlertService.showSnackBar(
          context: context,
          message: 'Update failed: $e',
          variant: AlertVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addVariation() {
    setState(() {
      _variations.add({'size': '', 'colors': [], 'stock': 0, 'sku': ''});
    });
  }

  InputDecoration _fieldDecoration(String label, bool isDark) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: isDark ? AppColors.darkBackground : AppColors.offWhite,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.rosewood, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: isDark ? AppColors.darkMutedForeground : AppColors.mutedForeground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit product',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _SectionHeader(
                  icon: Icons.inventory_2_outlined,
                  title: 'Product details',
                  subtitle: 'Name, description, and pricing',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        decoration: _fieldDecoration('Product name', isDark),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 5,
                        decoration: _fieldDecoration('Description', isDark),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration('Price (₱)', isDark),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _qtyCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration(
                          'Total stock (all variants)',
                          isDark,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _SectionHeader(
                        icon: Icons.style_outlined,
                        title: 'Variants',
                        subtitle: 'Size, color, and stock per option',
                        isDark: isDark,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _addVariation,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosewood.withValues(alpha: 0.12),
                        foregroundColor: AppColors.rosewood,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_variations.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'No variants yet. Add at least one size/color combination.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.darkMutedForeground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  )
                else
                  ...List.generate(_variations.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _VariationEditorCard(
                        key: ValueKey('var-$i-${_variations[i]['sku']}'),
                        index: i,
                        data: _variations[i],
                        isDark: isDark,
                        cardColor: cardColor,
                        borderColor: borderColor,
                        fieldDecoration: _fieldDecoration,
                        onChanged: (updated) {
                          setState(() => _variations[i] = updated);
                        },
                        onDelete: () {
                          setState(() => _variations.removeAt(i));
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosewood,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.rosewood.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.rosewood),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkMutedForeground
                      : AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VariationEditorCard extends StatefulWidget {
  final int index;
  final Map<String, dynamic> data;
  final bool isDark;
  final Color cardColor;
  final Color borderColor;
  final InputDecoration Function(String, bool) fieldDecoration;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;

  const _VariationEditorCard({
    super.key,
    required this.index,
    required this.data,
    required this.isDark,
    required this.cardColor,
    required this.borderColor,
    required this.fieldDecoration,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_VariationEditorCard> createState() => _VariationEditorCardState();
}

class _VariationEditorCardState extends State<_VariationEditorCard> {
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    _sizeCtrl = TextEditingController(text: widget.data['size']?.toString() ?? '');
    _colorCtrl = TextEditingController(
      text: (widget.data['colors'] as List?)?.join(', ') ?? '',
    );
    _stockCtrl = TextEditingController(text: '${widget.data['stock'] ?? 0}');
  }

  @override
  void dispose() {
    _sizeCtrl.dispose();
    _colorCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged({
      'size': _sizeCtrl.text.trim(),
      'colors': _colorCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
      'sku': widget.data['sku'] ?? '',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant ${widget.index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : AppColors.charcoal,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: AppColors.destructive),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          TextField(
            controller: _sizeCtrl,
            decoration: widget.fieldDecoration('Size', widget.isDark),
            onChanged: (_) => _emit(),
            style: TextStyle(
              color: widget.isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _colorCtrl,
            decoration: widget.fieldDecoration('Color (comma-separated)', widget.isDark),
            onChanged: (_) => _emit(),
            style: TextStyle(
              color: widget.isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _stockCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: widget.fieldDecoration('Stock', widget.isDark),
            onChanged: (_) => _emit(),
            style: TextStyle(
              color: widget.isDark ? Colors.white : AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
