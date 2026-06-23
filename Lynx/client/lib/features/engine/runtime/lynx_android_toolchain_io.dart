import 'dart:io';

import 'package:path/path.dart' as p;

import 'lynx_project_templates.dart';

typedef LynxBuildLog = void Function(String message);

class LynxAndroidEnv {
  final String javaHome;
  final String sdkRoot;
  final String? ndkHome;
  const LynxAndroidEnv({
    required this.javaHome,
    required this.sdkRoot,
    this.ndkHome,
  });

  Map<String, String> toProcessEnv() {
    final m = Map<String, String>.from(Platform.environment);
    m['JAVA_HOME'] = javaHome;
    m['ANDROID_HOME'] = sdkRoot;
    m['ANDROID_SDK_ROOT'] = sdkRoot;
    if (ndkHome != null) m['ANDROID_NDK_HOME'] = ndkHome!;
    final bin = p.join(javaHome, 'bin');
    m['PATH'] = '$bin${Platform.pathSeparator}${m['PATH'] ?? ''}';
    return m;
  }
}

String _lynxLocalRoot() {
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    return p.join(local, 'Lynx');
  }
  return p.join(Directory.systemTemp.path, 'Lynx');
}

Future<String?> _resolveToolchainScript() async {
  final candidates = <String>[];
  try {
    final exe = p.dirname(Platform.resolvedExecutable);
    candidates.add(p.join(exe, 'tools', 'ensure-lynx-android-toolchain.ps1'));
    candidates.add(p.join(exe, '..', 'scripts', 'ensure-lynx-android-toolchain.ps1'));
  } catch (_) {}
  candidates.add(p.join(resolveLynxRepoRootFromClient(), 'scripts', 'ensure-lynx-android-toolchain.ps1'));
  for (final c in candidates) {
    if (await File(c).exists()) return p.normalize(c);
  }
  return null;
}

/// JDK + SDK + NDK в %LOCALAPPDATA%\Lynx (Windows).
Future<String?> ensureLynxAndroidToolchain({
  required String clientRoot,
  LynxBuildLog? onLog,
}) async {
  if (!Platform.isWindows) {
    return 'Автоустановка Android SDK доступна на Windows. Установите Android Studio вручную.';
  }

  final jdk = p.join(_lynxLocalRoot(), 'jdk-17', 'bin', 'java.exe');
  final sdk = p.join(_lynxLocalRoot(), 'android-sdk');
  final sdkmanager = p.join(sdk, 'cmdline-tools', 'latest', 'bin', 'sdkmanager.bat');

  if (!await File(jdk).exists() || !await File(sdkmanager).exists()) {
    final script = await _resolveToolchainScript();
    if (script == null) {
      return 'Скрипт ensure-lynx-android-toolchain.ps1 не найден. Переустановите Lynx Launcher.';
    }
    onLog?.call('Загрузка JDK, Android SDK и NDK (первый раз ~1–3 ГБ)…');
    final r = await Process.run(
      'powershell',
      [
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        script,
        '-ClientRoot',
        clientRoot,
      ],
      runInShell: true,
    );
    final out = '${r.stdout}\n${r.stderr}'.trim();
    if (out.isNotEmpty) onLog?.call(out);
    if (r.exitCode != 0) {
      if (out.contains('being used by another process') ||
          out.contains('cmdline-tools-win.zip')) {
        return 'Файл Android SDK занят другим процессом. Закройте все сборки Lynx, '
            'удалите %LOCALAPPDATA%\\Lynx\\cache\\cmdline-tools-win.zip и повторите.';
      }
      return 'Не удалось установить Android toolchain (код ${r.exitCode})';
    }
  } else {
    await _writeLocalProperties(clientRoot, sdk);
  }

  if (!await File(jdk).exists()) {
    return 'JDK не установлен после provisioning';
  }
  return null;
}

Future<LynxAndroidEnv?> loadLynxAndroidEnv() async {
  final jdkHome = p.join(_lynxLocalRoot(), 'jdk-17');
  final sdkRoot = p.join(_lynxLocalRoot(), 'android-sdk');
  if (!await File(p.join(jdkHome, 'bin', 'java.exe')).exists()) return null;
  if (!await Directory(sdkRoot).exists()) return null;

  String? ndkHome;
  final ndkBase = Directory(p.join(sdkRoot, 'ndk'));
  if (await ndkBase.exists()) {
    final dirs = await ndkBase
        .list()
        .where((e) => e is Directory)
        .cast<Directory>()
        .toList();
    dirs.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    if (dirs.isNotEmpty) ndkHome = dirs.first.path;
  }
  if (ndkHome == null) {
    final envNdk = Platform.environment['ANDROID_NDK_HOME'];
    if (envNdk != null && await Directory(envNdk).exists()) ndkHome = envNdk;
  }

  return LynxAndroidEnv(javaHome: jdkHome, sdkRoot: sdkRoot, ndkHome: ndkHome);
}

Future<void> _writeLocalProperties(String clientRoot, String sdkRoot) async {
  final lp = File(p.join(clientRoot, 'android', 'local.properties'));
  final sdkEsc = sdkRoot.replaceAll('\\', r'\\');
  var lines = <String>[];
  if (await lp.exists()) {
    lines = (await lp.readAsString())
        .split('\n')
        .where((l) => !l.trim().startsWith('sdk.dir='))
        .toList();
  }
  lines.add('sdk.dir=$sdkEsc');
  await lp.parent.create(recursive: true);
  await lp.writeAsString('${lines.join('\n')}\n');
}

/// libengine.so из MSI / репозитория.
Future<String?> resolveBundledAndroidEngineSo() async {
  final names = ['libengine.so'];
  final candidates = <String>[];
  try {
    final exe = p.dirname(Platform.resolvedExecutable);
    for (final rel in ['tools/jniLibs/arm64-v8a', 'jniLibs/arm64-v8a', 'engine/android/arm64-v8a']) {
      candidates.add(p.join(exe, rel, names.first));
    }
  } catch (_) {}
  candidates.add(p.join(
    resolveLynxRepoRootFromClient(),
    'client',
    'android',
    'app',
    'src',
    'main',
    'jniLibs',
    'arm64-v8a',
    'libengine.so',
  ));
  candidates.add(p.join(_lynxLocalRoot(), 'jniLibs', 'arm64-v8a', 'libengine.so'));

  for (final c in candidates) {
    final f = File(c);
    if (await f.exists() && await f.length() > 1000) return c;
  }
  return null;
}
