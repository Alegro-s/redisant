import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// TIC-80 style square-wave SFX synthesizer (PCM → WAV bytes).
class TicAudioSynth {
  static const sampleRate = 44100;

  static Uint8List synthesizeSfxWave({
    required int note,
    required int durationTicks,
    required int volume,
    int wave = 0,
  }) {
    final vol = (volume.clamp(0, 15) / 15.0) * 0.35;
    final freq = note >= 0 ? _noteToHz(note) : 220.0;
    final samples = ((durationTicks / 60.0) * sampleRate).round().clamp(256, sampleRate);
    final pcm = Float32List(samples);
    for (var i = 0; i < samples; i++) {
      final t = i / sampleRate;
      final env = _adsr(i, samples);
      final phase = (t * freq) % 1.0;
      double sample;
      switch (wave) {
        case 1:
          sample = phase < 0.5 ? 1.0 : -1.0;
        case 2:
          sample = 2.0 * phase - 1.0;
        default:
          sample = math.sin(2 * math.pi * phase);
      }
      pcm[i] = (sample * env * vol).clamp(-1.0, 1.0);
    }
    return _pcmToWav(pcm);
  }

  static double _noteToHz(int note) {
    return 440.0 * math.pow(2, (note - 57) / 12.0);
  }

  static double _adsr(int i, int total) {
    final attack = (total * 0.05).round().clamp(1, 800);
    final release = (total * 0.25).round().clamp(1, 4000);
    if (i < attack) return i / attack;
    if (i > total - release) return (total - i) / release;
    return 1.0;
  }

  static Uint8List _pcmToWav(Float32List pcm) {
    final byteRate = sampleRate * 2;
    final dataSize = pcm.length * 2;
    final out = ByteData(44 + dataSize);
    out.setUint32(0, 0x46464952, Endian.little); // RIFF
    out.setUint32(4, 36 + dataSize, Endian.little);
    out.setUint32(8, 0x45564157, Endian.little); // WAVE
    out.setUint32(12, 0x20746d66, Endian.little); // fmt
    out.setUint32(16, 16, Endian.little);
    out.setUint16(20, 1, Endian.little);
    out.setUint16(22, 1, Endian.little);
    out.setUint32(24, sampleRate, Endian.little);
    out.setUint32(28, byteRate, Endian.little);
    out.setUint16(32, 2, Endian.little);
    out.setUint16(34, 16, Endian.little);
    out.setUint32(36, 0x61746164, Endian.little); // data
    out.setUint32(40, dataSize, Endian.little);
    var o = 44;
    for (final f in pcm) {
      final s = (f.clamp(-1.0, 1.0) * 32767).round();
      out.setInt16(o, s, Endian.little);
      o += 2;
    }
    return out.buffer.asUint8List();
  }
}

/// Loads `assets/tic/sfx.json` / `music.json` and plays synthesized audio.
class TicAudioEngine {
  TicAudioEngine(this._player);

  final AudioPlayer _player;
  List<TicSfxDef> _sfx = const [];
  List<List<int>> _musicTracks = const [];
  int? _musicTrack;
  int _musicRow = 0;
  int _musicTick = 0;

  Future<void> loadProject(String? projectRoot) async {
    _sfx = const [];
    _musicTracks = const [];
    if (projectRoot == null || projectRoot.isEmpty) return;
    if (kIsWeb) return;
    final ticDir = Directory(p.join(projectRoot, 'assets', 'tic'));
    if (!await ticDir.exists()) return;
    final sfxFile = File(p.join(ticDir.path, 'sfx.json'));
    if (await sfxFile.exists()) {
      try {
        final raw = jsonDecode(await sfxFile.readAsString());
        if (raw is List) {
          _sfx = raw
              .map((e) => TicSfxDef.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      } catch (_) {}
    }
    final musicFile = File(p.join(ticDir.path, 'music.json'));
    if (await musicFile.exists()) {
      try {
        final raw = jsonDecode(await musicFile.readAsString());
        if (raw is List) {
          _musicTracks = raw
              .map((t) => (t as List).map((n) => (n as num).toInt()).toList())
              .toList();
        }
      } catch (_) {}
    }
  }

  Future<void> handleSoundEvent(String line) async {
    if (!line.trimLeft().startsWith('{')) return;
    try {
      final m = jsonDecode(line);
      if (m is! Map) return;
      if (m.containsKey('tic_sfx')) {
        await playSfx(Map<String, dynamic>.from(m['tic_sfx'] as Map));
      } else if (m.containsKey('tic_music')) {
        await playMusic(Map<String, dynamic>.from(m['tic_music'] as Map));
      }
    } catch (_) {}
  }

  Future<void> playSfx(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt() ?? 0;
    TicSfxDef def;
    if (id >= 0 && id < _sfx.length) {
      def = _sfx[id];
    } else {
      def = TicSfxDef(
        note: (args['note'] as num?)?.toInt() ?? 48,
        volume: (args['volume'] as num?)?.toInt() ?? 15,
        duration: (args['duration'] as num?)?.toInt() ?? 10,
      );
    }
    final note = (args['note'] as num?)?.toInt();
    final duration = (args['duration'] as num?)?.toInt();
    final volume = (args['volume'] as num?)?.toInt();
    final wav = TicAudioSynth.synthesizeSfxWave(
      note: note != null && note >= 0 ? note : def.note,
      durationTicks: duration != null && duration > 0 ? duration : def.duration,
      volume: volume ?? def.volume,
    );
    await _player.play(BytesSource(wav), volume: 1.0);
  }

  Future<void> playMusic(Map<String, dynamic> args) async {
    final track = (args['track'] as num?)?.toInt() ?? 0;
    if (track < 0) {
      _musicTrack = null;
      await _player.stop();
      return;
    }
    _musicTrack = track.clamp(0, _musicTracks.isEmpty ? 0 : _musicTracks.length - 1);
    _musicRow = (args['row'] as num?)?.toInt() ?? 0;
    _musicTick = 0;
    await _tickMusic();
  }

  Future<void> tickMusicFrame() async {
    if (_musicTrack == null) return;
    _musicTick++;
    if (_musicTick % 30 != 0) return;
    await _tickMusic();
  }

  Future<void> _tickMusic() async {
    final track = _musicTrack;
    if (track == null || track >= _musicTracks.length) return;
    final rows = _musicTracks[track];
    if (rows.isEmpty) return;
    final note = rows[_musicRow % rows.length];
    _musicRow++;
    if (note < 0) return;
    final wav = TicAudioSynth.synthesizeSfxWave(note: note, durationTicks: 28, volume: 12);
    await _player.play(BytesSource(wav), volume: 0.9);
  }

  void dispose() {}
}

class TicSfxDef {
  final int note;
  final int volume;
  final int duration;

  const TicSfxDef({this.note = 48, this.volume = 15, this.duration = 10});

  factory TicSfxDef.fromJson(Map<String, dynamic> j) => TicSfxDef(
        note: (j['note'] as num?)?.toInt() ?? 48,
        volume: (j['volume'] as num?)?.toInt() ?? 15,
        duration: (j['duration'] as num?)?.toInt() ?? 10,
      );
}
