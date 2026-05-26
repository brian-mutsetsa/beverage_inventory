import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  /// Hash a PIN using SHA-256. Returns a 64-character hex string.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a plaintext PIN against a stored hash.
  static bool verifyPin(String inputPin, String storedHash) {
    return hashPin(inputPin) == storedHash;
  }

  /// Check if a PIN is already hashed (64-char hex string = SHA-256).
  static bool isAlreadyHashed(String pin) {
    return pin.length == 64 && RegExp(r'^[a-f0-9]{64}$').hasMatch(pin);
  }

  /// Check if a PIN is too weak.
  /// Rejects: all-same characters, common sequences, no letter+digit mix.
  static bool isWeakPin(String pin) {
    // All characters the same
    if (pin.split('').toSet().length == 1) return true;

    // Common sequences
    const weakPatterns = [
      '123456', '654321', 'ABCDEF', 'FEDCBA',
      'abcdef', 'fedcba', '111111', '000000',
      'aaaaaa', 'AAAAAA', '123ABC', 'ABC123',
    ];
    if (weakPatterns.contains(pin.toUpperCase()) || weakPatterns.contains(pin)) {
      return true;
    }

    // Must contain at least 1 letter and 1 digit
    final hasLetter = pin.contains(RegExp(r'[a-zA-Z]'));
    final hasDigit = pin.contains(RegExp(r'[0-9]'));
    if (!hasLetter || !hasDigit) return true;

    return false;
  }
}
