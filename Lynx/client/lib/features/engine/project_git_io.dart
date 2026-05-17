import 'dart:io';

class GitCommandResult {
  final bool ok;
  final String output;
  GitCommandResult({required this.ok, required this.output});
}

Future<GitCommandResult> projectGitInit(String root) async {
  if (!Directory(root).existsSync()) {
    return GitCommandResult(ok: false, output: 'Папка не найдена');
  }
  if (Directory('$root/.git').existsSync()) {
    return GitCommandResult(ok: true, output: 'Репозиторий уже инициализирован');
  }
  final r = await Process.run('git', ['init'], workingDirectory: root);
  final out = '${r.stdout}${r.stderr}'.trim();
  return GitCommandResult(ok: r.exitCode == 0, output: out.isEmpty ? 'git init' : out);
}

Future<GitCommandResult> projectGitStatus(String root) async {
  final r = await Process.run('git', ['status', '--short'], workingDirectory: root);
  return GitCommandResult(
    ok: r.exitCode == 0,
    output: '${r.stdout}${r.stderr}'.trim(),
  );
}

Future<GitCommandResult> projectGitAddAll(String root) async {
  final r = await Process.run('git', ['add', '-A'], workingDirectory: root);
  return GitCommandResult(ok: r.exitCode == 0, output: '${r.stdout}${r.stderr}'.trim());
}

Future<GitCommandResult> projectGitCommit(String root, String message) async {
  final add = await projectGitAddAll(root);
  if (!add.ok) return add;
  final r = await Process.run(
    'git',
    ['commit', '-m', message],
    workingDirectory: root,
  );
  return GitCommandResult(ok: r.exitCode == 0, output: '${r.stdout}${r.stderr}'.trim());
}
