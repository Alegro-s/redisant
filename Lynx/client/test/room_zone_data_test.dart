import 'package:client/features/engine/models/engine_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RoomZoneData.fromJson accepts scene-style keys', () {
    final m = <String, dynamic>{
      'id': 'zone_a',
      'x': 10.0,
      'y': 20.0,
      'w': 800.0,
      'h': 600.0,
      'cameraMinX': 0.0,
      'cameraMinY': 0.0,
      'cameraMaxX': 800.0,
      'cameraMaxY': 600.0,
    };
    final r = RoomZoneData.fromJson(m);
    expect(r.id, 'zone_a');
    expect(r.w, 800);
    expect(r.cameraMaxX, 800);
  });

  test('RoomZoneData.fromJson accepts snake_case from engine JSON', () {
    final m = <String, dynamic>{
      'id': 'r',
      'x': 0,
      'y': 0,
      'w': 100,
      'h': 50,
      'camera_min_x': 5,
      'camera_min_y': 6,
      'camera_max_x': 95,
      'camera_max_y': 44,
    };
    final r = RoomZoneData.fromJson(m);
    expect(r.cameraMinX, 5);
    expect(r.cameraMaxY, 44);
  });

  test('RoomZoneData.copyWith', () {
    const a = RoomZoneData(id: 'a', x: 1, y: 2, w: 3, h: 4);
    final b = a.copyWith(w: 99.0, cameraMaxX: 10);
    expect(b.w, 99);
    expect(b.x, 1);
    expect(b.cameraMaxX, 10);
    expect(b.cameraMaxY, 0);
  });
}
