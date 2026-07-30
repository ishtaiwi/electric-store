import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';
import '../core/utils/helpers.dart';

/// Mobile-only trial invoices.
///
/// Writes exclusively to `mobile_trial_invoices` / `mobile_trial_sales`.
/// Never touches desktop tables (`invoices`, `sales`, `customer_payments`)
/// and never changes product stock or customer balances.
class SalesRepository {
  SalesRepository(this._client);

  final SupabaseClient _client;
  final _random = Random();

  static const invoicesTable = 'mobile_trial_invoices';
  static const salesTable = 'mobile_trial_sales';

  String _trialInvoiceNumber() {
    final suffix = _random.nextInt(9999).toString().padLeft(4, '0');
    return 'MOB-${DateTime.now().millisecondsSinceEpoch}-$suffix';
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('mobile_trial_invoices') ||
        msg.contains('PGRST205') ||
        msg.contains('42P01') ||
        (msg.contains('relation') && msg.contains('does not exist'))) {
      return 'جداول الفواتير التجريبية غير موجودة في Supabase.\n'
          'نفّذ ملف mobile_trial_invoices.sql من مجلد supabase.';
    }
    return msg;
  }

  /// Creates a mobile trial invoice only — no stock / balance side effects.
  Future<CreatedInvoice> checkout({
    required List<CartLine> items,
    Customer? customer,
    double discountAmount = 0,
    double? paidAmount,
    int? userId,
  }) async {
    if (items.isEmpty) throw Exception('السلة فارغة');
    if (discountAmount < 0) throw Exception('الخصم غير صالح');

    final recordDate = DateTime.now();
    final totals = _calcTotals(items, discountAmount);
    final invoiceNumber = _trialInvoiceNumber();
    final paymentMethod = customer?.id != null ? 'trial_account' : 'trial_cash';
    final actualPaid =
        paidAmount ?? (customer?.id != null ? 0.0 : totals.finalAmount);

    try {
      final invRow = await _client.from(invoicesTable).insert({
        'invoice_number': invoiceNumber,
        'customer_id': customer?.id,
        'customer_name': customer?.name,
        'total_amount': totals.totalAmount,
        'discount_amount': discountAmount,
        'final_amount': totals.finalAmount,
        'paid_amount': actualPaid,
        'total_profit': totals.totalProfit,
        'payment_method': paymentMethod,
        'notes': 'Mobile trial invoice — does not affect stock or balances',
        'created_by': userId,
        'created_date': recordDate.toIso8601String(),
        'sale_date': recordDate.toIso8601String(),
      }).select().single();

      final invoiceId = asInt(invRow['id'])!;

      for (final item in items) {
        final itemTotal = item.totalPrice;
        final itemDiscount = totals.totalAmount > 0
            ? (discountAmount / totals.totalAmount) * itemTotal
            : 0.0;
        final itemFinal = itemTotal - itemDiscount;
        final itemProfit = item.profit - itemDiscount;

        await _client.from(salesTable).insert({
          'invoice_id': invoiceId,
          'product_id': item.product.id,
          'barcode': item.product.barcode,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'cost_price': item.product.costPrice,
          'sale_price': item.unitPrice,
          'total_amount': itemTotal,
          'profit': itemProfit,
          'customer_id': customer?.id,
          'discount_amount': itemDiscount,
          'final_amount': itemFinal,
          'sale_date': recordDate.toIso8601String(),
          if (item.note != null) 'note': item.note,
        });
      }

      return CreatedInvoice(
        id: invoiceId,
        invoiceNumber: invoiceNumber,
        customerId: customer?.id,
        customerName: customer?.name,
        totalAmount: totals.totalAmount,
        discountAmount: discountAmount,
        finalAmount: totals.finalAmount,
        paidAmount: actualPaid,
        paymentMethod: paymentMethod,
        saleDate: recordDate,
      );
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<List<CreatedInvoice>> listTrialInvoices({int limit = 50}) async {
    try {
      final rows = await _client
          .from(invoicesTable)
          .select()
          .order('id', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows as List)
          .map(
            (m) => CreatedInvoice(
              id: asInt(m['id'])!,
              invoiceNumber: m['invoice_number'] as String? ?? '',
              customerId: asInt(m['customer_id']),
              customerName: m['customer_name'] as String?,
              totalAmount: asDouble(m['total_amount']),
              discountAmount: asDouble(m['discount_amount']),
              finalAmount: asDouble(m['final_amount']),
              paidAmount: asDouble(m['paid_amount']),
              paymentMethod: m['payment_method'] as String? ?? 'trial_cash',
              saleDate: asDate(m['sale_date']),
            ),
          )
          .toList();
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<List<SaleLine>> getTrialInvoiceLines(int invoiceId) async {
    try {
      final rows = await _client
          .from(salesTable)
          .select()
          .eq('invoice_id', invoiceId)
          .order('id');
      return List<Map<String, dynamic>>.from(rows as List)
          .map(SaleLine.fromMap)
          .toList();
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  /// Deletes a trial invoice and its line items (CASCADE).
  Future<void> deleteTrialInvoice(int invoiceId) async {
    try {
      await _client.from(invoicesTable).delete().eq('id', invoiceId);
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<void> deleteAllTrialInvoices() async {
    try {
      // Delete all rows: filter that matches every id
      await _client.from(invoicesTable).delete().gte('id', 0);
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  _Totals _calcTotals(List<CartLine> items, double discountAmount) {
    double totalAmount = 0;
    double totalProfit = 0;
    for (final item in items) {
      totalAmount += item.totalPrice;
      totalProfit += item.profit;
    }
    return _Totals(
      totalAmount: totalAmount,
      finalAmount: totalAmount - discountAmount,
      totalProfit: totalProfit - discountAmount,
    );
  }
}

class _Totals {
  final double totalAmount;
  final double finalAmount;
  final double totalProfit;

  const _Totals({
    required this.totalAmount,
    required this.finalAmount,
    required this.totalProfit,
  });
}
