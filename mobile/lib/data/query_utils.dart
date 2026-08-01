import 'package:supabase_flutter/supabase_flutter.dart';

/// Splits a raw search box value into the tokens that are sent to Postgres.
/// Characters that would break PostgREST's filter grammar are dropped.
List<String> searchTokens(String? raw) {
  final cleaned = (raw ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'[,()%*\\]'), ' ')
      .trim();
  if (cleaned.isEmpty) return const [];
  return cleaned
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .take(4)
      .toList();
}

/// True when the error means the mobile views from
/// `supabase/mobile_performance.sql` have not been created yet,
/// or are missing newer columns (brand / category).
bool isMissingRelation(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    if (code == '42P01' ||
        code == 'PGRST205' ||
        code == 'PGRST202' ||
        code == 'PGRST204' ||
        code == '42703') {
      return true;
    }
    final msg = error.message.toLowerCase();
    return msg.contains('does not exist') ||
        msg.contains('schema cache') ||
        msg.contains('could not find') ||
        msg.contains('column');
  }
  final msg = error.toString();
  return msg.contains('42P01') ||
      msg.contains('PGRST205') ||
      msg.contains('PGRST202') ||
      msg.contains('PGRST204') ||
      msg.contains('42703');
}
