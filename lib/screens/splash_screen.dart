import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'manager_auth_screen.dart';
import 'tutorial_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Request permissions and schedule in the background completely non-blocking
    _initNotifications();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward().then((_) {
      _navigateToNextScreen();
    });
  }

  Future<void> _initNotifications() async {
    try {
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.scheduleDailyAITips();
    } catch (e) {
      debugPrint("Notification setup failed: $e");
    }
  }

  Future<void> _navigateToNextScreen() async {
    // Wait an extra second for effect
    await Future.delayed(const Duration(milliseconds: 1000));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;
    final companyId = prefs.getString('companyId');

    Widget nextScreen;
    if (!hasSeenTutorial) {
      nextScreen = const TutorialScreen();
    } else if (companyId != null && companyId.isNotEmpty) {
      DatabaseHelper.instance.currentCompanyId = companyId;
      nextScreen = const LoginScreen();
    } else {
      nextScreen = const ManagerAuthScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Uses the provided icon.png
                    Image.asset(
                      'assets/icon.png',
                      width: 120,
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.cloud_sync,
                          size: 100,
                          color: Colors.black,
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'AURA',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8.0,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intelligent Inventory',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        letterSpacing: 2.0,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
