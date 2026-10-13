// lib/services/storekit_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class StoreKitService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  /// Initialize StoreKit (only on iOS).
  static Future<void> init() async {
    if (!Platform.isIOS) return;
    final bool available = await _iap.isAvailable();
    if (!available) {
      debugPrint('❌ StoreKit not available');
      return;
    }
    _iap.purchaseStream.listen(_listenToPurchases, onError: (e) {
      debugPrint('❌ Purchase stream error: $e');
    });
  }

  static void dispose() {
    // No explicit dispose needed for InAppPurchase, kept for symmetry.
  }

  /// Trigger purchase for a given productId.
  static Future<void> buyProduct(String productId) async {
    if (!Platform.isIOS) return;
    final ProductDetailsResponse response =
        await _iap.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('❌ Product $productId not found');
      return;
    }
    final ProductDetails product = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  static void _listenToPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _iap.completePurchase(purchase);
        debugPrint('✅ Purchase completed: ${purchase.productID}');
        // TODO: Notify backend / unlock content.
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase error: ${purchase.error?.message}');
      }
    }
  }
}
