/// Web: проект подгружается из `/game_data/` при export preset Web.
Future<String?> resolvePlayerProjectRoot() async {
  const fromDefine = String.fromEnvironment('LYNX_GAME_DATA', defaultValue: '');
  if (fromDefine.isNotEmpty) return fromDefine;
  return 'web_game_data';
}
