import 'package:flutter/foundation.dart';

import 'lynx3d_physics.dart';
import 'lynx_3d_codec.dart';

/// Shared Play tick: physics + animation time (Canvas + Core D3D12).
class Lynx3dPlayRuntime {
  Lynx3dPlayRuntime({
    required Lynx3dSceneExtension extension,
    required bool simulatePhysics,
  })  : _base = extension,
        _bodies = extension.objects.map(Lynx3dRuntimeBody.new).toList(),
        _animTime = {
          for (final o in extension.objects)
            if (o.animationClip != null) o.id: o.animationTime,
        } {
    _useCorePhysics = simulatePhysics &&
        !kIsWeb &&
        Lynx3dPhysicsController.isAvailable;
    if (_useCorePhysics) {
      _physics = Lynx3dPhysicsController()..loadExtension(extension);
    }
  }

  final Lynx3dSceneExtension _base;
  final List<Lynx3dRuntimeBody> _bodies;
  final Map<String, double> _animTime;
  Lynx3dPhysicsController? _physics;
  bool _useCorePhysics = false;
  double _elapsed = 0;

  void dispose() {
    _physics?.dispose();
  }

  Lynx3dSceneExtension tick(double dt, {bool advanceAnimation = true}) {
    if (_useCorePhysics && _physics != null && _physics!.step(dt)) {
      _physics!.syncPositions(_bodies);
    } else if (!kIsWeb) {
      _integrateSimple(dt);
    }
    if (advanceAnimation) {
      _elapsed += dt;
      for (final b in _bodies) {
        final clip = b.spec.animationClip;
        if (clip == null) continue;
        _animTime[b.spec.id] = (_animTime[b.spec.id] ?? 0) + dt;
      }
    }
    return _buildExtension();
  }

  void _integrateSimple(double dt) {
    final g = _base.gravity;
    final floorY = _base.room != null
        ? _base.room!.center[1] - _base.room!.height * 0.5
        : 0.0;
    for (final b in _bodies) {
      if (b.spec.physics.isStatic) continue;
      b.velocity[0] += g[0] * dt;
      b.velocity[1] += g[1] * dt;
      b.velocity[2] += g[2] * dt;
      b.position[0] += b.velocity[0] * dt;
      b.position[1] += b.velocity[1] * dt;
      b.position[2] += b.velocity[2] * dt;
      final bottom = b.position[1] - b.spec.halfExtents[1];
      if (bottom < floorY) {
        b.position[1] = floorY + b.spec.halfExtents[1];
        b.velocity[1] = 0;
        b.velocity[0] *= 0.92;
        b.velocity[2] *= 0.92;
      }
    }
  }

  Lynx3dSceneExtension _buildExtension() {
    final objs = _bodies
        .map(
          (b) => Lynx3dObjectSpec(
            id: b.spec.id,
            mesh: b.spec.mesh,
            position: List<double>.from(b.position),
            rotationEuler: b.spec.rotationEuler,
            scale: b.spec.scale,
            halfExtents: b.spec.halfExtents,
            colorArgb: b.spec.colorArgb,
            material: b.spec.material,
            animationClip: b.spec.animationClip,
            animationTime: _animTime[b.spec.id] ?? b.spec.animationTime,
            physics: b.spec.physics,
          ),
        )
        .toList();
    return Lynx3dSceneExtension(
      active: _base.active,
      gravity: _base.gravity,
      ambientColor: _base.ambientColor,
      camera: _base.camera,
      room: _base.room,
      terrain: _base.terrain,
      render: _base.render,
      physicsJoints: _base.physicsJoints,
      objects: objs,
      culling: _base.culling,
    );
  }
}
