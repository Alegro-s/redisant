import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

import 'lynx_cart_io.dart';

/// Виртуальное хранилище cart на Web (распаковка ZIP в память).
class LynxCartWebStore {
  LynxCartWebStore._(this.manifest, this._files);

  final LynxCartManifest manifest;
  final Map<String, Uint8List> _files;

  static Future<LynxCartWebStore> fromBytes(List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final files = <String, Uint8List>{};
    LynxCartManifest? manifest;
    for (final f in archive) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      final content = Uint8List.fromList(f.content as List<int>);
      files[name] = content;
      if (name == 'cart.json') {
        manifest = LynxCartManifest.fromJson(
          jsonDecode(utf8.decode(content)) as Map<String, dynamic>,
        );
      }
    }
    manifest ??= LynxCartManifest(title: 'Cart');
    return LynxCartWebStore._(manifest, files);
  }

  static Future<LynxCartWebStore> download(Dio dio, String url) async {
    final res = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Пустой ответ cart');
    }
    return fromBytes(bytes);
  }

  String? readText(String rel) {
    final key = rel.replaceAll('\\', '/');
    final bytes = _files[key] ?? _files['$key/'];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }

  List<String> listPaths() => _files.keys.toList();
}

const String kLynxCartWebPrefix = 'lynx_cart_web:';

bool isLynxCartWebPath(String? path) =>
    path != null && path.startsWith(kLynxCartWebPrefix);

String cartIdFromWebPath(String path) => path.substring(kLynxCartWebPrefix.length);

String lynxCartWebPath(String cartId) => '$kLynxCartWebPrefix$cartId';

/// Глобальный кэш cart stores для web play session.
final Map<String, LynxCartWebStore> lynxCartWebSessionCache = {};
