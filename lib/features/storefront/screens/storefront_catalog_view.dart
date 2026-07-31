import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/storefront_provider.dart';

class StorefrontCatalogView extends StatefulWidget {
  final VoidCallback onViewCart;
  const StorefrontCatalogView({required this.onViewCart, super.key});

  @override
  State<StorefrontCatalogView> createState() => _StorefrontCatalogViewState();
}

class _StorefrontCatalogViewState extends State<StorefrontCatalogView> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorefrontProvider>();
    final products = provider.products
        .where((p) =>
            _selectedCategory == 'All' || p.category == _selectedCategory)
        .toList();

    return Column(
      children: [
        // Category Filter
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: provider.categories.length,
            itemBuilder: (context, index) {
              final cat = provider.categories[index];
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),

        // Product Grid
        Expanded(
          child: products.isEmpty
              ? const Center(child: Text('No products found in this category.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final p = products[index];
                    return Card(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: p.images.isNotEmpty
                                ? Image.network(p.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey))
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.inventory_2,
                                        size: 50, color: Colors.grey),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Text('\$${p.sellingPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                    onPressed: p.inStock
                                        ? () {
                                            provider.addToCart(p);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${p.name} added to cart'),
                                                duration:
                                                    const Duration(seconds: 1),
                                                action: SnackBarAction(
                                                  label: 'VIEW CART',
                                                  onPressed: widget.onViewCart,
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: const Icon(Icons.add_shopping_cart,
                                        size: 18),
                                    label: Text(
                                        p.inStock ? 'Add' : 'Out of Stock'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
