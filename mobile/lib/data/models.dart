import '../core/utils/helpers.dart';

/// One slice of a server-side paginated list.
class PagedResult<T> {
  final List<T> items;
  final bool hasMore;

  const PagedResult({required this.items, required this.hasMore});

  static PagedResult<T> empty<T>() =>
      PagedResult<T>(items: const [], hasMore: false);
}

class AppUser {
  final int id;
  final String username;
  final String role;
  final String? fullName;

  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: asInt(map['id'])!,
        username: map['username'] as String,
        role: map['role'] as String? ?? 'cashier',
        fullName: map['full_name'] as String?,
      );
}

class Product {
  final int? id;
  final String name;
  final String? barcode;
  final int quantity;
  final double price;
  final double costPrice;
  final String? note;
  /// Brand / make (النوع)
  final String? brand;
  /// Product class (الصنف)
  final String? category;
  final String? supplier;
  final int? supplierId;
  final int minStock;
  /// Public Supabase Storage URL
  final String? imageUrl;
  final DateTime? lastUpdated;

  const Product({
    this.id,
    required this.name,
    this.barcode,
    required this.quantity,
    required this.price,
    required this.costPrice,
    this.note,
    this.brand,
    this.category,
    this.supplier,
    this.supplierId,
    this.minStock = 5,
    this.imageUrl,
    this.lastUpdated,
  });

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: asInt(map['id']),
        name: map['name'] as String? ?? '',
        barcode: map['barcode'] as String?,
        quantity: asInt(map['quantity']) ?? 0,
        price: asDouble(map['price']),
        costPrice: asDouble(map['cost_price']),
        note: map['note'] as String?,
        brand: map['brand'] as String?,
        category: map['category'] as String?,
        supplier: map['supplier'] as String?,
        supplierId: asInt(map['supplier_id']),
        minStock: asInt(map['min_stock']) ?? 5,
        imageUrl: map['image_url'] as String?,
        lastUpdated: asDate(map['last_updated']),
      );

  Map<String, dynamic> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'name': name,
        'barcode': barcode,
        'quantity': quantity,
        'price': price,
        'cost_price': costPrice,
        'note': note,
        'brand': brand,
        'category': category,
        'supplier': supplier,
        'supplier_id': supplierId,
        'min_stock': minStock,
        'image_url': imageUrl,
        'last_updated': DateTime.now().toIso8601String(),
      };

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? quantity,
    double? price,
    double? costPrice,
    String? note,
    String? brand,
    String? category,
    String? supplier,
    int? supplierId,
    int? minStock,
    String? imageUrl,
    DateTime? lastUpdated,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        costPrice: costPrice ?? this.costPrice,
        note: note ?? this.note,
        brand: brand ?? this.brand,
        category: category ?? this.category,
        supplier: supplier ?? this.supplier,
        supplierId: supplierId ?? this.supplierId,
        minStock: minStock ?? this.minStock,
        imageUrl: imageUrl ?? this.imageUrl,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );

  bool get isLowStock => quantity <= minStock;
  bool get isOutOfStock => quantity <= 0;
  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
}

class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime? createdDate;
  final double balance;
  final double balanceAdjustment;

  const Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.createdDate,
    this.balance = 0,
    this.balanceAdjustment = 0,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: asInt(map['id']),
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        createdDate: asDate(map['created_date']),
        balance: asDouble(map['balance']),
        balanceAdjustment: asDouble(map['balance_adjustment']),
      );

  Map<String, dynamic> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'balance_adjustment': balanceAdjustment,
      };

  bool get hasDebt => balance > 0;
  bool get hasCredit => balance < 0;
  String get code =>
      id == null ? '' : 'CUST-${id.toString().padLeft(4, '0')}';
}

class CartLine {
  final Product product;
  final int quantity;
  final double? customPrice;
  final String? note;

  const CartLine({
    required this.product,
    this.quantity = 1,
    this.customPrice,
    this.note,
  });

  double get unitPrice => customPrice ?? product.price;
  double get totalPrice => unitPrice * quantity;
  double get totalCost => product.costPrice * quantity;
  double get profit => totalPrice - totalCost;

  CartLine copyWith({
    Product? product,
    int? quantity,
    double? customPrice,
    bool clearCustomPrice = false,
    String? note,
    bool clearNote = false,
  }) {
    return CartLine(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      customPrice: clearCustomPrice ? null : (customPrice ?? this.customPrice),
      note: clearNote ? null : (note ?? this.note),
    );
  }
}

class CreatedInvoice {
  final int id;
  final String invoiceNumber;
  final int? customerId;
  final String? customerName;
  final double totalAmount;
  final double discountAmount;
  final double finalAmount;
  final double paidAmount;
  final String paymentMethod;
  final DateTime? saleDate;

  const CreatedInvoice({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    required this.totalAmount,
    this.discountAmount = 0,
    required this.finalAmount,
    this.paidAmount = 0,
    required this.paymentMethod,
    this.saleDate,
  });
}

class SaleLine {
  final int? id;
  final int? invoiceId;
  final String productName;
  final int quantity;
  final double salePrice;
  final double finalAmount;
  final String? note;

  const SaleLine({
    this.id,
    this.invoiceId,
    required this.productName,
    required this.quantity,
    required this.salePrice,
    required this.finalAmount,
    this.note,
  });

  factory SaleLine.fromMap(Map<String, dynamic> map) => SaleLine(
        id: asInt(map['id']),
        invoiceId: asInt(map['invoice_id']),
        productName: map['product_name'] as String? ?? '',
        quantity: asInt(map['quantity']) ?? 0,
        salePrice: asDouble(map['sale_price']),
        finalAmount: asDouble(map['final_amount']),
        note: map['note'] as String?,
      );
}

enum LedgerDocType {
  salesInvoice,
  paymentReceipt,
  accountDiscount,
  manualAdjustment,
}

class LedgerEntry {
  final int? invoiceId;
  final int? paymentId;
  final DateTime date;
  final String documentNumber;
  final LedgerDocType documentType;
  final double debit;
  final double credit;
  final double runningBalance;
  final String? notes;
  final String? invoiceNumber;
  final String? paymentMethod;
  final List<SaleLine> lineItems;

  const LedgerEntry({
    this.invoiceId,
    this.paymentId,
    required this.date,
    required this.documentNumber,
    required this.documentType,
    this.debit = 0,
    this.credit = 0,
    this.runningBalance = 0,
    this.notes,
    this.invoiceNumber,
    this.paymentMethod,
    this.lineItems = const [],
  });

  String get typeLabel {
    switch (documentType) {
      case LedgerDocType.salesInvoice:
        return 'فاتورة بيع';
      case LedgerDocType.paymentReceipt:
        return 'سند قبض';
      case LedgerDocType.accountDiscount:
        return 'خصم حساب';
      case LedgerDocType.manualAdjustment:
        return 'تسوية';
    }
  }
}

class CustomerLedger {
  final Customer customer;
  final double previousBalance;
  final double currentBalance;
  final double totalDebit;
  final double totalCredit;
  final List<LedgerEntry> entries;

  const CustomerLedger({
    required this.customer,
    required this.previousBalance,
    required this.currentBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.entries,
  });
}
