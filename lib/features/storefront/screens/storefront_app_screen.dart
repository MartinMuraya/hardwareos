import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/storefront_provider.dart';
import 'storefront_catalog_view.dart';
import 'storefront_cart_view.dart';

class StorefrontAppScreen extends StatefulWidget {
  final String tenantSlug;
  const StorefrontAppScreen({required this.tenantSlug, super.key});

  @override
  State<StorefrontAppScreen> createState() => _StorefrontAppScreenState();
}

class _StorefrontAppScreenState extends State<StorefrontAppScreen> {
  late StorefrontProvider _provider;
  int _currentIndex = 0; // 0 = Catalog, 1 = Cart

  @override
  void initState() {
    super.initState();
    _provider = StorefrontProvider(tenantSlug: widget.tenantSlug);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _goToCatalog() => setState(() => _currentIndex = 0);
  void _goToCart() => setState(() => _currentIndex = 1);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<StorefrontProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (provider.error != null || provider.storeInfo == null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Storefront not found or inactive.', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(provider.error ?? '', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              elevation: 1,
              title: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _goToCatalog,
                  child: Row(
                    children: [
                      const Icon(Icons.storefront, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(provider.storeInfo!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              centerTitle: false,
              actions: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      onPressed: _goToCart,
                    ),
                    if (provider.cartItemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${provider.cartItemCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _currentIndex == 0
                  ? StorefrontCatalogView(onViewCart: _goToCart, key: const ValueKey('catalog'))
                  : StorefrontCartView(onContinueShopping: _goToCatalog, key: const ValueKey('cart')),
            ),
          );
        },
      ),
    );
  }
}
