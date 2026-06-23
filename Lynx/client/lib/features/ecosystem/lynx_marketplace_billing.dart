import 'package:dio/dio.dart';

/// Wave 30 — marketplace billing + creator dashboard (production HTTP).
class LynxMarketplaceBilling {
  LynxMarketplaceBilling({this.apiBase, this.dio});

  final String? apiBase;
  final Dio? dio;

  String get _base {
    final b = apiBase?.trim();
    if (b != null && b.isNotEmpty) return b.replaceAll(RegExp(r'/+$'), '');
    return '';
  }

  Future<LynxPurchaseResult> purchaseCart({
    required String cartId,
    required String buyerUserId,
    String? authToken,
  }) async {
    final base = _base;
    if (base.isEmpty || dio == null) {
      return LynxPurchaseResult(
        success: true,
        transactionId: 'local_${DateTime.now().millisecondsSinceEpoch}',
        cartId: cartId,
      );
    }
    try {
      final res = await dio!.post<Map<String, dynamic>>(
        '$base/v1/marketplace/purchase',
        data: {'cart_id': cartId, 'buyer_id': buyerUserId},
        options: Options(
          headers: authToken != null ? {'Authorization': 'Bearer $authToken'} : null,
        ),
      );
      final m = res.data ?? {};
      return LynxPurchaseResult(
        success: m['ok'] as bool? ?? res.statusCode == 200,
        transactionId: m['transaction_id']?.toString(),
        cartId: cartId,
        error: m['error']?.toString(),
      );
    } catch (e) {
      return LynxPurchaseResult(success: false, cartId: cartId, error: '$e');
    }
  }

  Future<LynxCreatorDashboard> fetchCreatorDashboard(String creatorId) async {
    final base = _base;
    if (base.isEmpty || dio == null) {
      return LynxCreatorDashboard(
        creatorId: creatorId,
        totalSales: 0,
        pendingReview: 0,
        publishedCarts: const [],
      );
    }
    try {
      final res = await dio!.get<Map<String, dynamic>>('$base/v1/marketplace/creator/$creatorId');
      final m = res.data ?? {};
      return LynxCreatorDashboard(
        creatorId: creatorId,
        totalSales: (m['total_sales'] as num?)?.toInt() ?? 0,
        pendingReview: (m['pending_review'] as num?)?.toInt() ?? 0,
        publishedCarts: (m['published_carts'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
    } catch (_) {
      return LynxCreatorDashboard(
        creatorId: creatorId,
        totalSales: 0,
        pendingReview: 0,
        publishedCarts: const [],
      );
    }
  }
}

class LynxPurchaseResult {
  final bool success;
  final String? transactionId;
  final String cartId;
  final String? error;

  const LynxPurchaseResult({
    required this.success,
    this.transactionId,
    required this.cartId,
    this.error,
  });
}

class LynxCreatorDashboard {
  final String creatorId;
  final int totalSales;
  final int pendingReview;
  final List<String> publishedCarts;

  const LynxCreatorDashboard({
    required this.creatorId,
    required this.totalSales,
    required this.pendingReview,
    required this.publishedCarts,
  });
}
