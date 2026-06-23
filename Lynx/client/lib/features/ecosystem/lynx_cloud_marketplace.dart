import 'dart:io';

import 'package:dio/dio.dart';

import 'lynx_marketplace.dart';

/// Маркетплейс Lynx Cloud API (волна 8): `/v1/marketplace/*`.
class LynxCloudMarketplace {
  LynxCloudMarketplace(this._dio);

  final Dio _dio;

  static const catalogPath = '/v1/marketplace/catalog';
  static String claimPath(String itemId) => '/v1/marketplace/items/$itemId/claim';
  static String downloadPath(String itemId) =>
      '/v1/marketplace/items/$itemId/download';

  Future<LynxMarketplaceCatalog> fetchCatalog() async {
    final r = await _dio.get<dynamic>(catalogPath);
    final data = r.data;
    if (data is Map<String, dynamic>) {
      return LynxMarketplaceCatalog.fromJson(data);
    }
    if (data is Map) {
      return LynxMarketplaceCatalog.fromJson(Map<String, dynamic>.from(data));
    }
    throw StateError('Invalid catalog response');
  }

  Future<ClaimResult> claimItem(String itemId) async {
    final r = await _dio.post<dynamic>(claimPath(itemId));
    final m = r.data is Map
        ? Map<String, dynamic>.from(r.data as Map)
        : <String, dynamic>{};
    return ClaimResult(
      ok: m['ok'] as bool? ?? false,
      message: m['message'] as String? ?? '',
      downloadPath: m['downloadPath'] as String?,
    );
  }

  Future<void> downloadPackage(String itemId, String destFile) async {
    final r = await _dio.get<List<int>>(
      downloadPath(itemId),
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = r.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Empty package');
    }
    await File(destFile).writeAsBytes(bytes);
  }
}

class ClaimResult {
  const ClaimResult({
    required this.ok,
    required this.message,
    this.downloadPath,
  });
  final bool ok;
  final String message;
  final String? downloadPath;
}
