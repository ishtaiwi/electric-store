import 'package:uuid/uuid.dart';
import '../../../../core/database/database_helper.dart';
import '../../../invoices/domain/entities/invoice.dart';
import '../../../invoices/domain/entities/sale_item.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/sales_repository.dart';

class SalesRepositoryImpl implements SalesRepository {
  final DatabaseHelper _databaseHelper;
  final _uuid = const Uuid();

  SalesRepositoryImpl(this._databaseHelper);

  @override
  Future<Invoice> createSale({
    required List<CartItem> items,
    int? customerId,
    double discountAmount = 0,
    String paymentMethod = 'cash',
    double? paidAmount,
    int? userId,
  }) async {
    final db = await _databaseHelper.database;

    // Calculate totals
    double totalAmount = 0;
    double totalProfit = 0;
    
    for (final item in items) {
      totalAmount += item.totalPrice;
      totalProfit += item.profit;
    }

    final finalAmount = totalAmount - discountAmount;
    totalProfit -= discountAmount; // Adjust profit for discount
    
    // If paidAmount not specified, default to full payment
    final actualPaidAmount = paidAmount ?? finalAmount;

    // Generate invoice number
    final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}-${_uuid.v4().substring(0, 4).toUpperCase()}';

    // Use a transaction to ensure all-or-nothing for data integrity
    late final int invoiceId;
    final List<SaleItem> saleItems = [];

    await db.transaction((txn) async {
      // Create invoice
      invoiceId = await txn.insert('invoices', {
        'invoice_number': invoiceNumber,
        'customer_id': customerId,
        'total_amount': totalAmount,
        'discount_amount': discountAmount,
        'final_amount': finalAmount,
        'paid_amount': actualPaidAmount,
        'total_profit': totalProfit,
        'payment_method': paymentMethod,
        'created_by': userId,
      });

      // Create sale items and update product quantities
      for (final item in items) {
        final itemTotal = item.totalPrice;
        // Avoid division by zero when totalAmount is 0
        final itemDiscount = totalAmount > 0 ? (discountAmount / totalAmount) * itemTotal : 0.0;
        final itemFinal = itemTotal - itemDiscount;
        final itemProfit = item.profit - itemDiscount;

        // Determine if this is a real product or a custom item
        final isRealProduct = item.product.id != null && item.product.id! > 0;

        // Insert sale record
        final saleId = await txn.insert('sales', {
          'product_id': isRealProduct ? item.product.id : null,
          'barcode': item.product.barcode,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'cost_price': item.product.costPrice,
          'sale_price': item.unitPrice,
          'total_amount': itemTotal,
          'profit': itemProfit,
          'customer_id': customerId,
          'discount_amount': itemDiscount,
          'final_amount': itemFinal,
          'invoice_id': invoiceId,
        });

        // Update product quantity only for real products (not custom items)
        if (isRealProduct) {
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity - ?, last_updated = ? WHERE id = ?',
            [item.quantity, DateTime.now().toIso8601String(), item.product.id],
          );
        }

        saleItems.add(SaleItem(
          id: saleId,
          productId: isRealProduct ? item.product.id : null,
          barcode: item.product.barcode,
          productName: item.product.name,
          quantity: item.quantity,
          costPrice: item.product.costPrice,
          salePrice: item.unitPrice,
          totalAmount: itemTotal,
          profit: itemProfit,
          discountAmount: itemDiscount,
          finalAmount: itemFinal,
          invoiceId: invoiceId,
        ));
      }
    });

    return Invoice(
      id: invoiceId,
      invoiceNumber: invoiceNumber,
      customerId: customerId,
      totalAmount: totalAmount,
      discountAmount: discountAmount,
      finalAmount: finalAmount,
      paidAmount: actualPaidAmount,
      totalProfit: totalProfit,
      paymentMethod: paymentMethod,
      createdBy: userId,
      createdDate: DateTime.now(),
      saleDate: DateTime.now(),
      items: saleItems,
    );
  }

  @override
  Future<int> cancelSale(int saleId, String reason, int? userId) async {
    final db = await _databaseHelper.database;

    // Get sale details
    final sales = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [saleId],
    );

    if (sales.isEmpty) return 0;
    final sale = sales.first;

    return await db.transaction((txn) async {
      // Insert cancelled sale record
      await txn.insert('cancelled_sales', {
        'original_sale_id': saleId,
        'product_id': sale['product_id'],
        'barcode': sale['barcode'],
        'product_name': sale['product_name'],
        'quantity': sale['quantity'],
        'cost_price': sale['cost_price'],
        'sale_price': sale['sale_price'],
        'total_amount': sale['total_amount'],
        'profit': sale['profit'],
        'cancelled_by': userId,
        'reason': reason,
      });

      // Restore product quantity
      final quantity = sale['quantity'] as int? ?? 0;
      final productId = sale['product_id'];
      if (productId != null) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, last_updated = ? WHERE id = ?',
          [quantity, DateTime.now().toIso8601String(), productId],
        );
      }

      // Delete original sale
      return await txn.delete('sales', where: 'id = ?', whereArgs: [saleId]);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getSalesToday() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    return await db.rawQuery('''
      SELECT s.*, p.name as product_name_current
      FROM sales s
      LEFT JOIN products p ON s.product_id = p.id
      WHERE date(s.sale_date) = date(?)
      ORDER BY s.sale_date DESC
    ''', [startOfDay.toIso8601String()]);
  }

  @override
  Future<double> getTodaySalesTotal() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(final_amount), 0) as total
      FROM invoices
      WHERE date(created_date) = date(?)
    ''', [startOfDay.toIso8601String()]);
    
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  @override
  Future<double> getTodayProfit() async {
    final db = await _databaseHelper.database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(total_profit), 0) as profit
      FROM invoices
      WHERE date(created_date) = date(?)
    ''', [startOfDay.toIso8601String()]);
    
    return (result.first['profit'] as num?)?.toDouble() ?? 0;
  }
}
