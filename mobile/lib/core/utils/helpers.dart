import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';

class Security {
  static const _salt = 'ElectricalStore_2024_SecureSalt';

  static String hashPassword(String password) {
    final bytes = utf8.encode(password + _salt);
    return sha256.convert(bytes).toString();
  }

  static bool verifyPassword(String password, String stored) {
    if (stored == hashPassword(password)) return true;
    // Legacy plain-text fallback (same as desktop)
    return stored == password;
  }
}

class Formatters {
  static final _money = NumberFormat('#,##0.00');

  static String money(num value) =>
      '${AppConfig.currencySymbol}${_money.format(value)}';

  static String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String dateTime(DateTime d) =>
      '${date(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

DateTime? asDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}
