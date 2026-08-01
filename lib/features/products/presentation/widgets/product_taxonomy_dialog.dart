import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/localization_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/product_repository.dart';

/// Manage master lists for product brands (النوع) and categories (الصنف).
class ProductTaxonomyDialog extends StatefulWidget {
  const ProductTaxonomyDialog({super.key});

  @override
  State<ProductTaxonomyDialog> createState() => _ProductTaxonomyDialogState();
}

class _ProductTaxonomyDialogState extends State<ProductTaxonomyDialog> {
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _repo = di.sl<ProductRepository>();

  List<String> _brands = [];
  List<String> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final brands = await _repo.getBrands();
    final categories = await _repo.getCategories();
    if (!mounted) return;
    setState(() {
      _brands = brands;
      _categories = categories;
      _loading = false;
    });
  }

  Future<void> _addBrand() async {
    final name = _brandController.text.trim();
    if (name.isEmpty) return;
    await _repo.addBrand(name);
    _brandController.clear();
    await _reload();
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;
    await _repo.addCategory(name);
    _categoryController.clear();
    await _reload();
  }

  Future<void> _deleteBrand(String name) async {
    await _repo.deleteBrand(name);
    await _reload();
  }

  Future<void> _deleteCategory(String name) async {
    await _repo.deleteCategory(name);
    await _reload();
  }

  Widget _buildColumn({
    required String title,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required List<String> items,
    required VoidCallback onAdd,
    required void Function(String) onDelete,
  }) {
    final l10n = LocalizationService();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(l10n.get('add')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        l10n.get('noItemsYet'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          dense: true,
                          title: Text(item),
                          trailing: IconButton(
                            tooltip: l10n.get('delete'),
                            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            onPressed: () => onDelete(item),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LocalizationService();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          minHeight: 420,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.category_outlined, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.get('manageBrandsCategories'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildColumn(
                            title: l10n.get('brand'),
                            hint: l10n.get('brandHint'),
                            icon: Icons.sell_outlined,
                            controller: _brandController,
                            items: _brands,
                            onAdd: _addBrand,
                            onDelete: _deleteBrand,
                          ),
                          const SizedBox(width: 20),
                          _buildColumn(
                            title: l10n.get('productCategory'),
                            hint: l10n.get('productCategoryHint'),
                            icon: Icons.category_outlined,
                            controller: _categoryController,
                            items: _categories,
                            onAdd: _addCategory,
                            onDelete: _deleteCategory,
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.get('close')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
