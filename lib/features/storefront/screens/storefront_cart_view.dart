import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/storefront_provider.dart';

class StorefrontCartView extends StatefulWidget {
  final VoidCallback onContinueShopping;
  const StorefrontCartView({required this.onContinueShopping, super.key});

  @override
  State<StorefrontCartView> createState() => _StorefrontCartViewState();
}

class _StorefrontCartViewState extends State<StorefrontCartView> {
  final _formKey = GlobalKey<FormState>();
  String _customerName = '';
  String _customerPhone = '';
  String _address = '';
  String _note = '';

  bool _isCheckingOut = false;

  Future<void> _handleCheckout(StorefrontProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isCheckingOut = true);
    try {
      await provider.checkout(
        customerName: _customerName,
        customerPhone: _customerPhone,
        address: _address,
        note: _note,
      );
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Order Placed'),
              ],
            ),
            content: const Text('Your order has been queued/placed successfully. The merchant will contact you soon.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onContinueShopping();
                },
                child: const Text('Back to Store'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StorefrontProvider>();

    if (provider.cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Your cart is empty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onContinueShopping,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Continue Shopping'),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final cartList = ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.cart.length,
      itemBuilder: (context, index) {
        final item = provider.cart[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: item.product.images.isNotEmpty
                ? Image.network(item.product.images.first, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image))
                : const Icon(Icons.inventory_2, size: 50),
            title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('\$${item.product.sellingPrice.toStringAsFixed(2)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => provider.updateQuantity(item.product.id, item.quantity - 1),
                ),
                Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: item.product.inStock ? () => provider.updateQuantity(item.product.id, item.quantity + 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => provider.removeFromCart(item.product.id),
                ),
              ],
            ),
          ),
        );
      },
    );

    final checkoutForm = Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: !isDesktop,
          children: [
            Text('Order Summary', style: Theme.of(context).textTheme.headlineSmall),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Items:', style: TextStyle(fontSize: 16)),
                Text('${provider.cartItemCount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                Text('\$${provider.cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            if (provider.selectedZone != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery Fee:', style: TextStyle(fontSize: 16)),
                  Text('\$${provider.selectedZone!.fee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Price:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('\$${provider.cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const Divider(height: 32),
            
            Text('Checkout Details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            TextFormField(
              decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              onSaved: (val) => _customerName = val!,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'M-Pesa Phone Number *', 
                border: OutlineInputBorder(),
                helperText: 'Must be an active M-Pesa number (e.g. 254700000000)'
              ),
              keyboardType: TextInputType.phone,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              onSaved: (val) => _customerPhone = val!,
            ),
            const SizedBox(height: 16),
            
            if (provider.storeInfo?.deliveryZones.isNotEmpty == true)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Delivery Zone *', border: OutlineInputBorder()),
                initialValue: provider.selectedZone?.id,
                items: provider.storeInfo!.deliveryZones.map((z) => DropdownMenuItem(
                  value: z.id,
                  child: Text('${z.name} (+\$${z.fee.toStringAsFixed(2)})'),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final zone = provider.storeInfo!.deliveryZones.firstWhere((z) => z.id == val);
                    provider.setDeliveryZone(zone);
                  }
                },
                validator: (val) => val == null ? 'Please select a delivery zone' : null,
              ),
            const SizedBox(height: 16),

            TextFormField(
              decoration: const InputDecoration(labelText: 'Delivery Address *', border: OutlineInputBorder()),
              maxLines: 3,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              onSaved: (val) => _address = val!,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              decoration: const InputDecoration(labelText: 'Order Notes (Optional)', border: OutlineInputBorder()),
              maxLines: 2,
              onSaved: (val) => _note = val ?? '',
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: _isCheckingOut ? null : () => _handleCheckout(provider),
                child: _isCheckingOut
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay with M-Pesa & Place Order', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: cartList),
          Expanded(flex: 1, child: checkoutForm),
        ],
      );
    } else {
      return Column(
        children: [
          Expanded(child: cartList),
          checkoutForm,
        ],
      );
    }
  }
}
