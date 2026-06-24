import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

import 'engine_bootstrap.dart';
import '../features/launcher/lynx_launcher_session_io.dart' as session;

Future<bool> shouldShowEngineLauncherGate(EngineBootstrap boot) async {
  if (Platform.isAndroid) return false;
  if (boot.allowStandalone || kDebugMode) return false;
  final ok = await session.LynxLauncherSession.validate(boot.launcherSession);
  return !ok;
}
