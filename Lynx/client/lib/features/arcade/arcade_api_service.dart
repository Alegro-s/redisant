import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../arcade/arcade_catalog_service.dart';
import '../engine/runtime/lynx_cart_io.dart';

/// Cloud Arcade API (lynx-server /v1/arcade).
class ArcadeApiService {
  ArcadeApiService(this.dio, {this.baseUrl});

  final Dio dio;
  final String? baseUrl;

  String get _root {
    final b = baseUrl?.trim();
    if (b != null && b.isNotEmpty) return b.replaceAll(RegExp(r'/+$'), '');
    return dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
  }

  String arcadeUrl(String path) => '$_root/v1/arcade$path';

  Future<List<ArcadeGameEntry>> fetchCatalog() async {
    final res = await dio.get<Map<String, dynamic>>(arcadeUrl('/catalog'));
    final data = res.data;
    if (data == null) return const [];
    final items = data['items'] as List? ?? const [];
    return items
        .map((e) => ArcadeGameEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((g) => g.tier == 'free_to_play' || g.tags.contains('arcade'))
        .toList();
  }

  Future<ArcadeGameEntry?> fetchCartMeta(String cartId) async {
    final res = await dio.get<Map<String, dynamic>>(arcadeUrl('/carts/$cartId'));
    final data = res.data;
    if (data == null) return null;
    return ArcadeGameEntry.fromJson(data);
  }

  String downloadUrl(String cartId) => arcadeUrl('/carts/$cartId/download');

  Future<UploadCartResult> uploadCart({
    required String cartFilePath,
    required LynxCartManifest manifest,
    String? cartId,
  }) async {
    final file = await MultipartFile.fromFile(
      cartFilePath,
      filename: '${manifest.cartId ?? cartId ?? 'game'}$kLynxCartExtension',
    );
    final form = FormData.fromMap({
      'cart': file,
      'title': manifest.title,
      'tier': manifest.tier,
      'tags': manifest.tags.join(','),
      if (cartId != null) 'cartId': cartId,
    });
    final res = await dio.post<Map<String, dynamic>>(
      arcadeUrl('/carts'),
      data: form,
    );
    final data = res.data ?? const {};
    return UploadCartResult(
      ok: data['ok'] == true,
      id: data['id'] as String? ?? '',
      cartUrl: data['cartUrl'] as String? ?? '',
      message: data['message'] as String? ?? '',
    );
  }

  Future<UploadCartResult> uploadCartBytes({
    required List<int> bytes,
    required LynxCartManifest manifest,
    String? cartId,
    String filename = 'game.lynxcart',
  }) async {
    final form = FormData.fromMap({
      'cart': MultipartFile.fromBytes(bytes, filename: filename),
      'title': manifest.title,
      'tier': manifest.tier,
      'tags': manifest.tags.join(','),
      if (cartId != null) 'cartId': cartId,
    });
    final res = await dio.post<Map<String, dynamic>>(
      arcadeUrl('/carts'),
      data: form,
    );
    final data = res.data ?? const {};
    return UploadCartResult(
      ok: data['ok'] == true,
      id: data['id'] as String? ?? '',
      cartUrl: data['cartUrl'] as String? ?? '',
      message: data['message'] as String? ?? '',
    );
  }
}

class UploadCartResult {
  const UploadCartResult({
    required this.ok,
    required this.id,
    required this.cartUrl,
    required this.message,
  });
  final bool ok;
  final String id;
  final String cartUrl;
  final String message;
}

String resolveArcadeCartAbsoluteUrl(Dio dio, String cartUrl) {
  if (cartUrl.startsWith('http://') || cartUrl.startsWith('https://')) {
    return cartUrl;
  }
  final base = dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
  final path = cartUrl.startsWith('/') ? cartUrl : '/$cartUrl';
  return '$base$path';
}
