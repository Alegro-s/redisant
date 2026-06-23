import 'package:client/features/ecosystem/lynx_cloud_marketplace.dart';
import 'package:client/features/ecosystem/lynx_marketplace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud marketplace paths', () {
    expect(LynxCloudMarketplace.catalogPath, '/v1/marketplace/catalog');
    expect(
      LynxCloudMarketplace.claimPath('lynx.3d'),
      '/v1/marketplace/items/lynx.3d/claim',
    );
    expect(
      LynxCloudMarketplace.downloadPath('pkg'),
      '/v1/marketplace/items/pkg/download',
    );
  });

  test('fetchCatalog falls back to bundled without server', () async {
    final cat = await LynxMarketplace.fetchCatalog('');
    expect(cat.items.isNotEmpty, isTrue);
  });
}
