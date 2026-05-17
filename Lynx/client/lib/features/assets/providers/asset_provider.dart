import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../models/asset.dart';
import '../../auth/providers/auth_provider.dart';

class AssetProvider extends ChangeNotifier {
  final AuthProvider _auth;
  List<Asset> _assets = [];

  List<Asset> get assets => _assets;

  AssetProvider(this._auth);

  Future<String?> uploadAsset(String projectId, File file, String assetName, String assetType, {Map<String, dynamic>? metadata}) async {
    try {
      String fileName = path.basename(file.path);
      String mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      FormData formData = FormData.fromMap({
        'name': assetName,
        'type': assetType,
        'metadata': metadata != null ? jsonEncode(metadata) : null,
        'file': await MultipartFile.fromFile(file.path, filename: fileName, contentType: DioMediaType.parse(mimeType)),
      });

      final response = await _auth.http.post('/projects/$projectId/assets', data: formData);
      if (response.statusCode == 200) {
        final asset = Asset.fromJson(response.data);
        _assets.add(asset);
        notifyListeners();
        return null;
      } else {
        return response.data['error'] ?? 'Upload failed';
      }
    } on DioException catch (e) {
      return e.response?.data['error'] ?? 'Network error';
    }
  }

  Future<String?> loadAssets(String projectId) async {
    try {
      final response = await _auth.http.get('/projects/$projectId/assets');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _assets = data.map((json) => Asset.fromJson(json)).toList();
        notifyListeners();
        return null;
      } else {
        return response.data['error'] ?? 'Failed to load assets';
      }
    } on DioException catch (e) {
      return e.response?.data['error'] ?? 'Network error';
    }
  }

  Future<Uint8List?> downloadAssetBytes(String assetId) async {
    try {
      final response = await _auth.http.get<List<int>>(
        '/assets/$assetId',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } on DioException catch (_) {}
    return null;
  }

  Future<String?> putAssetContent(
    String projectId,
    String assetId,
    Uint8List bytes,
  ) async {
    try {
      final response = await _auth.http.put<dynamic>(
        '/projects/$projectId/assets/$assetId/content',
        data: bytes,
        options: Options(contentType: 'application/octet-stream'),
      );
      if (response.statusCode == 200) return null;
      final err = response.data is Map ? (response.data as Map)['error']?.toString() : null;
      return err ?? 'Сохранение не удалось (${response.statusCode})';
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['error'] != null) return d['error'].toString();
      return e.message ?? 'Сеть';
    }
  }
}
