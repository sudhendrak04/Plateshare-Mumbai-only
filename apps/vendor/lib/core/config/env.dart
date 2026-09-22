class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
}
