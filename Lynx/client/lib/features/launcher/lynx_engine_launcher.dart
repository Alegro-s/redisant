import 'package:flutter/foundation.dart' show kIsWeb;

import 'lynx_engine_launcher_stub.dart'
    if (dart.library.io) 'lynx_engine_launcher_io.dart' as io;

export 'lynx_engine_launcher_io.dart'
    if (dart.library.html) 'lynx_engine_launcher_stub.dart';

typedef LynxEngineLaunchResult = io.LynxEngineLaunchResult;

bool get lynxEngineSpawnSupported => io.lynxEngineSpawnSupported;

String? resolveLynxEngineExecutable({String? configuredPath}) =>
    io.resolveLynxEngineExecutable(configuredPath: configuredPath);

Future<LynxEngineLaunchResult> launchLynxEngineProcess({
  required String? executablePath,
  required List<String> arguments,
}) =>
    io.launchLynxEngineProcess(
      executablePath: executablePath,
      arguments: arguments,
    );
