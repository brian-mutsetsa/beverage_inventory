/// Supabase configuration constants.
/// 
/// To set up:
/// 1. Create a free project at https://supabase.com
/// 2. Go to Settings → API in your Supabase dashboard
/// 3. Copy your Project URL and anon/public key
/// 4. Paste them below
class SupabaseConfig {
  // Replace these with your actual Supabase project values
  static const String supabaseUrl = 'https://nfyygtiaywzkdutdxeew.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5meXlndGlheXd6a2R1dGR4ZWV3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM3NTUzNzQsImV4cCI6MjA4OTMzMTM3NH0.4SHjB5g5aJDx40_Vny9_G8lm8bxzaTTFgLl2jHlhfwM';

  /// Returns true if Supabase credentials have been configured.
  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
