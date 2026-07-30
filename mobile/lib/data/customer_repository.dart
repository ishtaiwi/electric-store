import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/helpers.dart';
import 'models.dart';
import 'query_utils.dart';

class CustomerRepository {
  CustomerRepository(this._client);

  final SupabaseClient _client;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isBeforeDay(DateTime date, DateTime dayStart) =>
      _dateOnly(date).isBefore(_dateOnly(dayStart));

  bool _isAfterDay(DateTime date, DateTime dayEnd) =>
      _dateOnly(date).isAfter(_dateOnly(dayEnd));

  String _invoiceDoc(int id) => 'I${id.toString().padLeft(7, '0')}';
  String _receiptDoc(int id) => 'R${id.toString().padLeft(7, '0')}';
  String _discountDoc(int id) => 'D${id.toString().padLeft(7, '0')}';

  static const int pageSize = 40;
  static const String _balanceColumns =
      'id,name,phone,email,address,created_date,balance_adjustment,balance';

  /// Set to false the first time `mobile_customer_balances` turns out to be
  /// missing, so we stop paying for a failed round-trip on every search.
  bool _serverBalances = true;

  List<Customer>? _legacyCache;
  DateTime? _legacyCachedAt;

  void invalidateCache() {
    _legacyCache = null;
    _legacyCachedAt = null;
  }

  /// Fetches one page of customers with balances already aggregated by
  /// Postgres, instead of downloading every invoice and payment.
  Future<PagedResult<Customer>> fetchPage({
    String? query,
    bool debtOnly = false,
    int offset = 0,
    int limit = pageSize,
  }) async {
    if (_serverBalances) {
      try {
        return await _fetchPageFromView(
          query: query,
          debtOnly: debtOnly,
          offset: offset,
          limit: limit,
        );
      } catch (e) {
        if (!isMissingRelation(e)) rethrow;
        _serverBalances = false;
      }
    }
    return _fetchPageLegacy(
      query: query,
      debtOnly: debtOnly,
      offset: offset,
      limit: limit,
    );
  }

  Future<PagedResult<Customer>> _fetchPageFromView({
    required String? query,
    required bool debtOnly,
    required int offset,
    required int limit,
  }) async {
    var filter =
        _client.from('mobile_customer_balances').select(_balanceColumns);
    for (final token in searchTokens(query)) {
      filter = filter.ilike('search_text', '%$token%');
    }
    if (debtOnly) {
      filter = filter.gt('balance', 0);
    }

    final ordered = debtOnly
        ? filter.order('balance', ascending: false)
        : filter.order('name');
    final rows = await ordered.range(offset, offset + limit);
    final list = List<Map<String, dynamic>>.from(rows as List);
    final hasMore = list.length > limit;
    return PagedResult(
      items: list.take(limit).map(Customer.fromMap).toList(),
      hasMore: hasMore,
    );
  }

  Future<PagedResult<Customer>> _fetchPageLegacy({
    required String? query,
    required bool debtOnly,
    required int offset,
    required int limit,
  }) async {
    final all = await _legacyAll();
    final tokens = searchTokens(query);
    var list = all.where((c) {
      if (debtOnly && !c.hasDebt) return false;
      if (tokens.isEmpty) return true;
      final hay = [
        c.name,
        c.phone ?? '',
        (c.phone ?? '').replaceAll(RegExp(r'\D'), ''),
        c.address ?? '',
        c.email ?? '',
      ].join(' ').toLowerCase();
      return tokens.every(hay.contains);
    }).toList();
    if (debtOnly) {
      list.sort((a, b) => b.balance.compareTo(a.balance));
    }

    if (offset >= list.length) return PagedResult.empty<Customer>();
    final end = (offset + limit).clamp(0, list.length);
    return PagedResult(
      items: list.sublist(offset, end),
      hasMore: end < list.length,
    );
  }

  Future<List<Customer>> _legacyAll() async {
    final cached = _legacyCache;
    final at = _legacyCachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 5)) {
      return cached;
    }

    final rows = await _client
        .from('customers')
        .select('id,name,phone,email,address,created_date,balance_adjustment')
        .order('name');
    final invoiced = await _invoiceTotals();
    final paid = await _paymentTotals();

    final list = List<Map<String, dynamic>>.from(rows as List).map((m) {
      final c = Customer.fromMap(m);
      final id = c.id ?? 0;
      return c.copyWithBalance(
        (invoiced[id] ?? 0) - (paid[id] ?? 0) + c.balanceAdjustment,
      );
    }).toList();
    _legacyCache = list;
    _legacyCachedAt = DateTime.now();
    return list;
  }

  Future<Map<int, double>> _invoiceTotals() async {
    final rows = await _client
        .from('invoices')
        .select('customer_id, final_amount')
        .not('customer_id', 'is', null);
    final map = <int, double>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final id = asInt(row['customer_id']);
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + asDouble(row['final_amount']);
    }
    return map;
  }

  Future<Map<int, double>> _paymentTotals() async {
    final rows =
        await _client.from('customer_payments').select('customer_id, amount');
    final map = <int, double>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final id = asInt(row['customer_id']);
      if (id == null) continue;
      map[id] = (map[id] ?? 0) + asDouble(row['amount']);
    }
    return map;
  }

  Future<List<Customer>> getAll({
    String? query,
    bool debtOnly = false,
  }) async {
    final page = await fetchPage(query: query, debtOnly: debtOnly, limit: 1000);
    return page.items;
  }

  Future<Customer?> getById(int id) async {
    if (_serverBalances) {
      try {
        final row = await _client
            .from('mobile_customer_balances')
            .select(_balanceColumns)
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return Customer.fromMap(Map<String, dynamic>.from(row));
      } catch (e) {
        if (!isMissingRelation(e)) rethrow;
        _serverBalances = false;
      }
    }

    final row =
        await _client.from('customers').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final c = Customer.fromMap(Map<String, dynamic>.from(row));
    final invoiced = await _client
        .from('invoices')
        .select('final_amount')
        .eq('customer_id', id);
    final paid = await _client
        .from('customer_payments')
        .select('amount')
        .eq('customer_id', id);
    var inv = 0.0;
    var pay = 0.0;
    for (final r in List<Map<String, dynamic>>.from(invoiced as List)) {
      inv += asDouble(r['final_amount']);
    }
    for (final r in List<Map<String, dynamic>>.from(paid as List)) {
      pay += asDouble(r['amount']);
    }
    return c.copyWithBalance(inv - pay + c.balanceAdjustment);
  }

  Future<Customer> create(Customer customer) async {
    final row = await _client
        .from('customers')
        .insert(customer.toMap())
        .select()
        .single();
    invalidateCache();
    return Customer.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Customer> update(Customer customer) async {
    if (customer.id == null) throw Exception('Customer id required');
    final row = await _client
        .from('customers')
        .update(customer.toMap())
        .eq('id', customer.id!)
        .select()
        .single();
    invalidateCache();
    return (await getById(asInt(row['id'])!))!;
  }

  Future<void> delete(int id) async {
    final inv = await _client
        .from('invoices')
        .select('id')
        .eq('customer_id', id)
        .limit(1);
    if ((inv as List).isNotEmpty) {
      throw Exception('لا يمكن حذف العميل لوجود فواتير مرتبطة');
    }
    await _client.from('customers').delete().eq('id', id);
    invalidateCache();
  }

  Future<int> getOrCreateAccountAnchorInvoice(int customerId) async {
    final existing = await _client
        .from('invoices')
        .select()
        .eq('customer_id', customerId)
        .eq('payment_method', 'account')
        .eq('final_amount', 0)
        .order('id')
        .limit(20);

    final list = List<Map<String, dynamic>>.from(existing as List);
    for (final row in list) {
      final id = asInt(row['id']);
      if (id == null) continue;
      final sales = await _client
          .from('sales')
          .select('id')
          .eq('invoice_id', id)
          .limit(1);
      if ((sales as List).isEmpty) return id;
    }

    final customer = await getById(customerId);
    final number =
        'ACC-$customerId-${DateTime.now().millisecondsSinceEpoch}';
    final row = await _client.from('invoices').insert({
      'invoice_number': number,
      'customer_id': customerId,
      'customer_name': customer?.name,
      'total_amount': 0,
      'discount_amount': 0,
      'final_amount': 0,
      'paid_amount': 0,
      'total_profit': 0,
      'payment_method': 'account',
      'notes': 'Account anchor',
      'sale_date': DateTime.now().toIso8601String(),
    }).select().single();
    return asInt(row['id'])!;
  }

  Future<void> recordPayment({
    required int customerId,
    required double amount,
    required DateTime paymentDate,
    String paymentMethod = 'cash',
    String? chequeNumber,
    String? notes,
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    final invoiceId = await getOrCreateAccountAnchorInvoice(customerId);
    await _client.from('customer_payments').insert({
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'amount': amount,
      'payment_date': paymentDate.toIso8601String(),
      'payment_method': paymentMethod,
      'cheque_number': chequeNumber,
      'notes': notes,
      'created_date': DateTime.now().toIso8601String(),
    });

    if (paymentMethod != 'discount') {
      final inv = await _client
          .from('invoices')
          .select('paid_amount')
          .eq('id', invoiceId)
          .single();
      final paid = asDouble(inv['paid_amount']) + amount;
      await _client
          .from('invoices')
          .update({'paid_amount': paid}).eq('id', invoiceId);
    }
    invalidateCache();
  }

  Future<void> recordAccountDiscount({
    required int customerId,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    await recordPayment(
      customerId: customerId,
      amount: amount,
      paymentDate: date,
      paymentMethod: 'discount',
      notes: notes ?? 'خصم على الحساب',
    );
  }

  Future<CustomerLedger> getLedger(
    int customerId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final customer = await getById(customerId);
    if (customer == null) throw Exception('العميل غير موجود');

    DateTime? fromStart =
        fromDate == null ? null : _dateOnly(fromDate);
    DateTime? toEnd = toDate == null
        ? null
        : DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);

    // Only the columns the ledger actually renders, and all three requests
    // run in parallel instead of one after the other.
    final responses = await Future.wait([
      _client
          .from('invoices')
          .select('id,invoice_number,final_amount,payment_method,notes,'
              'sale_date,created_date')
          .eq('customer_id', customerId)
          .order('sale_date'),
      _client
          .from('customer_payments')
          .select('id,invoice_id,amount,payment_date,payment_method,notes,'
              'invoices(invoice_number)')
          .eq('customer_id', customerId)
          .order('payment_date'),
      _client
          .from('sales')
          .select('id,invoice_id,product_name,quantity,sale_price,'
              'final_amount,note')
          .eq('customer_id', customerId),
    ]);

    final invoices = List<Map<String, dynamic>>.from(responses[0]);
    final payments = List<Map<String, dynamic>>.from(responses[1]);

    final salesByInvoice = <int, List<SaleLine>>{};
    for (final row in List<Map<String, dynamic>>.from(responses[2])) {
      final invId = asInt(row['invoice_id']);
      if (invId == null) continue;
      salesByInvoice.putIfAbsent(invId, () => []).add(SaleLine.fromMap(row));
    }

    double previousBalance = 0;
    if (fromStart != null) {
      for (final inv in invoices) {
        final date = asDate(inv['sale_date']) ?? asDate(inv['created_date']);
        if (date != null && _isBeforeDay(date, fromStart)) {
          previousBalance += asDouble(inv['final_amount']);
        }
      }
      for (final pay in payments) {
        final date = asDate(pay['payment_date']);
        if (date != null && _isBeforeDay(date, fromStart)) {
          previousBalance -= asDouble(pay['amount']);
        }
      }
      final adjDate = customer.createdDate ?? DateTime(2000);
      if (customer.balanceAdjustment != 0 &&
          _isBeforeDay(adjDate, fromStart)) {
        previousBalance += customer.balanceAdjustment;
      }
    }

    final entries = <LedgerEntry>[];

    if (customer.balanceAdjustment != 0) {
      final adjDate = customer.createdDate ?? DateTime(2000);
      final include = (fromStart == null || !_isBeforeDay(adjDate, fromStart)) &&
          (toEnd == null || !_isAfterDay(adjDate, toEnd));
      if (include) {
        entries.add(LedgerEntry(
          date: adjDate,
          documentType: LedgerDocType.manualAdjustment,
          documentNumber: 'ADJ-${customer.id}',
          debit:
              customer.balanceAdjustment > 0 ? customer.balanceAdjustment : 0,
          credit: customer.balanceAdjustment < 0
              ? customer.balanceAdjustment.abs()
              : 0,
          notes: 'تسوية رصيد',
        ));
      }
    }

    for (final inv in invoices) {
      final id = asInt(inv['id']);
      if (id == null) continue;
      final date = asDate(inv['sale_date']) ??
          asDate(inv['created_date']) ??
          DateTime.now();
      if (fromStart != null && _isBeforeDay(date, fromStart)) continue;
      if (toEnd != null && _isAfterDay(date, toEnd)) continue;

      final method = inv['payment_method'] as String? ?? 'cash';
      final finalAmount = asDouble(inv['final_amount']);
      final items = salesByInvoice[id] ?? [];
      if (method == 'account' && finalAmount == 0 && items.isEmpty) continue;

      entries.add(LedgerEntry(
        invoiceId: id,
        date: date,
        documentType: LedgerDocType.salesInvoice,
        documentNumber: _invoiceDoc(id),
        debit: finalAmount,
        invoiceNumber: inv['invoice_number'] as String?,
        notes: inv['notes'] as String?,
        lineItems: items,
      ));
    }

    for (final pay in payments) {
      final id = asInt(pay['id']);
      if (id == null) continue;
      final date = asDate(pay['payment_date']) ?? DateTime.now();
      if (fromStart != null && _isBeforeDay(date, fromStart)) continue;
      if (toEnd != null && _isAfterDay(date, toEnd)) continue;

      final method = pay['payment_method'] as String? ?? 'cash';
      final isDiscount = method == 'discount';
      final invJoin = pay['invoices'];
      String? invNumber;
      if (invJoin is Map) {
        invNumber = invJoin['invoice_number'] as String?;
      }

      entries.add(LedgerEntry(
        paymentId: id,
        invoiceId: asInt(pay['invoice_id']),
        date: date,
        documentType: isDiscount
            ? LedgerDocType.accountDiscount
            : LedgerDocType.paymentReceipt,
        documentNumber:
            isDiscount ? _discountDoc(id) : _receiptDoc(id),
        credit: asDouble(pay['amount']),
        notes: pay['notes'] as String?,
        invoiceNumber: invNumber,
        paymentMethod: method,
      ));
    }

    entries.sort((a, b) {
      final byDate = _dateOnly(a.date).compareTo(_dateOnly(b.date));
      if (byDate != 0) return byDate;
      // sales before credits
      int rank(LedgerDocType t) {
        switch (t) {
          case LedgerDocType.manualAdjustment:
            return 0;
          case LedgerDocType.salesInvoice:
            return 1;
          case LedgerDocType.accountDiscount:
            return 2;
          case LedgerDocType.paymentReceipt:
            return 3;
        }
      }

      return rank(a.documentType).compareTo(rank(b.documentType));
    });

    var running = previousBalance;
    var totalDebit = 0.0;
    var totalCredit = 0.0;
    final withBalance = <LedgerEntry>[];
    for (final e in entries) {
      running += e.debit - e.credit;
      totalDebit += e.debit;
      totalCredit += e.credit;
      withBalance.add(LedgerEntry(
        invoiceId: e.invoiceId,
        paymentId: e.paymentId,
        date: e.date,
        documentNumber: e.documentNumber,
        documentType: e.documentType,
        debit: e.debit,
        credit: e.credit,
        runningBalance: running,
        notes: e.notes,
        invoiceNumber: e.invoiceNumber,
        paymentMethod: e.paymentMethod,
        lineItems: e.lineItems,
      ));
    }

    return CustomerLedger(
      customer: customer,
      previousBalance: previousBalance,
      currentBalance: customer.balance,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      entries: withBalance,
    );
  }
}

extension on Customer {
  Customer copyWithBalance(double balance) => Customer(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        createdDate: createdDate,
        balance: balance,
        balanceAdjustment: balanceAdjustment,
      );
}
