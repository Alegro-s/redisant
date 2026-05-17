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
  return NexusEditorLaunchResult.fail(
    'Отдельный Lynx Editor доступен только на desktop (Windows/macOS/Linux).',
  );
}
