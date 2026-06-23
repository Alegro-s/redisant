import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../arcade/arcade_api_service.dart';
import '../arcade/arcade_local_resolver.dart';
import '../auth/providers/auth_provider.dart';
import '../engine/runtime/lynx_cart_io.dart';
import '../engine/runtime/lynx_cart_web_store.dart';
import 'game_player_screen.dart';

/// Play-only режим для `.lynxcart` (Web + native).
class CartPlayScreen extends StatefulWidget {
  const CartPlayScreen({
    super.key,
    this.cartPath,
    this.cartId,
  });

  final String? cartPath;
  final String? cartId;

  @override
  State<CartPlayScreen> createState() => _CartPlayScreenState();
}

class _CartPlayScreenState extends State<CartPlayScreen> {
  String? _playPath;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final cartId = widget.cartId?.trim() ?? '';
    try {
      if (kIsWeb) {
        if (cartId.isEmpty) throw StateError('Не указан cartId');
        final auth = context.read<AuthProvider>();
        final api = ArcadeApiService(auth.http);
        var url = api.downloadUrl(cartId);
        try {
          final meta = await api.fetchCartMeta(cartId);
          if (meta?.cartUrl != null && meta!.cartUrl!.isNotEmpty) {
            url = meta.cartUrl!;
          }
        } catch (_) {}
        final abs = resolveArcadeCartAbsoluteUrl(auth.http, url);
        final store = await LynxCartWebStore.download(auth.http, abs);
        lynxCartWebSessionCache[cartId] = store;
        if (!mounted) return;
        setState(() {
          _playPath = lynxCartWebPath(cartId);
          _loading = false;
        });
        return;
      }

      final localPath = widget.cartPath?.trim() ?? '';
      if (localPath.isNotEmpty) {
        final dest = await extractLynxCartToDirectory(
          cartFilePath: localPath,
          destDirectory:
              '${Directory.systemTemp.path}${Platform.pathSeparator}lynx_cart_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (!mounted) return;
        setState(() {
          _playPath = dest;
          _loading = false;
        });
        return;
      }

      if (cartId.isNotEmpty) {
        final auth = context.read<AuthProvider>();
        final api = ArcadeApiService(auth.http);
        try {
          final abs = resolveArcadeCartAbsoluteUrl(auth.http, api.downloadUrl(cartId));
          final res = await auth.http.get<List<int>>(
            abs,
            options: Options(responseType: ResponseType.bytes),
          );
          final bytes = res.data;
          if (bytes == null || bytes.isEmpty) throw StateError('Пустой cart');
          final tmp = await Directory.systemTemp.createTemp('lynx_cart_dl_');
          final out = '${tmp.path}${Platform.pathSeparator}$cartId.lynxcart';
          await File(out).writeAsBytes(bytes);
          final dest = await extractLynxCartToDirectory(cartFilePath: out, destDirectory: tmp.path);
          if (!mounted) return;
          setState(() {
            _playPath = dest;
            _loading = false;
          });
          return;
        } on DioException catch (e) {
          if (e.response?.statusCode != 404 && e.response?.statusCode != 429) rethrow;
        }
        final bundledCart = await ArcadeLocalResolver.resolveBundledCartFile(cartId);
        if (bundledCart != null) {
          final tmp = await Directory.systemTemp.createTemp('lynx_cart_local_');
          final dest = await extractLynxCartToDirectory(
            cartFilePath: bundledCart,
            destDirectory: tmp.path,
          );
          if (!mounted) return;
          setState(() {
            _playPath = dest;
            _loading = false;
          });
          return;
        }
        final tpl = ArcadeLocalResolver.templateIdForCart(cartId);
        final templateRoot = tpl != null
            ? await ArcadeLocalResolver.resolveBundledTemplateProject(tpl)
            : null;
        if (templateRoot != null) {
          if (!mounted) return;
          setState(() {
            _playPath = templateRoot;
            _loading = false;
          });
          return;
        }
        throw StateError(
          'Игра не найдена на сервере. Опубликуйте .lynxcart в Hub → Админ → Аркада '
          'или установите MSI с встроенными демо.',
        );
      }

      throw StateError('Cart не указан');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lynx Cart')),
        body: Center(child: Text(_error!)),
      );
    }
    return GamePlayerScreen(projectPath: _playPath, freshPlay: true, forcePixelPerfect: true);
  }
}
