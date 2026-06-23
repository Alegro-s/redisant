import 'dart:js_interop';
import 'dart:js_util' as jsu;

import 'dart:convert';
import 'dart:io';

import 'tic_audio_engine.dart';
import 'web_logic_grid_state.dart';

/// Fengari Lua runtime for Lynx Cart on Web (E18b — не заглушка).
class LynxLuaWebRuntime {
  LynxLuaWebRuntime._(this._stateId, this._grids);

  static int _seq = 0;
  final String _stateId;
  final WebLogicGridState _grids;
  bool _loaded = false;

  static LynxLuaWebRuntime? create(WebLogicGridState grids, {TicAudioEngine? ticAudio}) {
    if (!jsu.hasProperty(jsu.globalThis, 'LynxLuaBridge')) return null;
    final id = 'lynx_${++_seq}';
    final api = jsu.jsify({
      'gridEnsure': jsu.allowInterop((String name, int w, int h) {
        grids.ensure(name, w, h);
      }),
      'gridGet': jsu.allowInterop((String name, int x, int y) {
        return grids.get(name, x, y);
      }),
      'gridSet': jsu.allowInterop((String name, int x, int y, int v) {
        grids.set(name, x, y, v);
      }),
      'gridFill': jsu.allowInterop((String name, int v) {
        grids.fill(name, v);
      }),
      'gridWidth': jsu.allowInterop((String name) {
        return grids.width(name);
      }),
      'btnPressed': jsu.allowInterop((String key) {
        return grids.input.btnPressed(key);
      }),
      'actionPressed': jsu.allowInterop((String key) {
        return grids.input.actionPressed(key);
      }),
      'nexusLog': jsu.allowInterop((String msg) {
        grids.log(msg);
      }),
      'keyHeld': jsu.allowInterop((String key) {
        return grids.input.keyHeld(key);
      }),
      'ticSfx': jsu.allowInterop((int id, int note, int duration, int channel, int volume, int speed) {
        final line = jsonEncode({
          'tic_sfx': {
            'id': id,
            'note': note,
            'duration': duration,
            'channel': channel,
            'volume': volume,
            'speed': speed,
          },
        });
        if (ticAudio != null) {
          ticAudio.handleSoundEvent(line);
        } else {
          grids.log('sfx:$id');
        }
      }),
      'ticMusic': jsu.allowInterop((int track, int frame, int row, bool loopOn) {
        final line = jsonEncode({
          'tic_music': {'track': track, 'frame': frame, 'row': row, 'loop': loopOn},
        });
        if (ticAudio != null) {
          ticAudio.handleSoundEvent(line);
        } else {
          grids.log('music:$track');
        }
      }),
    });
    jsu.callMethod(jsu.globalThis, 'LynxLuaBridge.create', [id, api]);
    return LynxLuaWebRuntime._(id, grids);
  }

  String? load(String code) {
    final err = jsu.callMethod(
      jsu.globalThis,
      'LynxLuaBridge.load',
      [_stateId, code],
    );
    if (err != null) return err.toString();
    _loaded = true;
    return null;
  }

  String? runFrame(double dt, Map<String, dynamic> globals) {
    if (!_loaded) return 'Lua not loaded';
    final err = jsu.callMethod(
      jsu.globalThis,
      'LynxLuaBridge.runFrame',
      [_stateId, dt, jsu.jsify(globals)],
    );
    return err?.toString();
  }

  void dispose() {
    jsu.callMethod(jsu.globalThis, 'LynxLuaBridge.destroy', [_stateId]);
  }
}

bool get lynxLuaWebAvailable =>
    jsu.hasProperty(jsu.globalThis, 'LynxLuaBridge') &&
    jsu.hasProperty(jsu.globalThis, 'fengari');
