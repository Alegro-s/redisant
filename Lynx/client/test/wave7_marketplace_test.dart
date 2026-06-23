import 'package:client/features/ecosystem/lynx_marketplace.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  test('bundled catalog loads with lynx.3d plugin', () async {
    final cat = await LynxMarketplace.fetchCatalog('');
    expect(cat.apiVersion, 1);
    expect(
      cat.items.any((i) => i.id == 'lynx.3d' && i.kind == 'plugin'),
      isTrue,
    );
  });

  test('marketplace item roundtrip json', () {
    final item = LynxMarketplaceItem(
      id: 'test',
      kind: 'plugin',
      title: 'Test',
      category: 'plugins',
      builtin: true,
    );
    final back = LynxMarketplaceItem.fromJson(item.toJson());
    expect(back.id, 'test');
    expect(back.kind, 'plugin');
  });
}
