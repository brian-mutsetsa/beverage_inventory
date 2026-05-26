import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static final SessionManager instance = SessionManager._init();
  SessionManager._init();

  DateTime _lastActivity = DateTime.now();
  Timer? _timer;
  VoidCallback? _onTimeout;

  /// Default timeout: 15 minutes. Can be changed by manager.
  Duration _timeoutDuration = const Duration(minutes: 15);
  bool _isEnabled = true;

  Duration get timeoutDuration => _timeoutDuration;
  bool get isEnabled => _isEnabled;

  /// Load the saved timeout preference.
  Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt('session_timeout_minutes') ?? 15;
    if (minutes <= 0) {
      _isEnabled = false;
      _timeoutDuration = Duration.zero;
    } else {
      _isEnabled = true;
      _timeoutDuration = Duration(minutes: minutes);
    }
  }

  /// Save timeout preference. Pass 0 for "Never".
  Future<void> setTimeoutMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('session_timeout_minutes', minutes);
    if (minutes <= 0) {
      _isEnabled = false;
      _timeoutDuration = Duration.zero;
      stopMonitoring();
    } else {
      _isEnabled = true;
      _timeoutDuration = Duration(minutes: minutes);
    }
  }

  /// Reset the activity timer. Call on every user interaction.
  void resetTimer() {
    _lastActivity = DateTime.now();
  }

  /// Check if the session has expired.
  bool isExpired() {
    if (!_isEnabled) return false;
    return DateTime.now().difference(_lastActivity) > _timeoutDuration;
  }

  /// Start monitoring for timeout. Checks every 30 seconds.
  void startMonitoring(VoidCallback onTimeout) {
    _onTimeout = onTimeout;
    _lastActivity = DateTime.now();
    _timer?.cancel();
    if (!_isEnabled) return;
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isExpired()) {
        stopMonitoring();
        _onTimeout?.call();
      }
    });
  }

  /// Stop monitoring. Call on logout.
  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
  }
}
