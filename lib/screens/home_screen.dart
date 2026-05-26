import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';
import '../models/user.dart';
import '../services/sync_service.dart';
import '../services/session_manager.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'inventory_screen.dart';
import 'sales_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final User currentUser;

  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _pendingNotifications = 0;
  StreamSubscription<SyncEvent>? _syncSubscription;
  Timer? _eodTimer;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(currentUser: widget.currentUser),
      InventoryScreen(currentUser: widget.currentUser),
      SalesScreen(currentUser: widget.currentUser),
      NotificationsScreen(currentUser: widget.currentUser),
      ReportsScreen(currentUser: widget.currentUser),
    ];
    _updateBadgeCount();
    _syncSubscription = SyncService.instance.onSync.listen((event) {
      if (event.table == SyncTable.auditLogs ||
          event.table == SyncTable.products ||
          event.table == SyncTable.all) {
        _updateBadgeCount();
      }
    });

    // Start session timeout monitoring
    SessionManager.instance.loadPreference().then((_) {
      SessionManager.instance.startMonitoring(_handleSessionTimeout);
    });

    // Check notification permission — show a warning banner if blocked
    _checkNotificationPermission();

    // Schedule manager end-of-day summary notification
    if (widget.currentUser.role == 'manager') {
      NotificationService.instance.scheduleDailyManagerSummary();
      _scheduleEodSummary();
    }
  }

  void _handleSessionTimeout() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.timer_off, color: Color(0xFFFF9800)),
            const SizedBox(width: 12),
            Text('Session Expired', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'You have been logged out due to inactivity. Please log in again.',
          style: GoogleFonts.poppins(color: Colors.grey[700]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Log In', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Checks whether notifications are enabled for this app.
  /// On Samsung / OEM devices notifications can be silently blocked.
  /// Shows a persistent warning banner so the user knows how to fix it.
  Future<void> _checkNotificationPermission() async {
    if (!Platform.isAndroid) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    try {
      final android = NotificationService.instance.flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled() ?? true;
      if (!enabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            backgroundColor: const Color(0xFFB71C1C),
            content: const Text(
              '🔕 Notifications are disabled.\n'
              'Go to Settings → Apps → Aura → Notifications and turn them ON.',
              style: TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white70,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (_) {}
  }

  /// Calculates duration until 8:00 PM today (or tomorrow if past 8 PM) and
  /// fires an end-of-day summary notification with real data from the DB.
  void _scheduleEodSummary() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 20, 0);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    final delay = target.difference(now);

    _eodTimer = Timer(delay, () async {
      try {
        final summary = await DatabaseHelper.instance.getTodaySummary();
        await NotificationService.instance.showEndOfDaySummary(
          revenue: (summary['revenue'] as num).toDouble(),
          txCount: summary['count'] as int,
          profit: (summary['profit'] as num).toDouble(),
          margin: (summary['margin'] as num).toDouble(),
        );
      } catch (_) {}
      // Re-schedule for the next day
      if (mounted) _scheduleEodSummary();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    _eodTimer?.cancel();
    SessionManager.instance.stopMonitoring();
    super.dispose();
  }

  Future<void> _updateBadgeCount() async {
    try {
      final requests = await DatabaseHelper.instance.getOrderRequests();
      final fulfilled = await DatabaseHelper.instance.getFulfilledOrderRequestIds();
      final products = await DatabaseHelper.instance.readAllProducts();

      // Build product map for stock-based resolution check
      final productsMap = <int, dynamic>{};
      for (final p in products) {
        if (p.id != null) productsMap[p.id!] = p;
      }

      int pending = 0;
      for (final r in requests) {
        if (r.action != 'order_request') continue;
        if (fulfilled.contains(r.id)) continue;

        // Check stock-based resolution
        final productId = DatabaseHelper.instance.extractProductIdFromDetails(r.details);
        if (productId != null) {
          final product = productsMap[productId];
          if (product != null && product.quantity >= product.minQuantity) continue;
        }
        pending++;
      }

      if (mounted) setState(() => _pendingNotifications = pending);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => SessionManager.instance.resetTimer(),
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 3) _updateBadgeCount(); // Refresh when tapping Alerts
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: ValueListenableBuilder<int>(
              valueListenable: SyncService.instance.pendingCount,
              builder: (context, count, _) => Badge(
                isLabelVisible: count > 0,
                label: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: const Color(0xFFFF9800),
                child: const Icon(Icons.dashboard_rounded),
              ),
            ),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _pendingNotifications > 0,
              label: Text(
                '$_pendingNotifications',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: const Color(0xFFFF9800),
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            label: 'Reports',
          ),
        ],
      ),
      ),
    );
  }
}