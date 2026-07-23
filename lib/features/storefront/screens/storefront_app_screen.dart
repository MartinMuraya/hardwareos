import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
                    const Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text('Storefront not found or inactive.', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(provider.error ?? '', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          }

          Color? brandColor;
          if (provider.storeInfo?.primaryColor != null && provider.storeInfo!.primaryColor!.length >= 7) {
            try {
              final hex = provider.storeInfo!.primaryColor!.substring(1, 7);
              brandColor = Color(int.parse(hex, radix: 16) + 0xFF000000);
            } catch (_) {}
          }

          final Color appBarColor = brandColor ?? Colors.white;
          final Color iconColor = brandColor != null ? Colors.white : Colors.black87;
          final Color textColor = brandColor != null ? Colors.white : Colors.black87;

          return Theme(
            data: Theme.of(context).copyWith(
              primaryColor: brandColor ?? Colors.blue,
              colorScheme: ColorScheme.fromSeed(seedColor: brandColor ?? Colors.blue),
            ),
            child: Scaffold(
              appBar: AppBar(
                elevation: 1,
                backgroundColor: appBarColor,
                title: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: _goToCatalog,
                    child: Row(
                      children: [
                        if (provider.storeInfo?.logoUrl != null && provider.storeInfo!.logoUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Image.network(
                              provider.storeInfo!.logoUrl!,
                              height: 40,
                              errorBuilder: (_, __, ___) => Icon(Icons.storefront, color: iconColor),
                            ),
                          )
                        else
                          Icon(Icons.storefront, color: iconColor),
                        
                        const SizedBox(width: 8),
                        Text(provider.storeInfo!.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
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
                        icon: Icon(Icons.shopping_cart_outlined, color: iconColor),
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
              body: Column(
                children: [
                  if (_currentIndex == 0 && provider.storeInfo?.bannerUrl != null && provider.storeInfo!.bannerUrl!.isNotEmpty)
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(provider.storeInfo!.bannerUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentIndex == 0
                          ? StorefrontCatalogView(onViewCart: _goToCart, key: const ValueKey('catalog'))
                          : StorefrontCartView(onContinueShopping: _goToCatalog, key: const ValueKey('cart')),
                    ),
                  ),
                ],
              ),
              floatingActionButton: (provider.storeInfo?.whatsappNumber != null && provider.storeInfo!.whatsappNumber!.isNotEmpty)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      final url = Uri.parse('https://wa.me/${provider.storeInfo!.whatsappNumber}');
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text('WhatsApp Us', style: TextStyle(color: Colors.white)),
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                  )
                : null,
            ),
          );
        },
      ),
    );
  }
}
