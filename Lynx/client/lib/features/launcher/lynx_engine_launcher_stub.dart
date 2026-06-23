class LynxEngineLaunchResult {
  LynxEngineLaunchResult.ok({this.inProcess = false})
      : ok = true,
        message = null;
  LynxEngineLaunchResult.fail(this.message)
      : ok = false,
        inProcess = false;
  final bool ok;
  final String? message;
  final bool inProcess;
}

bool get lynxEngineSpawnSupported => false;

String? resolveLynxEngineExecutable({String? configuredPath}) => null;

Future<LynxEngineLaunchResult> launchLynxEngineProcess({
  required String? executablePath,
  required List<String> arguments,
}) async =>
    LynxEngineLaunchResult.fail('Запуск Lynx Engine недоступен на этой платформе.');
