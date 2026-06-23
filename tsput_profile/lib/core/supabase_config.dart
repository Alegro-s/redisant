
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://znltxknyweldbtqkrfih.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_M97MwcXitQ9Y6J-lH7QjEg_rmUVUy-P',
  );

  static bool get enabled => url.isNotEmpty && anonKey.isNotEmpty;
}
