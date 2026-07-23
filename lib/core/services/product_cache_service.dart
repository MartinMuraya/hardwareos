import 'package:cloud_functions/cloud_functions.dart';
import '../models/product.dart';
import 'offline_service.dart';

class ProductCacheService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Syncs products from Cloud Function and saves to Hive cache
  static Future<void> syncProducts(String businessId) async {
    try {
      final res = await _functions.httpsCallable('getProducts').call({
        'businessId': businessId,
        'limit': 1000, // Fetch up to 1000 products for offline caching
      });
      
      final data = res.data as Map;
      final productsList = List<Map<String, dynamic>>.from(data['products'] as List);
      
      await OfflineService.saveProducts(productsList);
    } catch (e) {
      // Failed to sync, we will rely on existing cache
      rethrow;
    }
  }

  /// Gets products from Hive cache
  static List<Product> getCachedProducts() {
    final rawList = OfflineService.loadProducts();
    return rawList.map((e) => Product.fromMap(e)).toList();
  }

  /// Checks if cache is stale (older than 15 minutes)
  static bool isCacheStale() {
    final lastSync = OfflineService.lastProductSyncAt;
    if (lastSync == null) return true;
    
    final difference = DateTime.now().difference(lastSync);
    return difference.inMinutes >= 15;
  }
}
