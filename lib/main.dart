import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'database/database_helper.dart';
import 'services/notification_service.dart';
import 'services/supabase_config.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database on app startup (Offline support)
  try {
    await DatabaseHelper.instance.database;
  } catch (e) {
    debugPrint('Database initialization error: $e');
  }

  // Initialize notifications (non-blocking)
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification initialization error: $e');
  }

  // Initialize Supabase (cloud sync) — separate try/catch so DB/notifications
  // failures don't prevent cloud from working
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      debugPrint('Supabase initialized successfully');
      // Retry any items that failed to sync while offline
      SyncService.instance.flushQueue();
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  } else {
    debugPrint('Supabase not configured — running in offline-only mode');
  }

  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Colors.black, // Sleek black priority
          secondary: Color(0xFFF3F3F3), // Light grey for buttons
          background: Colors.white, // Clean white background
          surface: Colors.white,
          onPrimary: Colors.white,
          onBackground: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(
          0xFFFBFBFB,
        ), // Very slight off-white
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.black87, displayColor: Colors.black),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Clean app bars
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill shaped!
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1.5,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
