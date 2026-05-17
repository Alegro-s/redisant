Future<GitCommandResult> projectGitInit(String root) async =>
    GitCommandResult(ok: false, output: 'Git в браузере недоступен');

Future<GitCommandResult> projectGitStatus(String root) async =>
    GitCommandResult(ok: false, output: '');

Future<GitCommandResult> projectGitCommit(String root, String message) async =>
    GitCommandResult(ok: false, output: '');

class GitCommandResult {
  final bool ok;
  final String output;
  GitCommandResult({required this.ok, required this.output});
}
