import 'dart:io';

class NexusEditorLaunchResult {
  NexusEditorLaunchResult.ok() : ok = true, message = null;
  NexusEditorLaunchResult.fail(this.message) : ok = false;
  final bool ok;
  final String? message;
}

Future<NexusEditorLaunchResult> launchNexusEditorProcess({
  required String? executablePath,
  required List<String> arguments,
}) async {
  final exe = executablePath?.trim() ?? '';
  if (exe.isEmpty) {
    return NexusEditorLaunchResult.fail(
      'Укажите путь к исполняемому файлу Lynx Editor в настройках профиля.',
    );
  }
  final f = File(exe);
  if (!await f.exists()) {
    return NexusEditorLaunchResult.fail('Файл не найден: $exe');
  }
  try {
    await Process.start(exe, arguments, mode: ProcessStartMode.detached);
    return NexusEditorLaunchResult.ok();
  } catch (e) {
    return NexusEditorLaunchResult.fail('$e');
  }
}
