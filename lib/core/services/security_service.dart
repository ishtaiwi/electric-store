import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Security service for password hashing and validation
/// Implements SHA-256 hashing with salt for secure password storage
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  /// Salt for password hashing (should be stored securely in production)
  static const String _salt = 'ElectricalStore_2024_SecureSalt';

  /// Hash a password using SHA-256 with salt
  /// Returns the hashed password as a hex string
  String hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify a password against a stored hash
  bool verifyPassword(String password, String storedHash) {
    final hashedInput = hashPassword(password);
    return hashedInput == storedHash;
  }

  /// Validate password strength
  /// Returns null if valid, error message if invalid
  String? validatePasswordStrength(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    // For simplicity, we allow any password >= 6 chars
    // In production, add more rules (uppercase, numbers, special chars)
    return null;
  }

  /// Sanitize input to prevent SQL injection and XSS
  /// Note: SQLite parameterized queries already prevent SQL injection,
  /// but this adds an extra layer of protection
  String sanitizeInput(String input) {
    // Remove potentially dangerous characters
    return input
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .replaceAll('--', '')
        .replaceAll(';', '')
        .trim();
  }

  /// Validate email format
  bool isValidEmail(String email) {
    if (email.isEmpty) return true; // Email is optional
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number format
  bool isValidPhone(String phone) {
    if (phone.isEmpty) return true; // Phone is optional
    // Allow digits, spaces, dashes, plus sign, and parentheses
    final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]{7,20}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Validate numeric input
  bool isValidNumber(String value, {double? min, double? max}) {
    final number = double.tryParse(value);
    if (number == null) return false;
    if (min != null && number < min) return false;
    if (max != null && number > max) return false;
    return true;
  }

  /// Validate integer input
  bool isValidInteger(String value, {int? min, int? max}) {
    final number = int.tryParse(value);
    if (number == null) return false;
    if (min != null && number < min) return false;
    if (max != null && number > max) return false;
    return true;
  }

  /// Check if input contains only allowed characters
  bool isAlphanumeric(String input) {
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(input);
  }

  /// Mask sensitive data for logging
  String maskSensitiveData(String data, {int visibleChars = 2}) {
    if (data.length <= visibleChars * 2) {
      return '*' * data.length;
    }
    final start = data.substring(0, visibleChars);
    final end = data.substring(data.length - visibleChars);
    final masked = '*' * (data.length - visibleChars * 2);
    return '$start$masked$end';
  }
}
