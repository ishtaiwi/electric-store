import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import 'localization_service.dart';
import 'smart_search_service.dart';

/// Chatbot message model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  final ChatMessageType type;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.data,
    this.type = ChatMessageType.text,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ChatMessageType {
  text,
  productList,
  customerInfo,
  invoiceInfo,
  salesReport,
  error,
}

/// Intent types the chatbot can understand
enum ChatIntent {
  greeting,
  customerBalance,
  customerInfo,
  productStock,
  productPrice,
  productSearch,
  todaySales,
  monthSales,
  topProducts,
  lowStock,
  totalDebt,
  invoiceInfo,
  help,
  unknown,
}

/// Chatbot Service for natural language queries
class ChatbotService {
  static final ChatbotService _instance = ChatbotService._internal();
  factory ChatbotService() => _instance;
  ChatbotService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  final LocalizationService _l10n = LocalizationService();
  final SmartSearchService _smartSearch = SmartSearchService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₪', decimalDigits: 2);
  
  bool _isInitialized = false;

  /// Initialize chatbot and learn from database
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _smartSearch.initialize();
    _isInitialized = true;
    debugPrint('Chatbot initialized with smart search');
  }

  /// Arabic number words for extraction
  final Map<String, int> _arabicNumbers = {
    'واحد': 1, 'اثنين': 2, 'ثلاثة': 3, 'أربعة': 4, 'خمسة': 5,
    'ستة': 6, 'سبعة': 7, 'ثمانية': 8, 'تسعة': 9, 'عشرة': 10,
    'عشر': 10, 'عشرين': 20, 'ثلاثين': 30, 'أربعين': 40, 'خمسين': 50,
    'مئة': 100, 'مية': 100, 'ميتين': 200, 'مئتين': 200,
  };

  /// Brand name variations for fuzzy matching
  final Map<String, List<String>> _brandVariations = {
    'ليبر': ['ليبر', 'liber', 'liper', 'ليبير', 'لييبر', 'libr'],
    'فيتايا': ['فيتايا', 'vitaya', 'فيتاية', 'فتايا', 'فيتيا'],
    'سبسان': ['سبسان', 'sepsan', 'سيبسان', 'sibsan'],
    'لوتيكا': ['لوتيكا', 'lotica', 'لوطيكا', 'lotika'],
  };

  /// Product type synonyms
  final Map<String, List<String>> _productSynonyms = {
    'كشاف': ['كشاف', 'فلاش', 'ضوء', 'مصباح', 'لمبة', 'اضاءة', 'spotlight', 'flashlight'],
    'سلك': ['سلك', 'كيبل', 'كابل', 'موصل', 'wire', 'cable'],
    'مفتاح': ['مفتاح', 'سويتش', 'قاطع', 'switch'],
    'بريزة': ['بريزة', 'فيشة', 'مقبس', 'بلج', 'plug', 'socket'],
    'لمبة': ['لمبة', 'لمبه', 'مصباح', 'ضوء', 'bulb', 'lamp'],
  };

  /// Intent patterns for Arabic and English
  final Map<ChatIntent, List<RegExp>> _intentPatterns = {
    ChatIntent.greeting: [
      RegExp(r'^(مرحبا|السلام عليكم|اهلا|هاي|صباح الخير|مساء الخير)', caseSensitive: false),
      RegExp(r'^(hello|hi|hey|good morning|good evening)', caseSensitive: false),
    ],
    ChatIntent.customerBalance: [
      RegExp(r'(رصيد|ديون?|مديونية|حساب)\s*(العميل|الزبون|لـ?)?', caseSensitive: false),
      RegExp(r'(balance|debt|account)\s*(of|for)?\s*(customer)?', caseSensitive: false),
      RegExp(r'كم\s*(رصيد|على|عليه)', caseSensitive: false),
    ],
    ChatIntent.customerInfo: [
      RegExp(r'(معلومات|بيانات|تفاصيل)\s*(العميل|الزبون)', caseSensitive: false),
      RegExp(r'(customer|client)\s*(info|details|information)', caseSensitive: false),
    ],
    ChatIntent.productStock: [
      RegExp(r'(كم|كمية|مخزون|رصيد)\s*(المنتج|البضاعة|قطعة)?', caseSensitive: false),
      RegExp(r'(stock|quantity|how many)\s*(of|for)?', caseSensitive: false),
      RegExp(r'عندي\s*كم', caseSensitive: false),
    ],
    ChatIntent.productPrice: [
      RegExp(r'(سعر|بكم|ثمن)\s*(المنتج)?', caseSensitive: false),
      RegExp(r'(price|cost|how much)\s*(of|for)?', caseSensitive: false),
    ],
    ChatIntent.productSearch: [
      RegExp(r'(ابحث|بحث|جد|اعطني|وريني)\s*(عن|لي)?', caseSensitive: false),
      RegExp(r'(search|find|show|look)\s*(for)?', caseSensitive: false),
    ],
    ChatIntent.todaySales: [
      RegExp(r'(مبيعات|بيعات|ايرادات)\s*(اليوم|اليومية)?', caseSensitive: false),
      RegExp(r'(today|daily)\s*(sales|revenue)', caseSensitive: false),
      RegExp(r'كم\s*(بعت|بعنا)\s*اليوم', caseSensitive: false),
    ],
    ChatIntent.monthSales: [
      RegExp(r'(مبيعات|بيعات|ايرادات)\s*(الشهر|الشهرية)', caseSensitive: false),
      RegExp(r'(month|monthly)\s*(sales|revenue)', caseSensitive: false),
    ],
    ChatIntent.topProducts: [
      RegExp(r'(أكثر|اكثر|افضل|أفضل)\s*(المنتجات|البضاعة)?\s*(مبيعا|بيعا)', caseSensitive: false),
      RegExp(r'(top|best)\s*(selling|sold)\s*(products)?', caseSensitive: false),
    ],
    ChatIntent.lowStock: [
      RegExp(r'(قليل|نقص|منخفض|ناقص)\s*(المخزون|البضاعة)', caseSensitive: false),
      RegExp(r'(low|out of)\s*stock', caseSensitive: false),
      RegExp(r'(منتجات|بضاعة)\s*(قليلة|ناقصة|خالصة)', caseSensitive: false),
    ],
    ChatIntent.totalDebt: [
      RegExp(r'(مجموع|اجمالي|كل)\s*(الديون|المديونيات|الذمم)', caseSensitive: false),
      RegExp(r'total\s*(debt|debts|receivables)', caseSensitive: false),
    ],
    ChatIntent.invoiceInfo: [
      RegExp(r'(فاتورة|فواتير)\s*(رقم)?', caseSensitive: false),
      RegExp(r'invoice\s*(number|#)?', caseSensitive: false),
    ],
    ChatIntent.help: [
      RegExp(r'^(مساعدة|ساعدني|كيف|شو اقدر|ماذا يمكن)', caseSensitive: false),
      RegExp(r'^(help|what can you|how to)', caseSensitive: false),
    ],
  };

  /// Process user message and generate response
  Future<ChatMessage> processMessage(String userMessage) async {
    // Ensure initialized with database learning
    await initialize();
    
    try {
      final intent = _detectIntent(userMessage);
      final entities = _extractEntities(userMessage);
      
      debugPrint('Intent: $intent, Entities: $entities');
      
      switch (intent) {
        case ChatIntent.greeting:
          return _handleGreeting();
        case ChatIntent.customerBalance:
          return await _handleCustomerBalance(entities);
        case ChatIntent.customerInfo:
          return await _handleCustomerInfo(entities);
        case ChatIntent.productStock:
          return await _handleProductStock(entities);
        case ChatIntent.productPrice:
          return await _handleProductPrice(entities);
        case ChatIntent.productSearch:
          return await _handleProductSearch(entities);
        case ChatIntent.todaySales:
          return await _handleTodaySales();
        case ChatIntent.monthSales:
          return await _handleMonthSales();
        case ChatIntent.topProducts:
          return await _handleTopProducts();
        case ChatIntent.lowStock:
          return await _handleLowStock();
        case ChatIntent.totalDebt:
          return await _handleTotalDebt();
        case ChatIntent.invoiceInfo:
          return await _handleInvoiceInfo(entities);
        case ChatIntent.help:
          return _handleHelp();
        case ChatIntent.unknown:
        default:
          return await _handleUnknown(userMessage);
      }
    } catch (e) {
      debugPrint('Chatbot error: $e');
      return ChatMessage(
        text: 'حدث خطأ أثناء معالجة طلبك. حاول مرة أخرى.',
        isUser: false,
        type: ChatMessageType.error,
      );
    }
  }

  /// Detect intent from message
  ChatIntent _detectIntent(String message) {
    for (final entry in _intentPatterns.entries) {
      for (final pattern in entry.value) {
        if (pattern.hasMatch(message)) {
          return entry.key;
        }
      }
    }
    return ChatIntent.unknown;
  }

  /// Extract entities with intelligent parsing
  Map<String, dynamic> _extractEntities(String message) {
    final entities = <String, dynamic>{};
    
    // Extract wattage (e.g., "100 واط", "100w", "مية واط")
    final wattage = _extractWattage(message);
    if (wattage != null) {
      entities['wattage'] = wattage;
    }
    
    // Extract brand name
    final brand = _extractBrand(message);
    if (brand != null) {
      entities['brand'] = brand;
    }
    
    // Extract product type
    final productType = _extractProductType(message);
    if (productType != null) {
      entities['productType'] = productType;
    }
    
    // Extract customer/product name (words after keywords)
    final namePatterns = [
      RegExp(r'(?:العميل|الزبون|customer|client)\s+([^\d]{2,})', caseSensitive: false),
      RegExp(r'(?:المنتج|product)\s+([^\d]{2,})', caseSensitive: false),
    ];
    
    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        entities['name'] = match.group(1)?.trim();
        break;
      }
    }
    
    // Extract numbers
    final numberMatch = RegExp(r'\d+').firstMatch(message);
    if (numberMatch != null) {
      entities['number'] = int.tryParse(numberMatch.group(0)!);
    }
    
    // Build intelligent search term from extracted entities
    final searchParts = <String>[];
    if (productType != null) searchParts.add(productType);
    if (brand != null) searchParts.add(brand);
    if (wattage != null) searchParts.add('$wattage');
    
    if (searchParts.isNotEmpty) {
      entities['smartSearchTerm'] = searchParts.join(' ');
    }
    
    // If no specific name found, try to get meaningful words
    if (entities['name'] == null) {
      final words = message.split(RegExp(r'[\s،,]+'));
      final meaningfulWords = words.where((w) => 
        w.length >= 2 && 
        !_isStopWord(w)
      ).toList();
      if (meaningfulWords.isNotEmpty) {
        entities['searchTerm'] = meaningfulWords.join(' ');
      }
    }
    
    return entities;
  }

  /// Extract wattage from message
  int? _extractWattage(String message) {
    // Pattern: number followed by واط/وات/w/W
    final patterns = [
      RegExp(r'(\d+)\s*(?:واط|وات|w)', caseSensitive: false),
      RegExp(r'(\d+)\s*watt', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(message);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    
    // Check Arabic number words (e.g., "مية واط")
    for (final entry in _arabicNumbers.entries) {
      if (message.contains(entry.key) && message.contains(RegExp(r'واط|وات'))) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Extract brand name from message
  String? _extractBrand(String message) {
    final lowerMessage = message.toLowerCase();
    for (final entry in _brandVariations.entries) {
      for (final variant in entry.value) {
        if (lowerMessage.contains(variant.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Extract product type from message
  String? _extractProductType(String message) {
    final lowerMessage = message.toLowerCase();
    for (final entry in _productSynonyms.entries) {
      for (final synonym in entry.value) {
        if (lowerMessage.contains(synonym.toLowerCase())) {
          return entry.key;
        }
      }
    }
    return null;
  }

  bool _isStopWord(String word) {
    const stopWords = [
      'كم', 'رصيد', 'ديون', 'العميل', 'الزبون', 'سعر', 'مخزون', 'كمية',
      'اعطني', 'وريني', 'ابحث', 'عن', 'لي', 'من', 'في', 'على', 'إلى',
      'the', 'of', 'for', 'what', 'how', 'is', 'are', 'customer', 'product'
    ];
    return stopWords.contains(word.toLowerCase());
  }

  // Handler implementations
  ChatMessage _handleGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'صباح الخير! ';
    } else if (hour < 18) {
      greeting = 'مساء الخير! ';
    } else {
      greeting = 'مساء النور! ';
    }
    return ChatMessage(
      text: '$greeting كيف يمكنني مساعدتك اليوم؟',
      isUser: false,
    );
  }

  Future<ChatMessage> _handleCustomerBalance(Map<String, dynamic> entities) async {
    final searchTerm = entities['name'] ?? entities['searchTerm'];
    if (searchTerm == null) {
      return ChatMessage(
        text: 'من فضلك حدد اسم العميل. مثال: "رصيد العميل محمد"',
        isUser: false,
      );
    }

    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT c.id, c.name, c.phone, c.balance_adjustment,
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) as invoice_debt
      FROM customers c
      LEFT JOIN invoices i ON c.id = i.customer_id
      WHERE c.name LIKE ?
      GROUP BY c.id
      LIMIT 5
    ''', ['%$searchTerm%']);

    if (results.isEmpty) {
      return ChatMessage(
        text: 'لم أجد عميل باسم "$searchTerm"',
        isUser: false,
      );
    }

    if (results.length == 1) {
      final customer = results.first;
      final invoiceDebt = (customer['invoice_debt'] as num?)?.toDouble() ?? 0;
      final adjustment = (customer['balance_adjustment'] as num?)?.toDouble() ?? 0;
      final totalBalance = invoiceDebt + adjustment;
      
      return ChatMessage(
        text: '''
📋 **${customer['name']}**
├ الهاتف: ${customer['phone'] ?? 'غير محدد'}
├ ديون الفواتير: ${_currencyFormat.format(invoiceDebt)}
├ تعديل الرصيد: ${_currencyFormat.format(adjustment)}
└ **الرصيد الإجمالي: ${_currencyFormat.format(totalBalance)}**
''',
        isUser: false,
        type: ChatMessageType.customerInfo,
        data: {'customer': customer, 'balance': totalBalance},
      );
    }

    // Multiple matches
    final customerList = results.map((c) {
      final debt = ((c['invoice_debt'] as num?)?.toDouble() ?? 0) + 
                   ((c['balance_adjustment'] as num?)?.toDouble() ?? 0);
      return '• ${c['name']}: ${_currencyFormat.format(debt)}';
    }).join('\n');

    return ChatMessage(
      text: 'وجدت ${results.length} عملاء:\n$customerList',
      isUser: false,
      type: ChatMessageType.customerInfo,
    );
  }

  Future<ChatMessage> _handleCustomerInfo(Map<String, dynamic> entities) async {
    return _handleCustomerBalance(entities);
  }

  Future<ChatMessage> _handleProductStock(Map<String, dynamic> entities) async {
    // Build intelligent search term
    final smartTerm = entities['smartSearchTerm'];
    final searchTerm = smartTerm ?? entities['name'] ?? entities['searchTerm'];
    
    if (searchTerm == null) {
      return ChatMessage(
        text: 'من فضلك حدد اسم المنتج. مثال: "كم مخزون كشاف ليبر"\n\n💡 يمكنني فهم:\n• الأرقام العربية (مية واط)\n• أسماء الماركات (ليبر، فيتايا)\n• أنواع المنتجات (كشاف، لمبة، سلك)',
        isUser: false,
      );
    }

    // Use smart search for fuzzy matching
    final results = await _smartSearch.smartSearchProducts(searchTerm.toString());

    if (results.isEmpty) {
      // Try suggestions
      final suggestions = await _smartSearch.getSuggestions(searchTerm.toString());
      if (suggestions.isNotEmpty) {
        return ChatMessage(
          text: 'لم أجد "$searchTerm" بالضبط\n\n💡 هل تقصد:\n${suggestions.take(5).map((s) => '• $s').join('\n')}',
          isUser: false,
        );
      }
      return ChatMessage(
        text: 'لم أجد منتج مطابق لـ "$searchTerm"\n\n💡 جرب:\n• كشاف ليبر 100 واط\n• لمبة فيتايا\n• سلك 2.5',
        isUser: false,
      );
    }

    if (results.length == 1) {
      final product = results.first;
      final qty = product['quantity'] as int? ?? 0;
      final status = qty > 10 ? '✅' : (qty > 0 ? '⚠️' : '❌');
      return ChatMessage(
        text: '$status **${product['name']}**\nالمخزون: $qty قطعة\nالسعر: ${_currencyFormat.format(product['price'])}',
        isUser: false,
        type: ChatMessageType.productList,
        data: {'products': results},
      );
    }

    // Show best matches (sorted by relevance)
    final topResults = results.take(10).toList();
    final productList = topResults.map((p) {
      final qty = p['quantity'] as int? ?? 0;
      final status = qty > 10 ? '✅' : (qty > 0 ? '⚠️' : '❌');
      return '$status ${p['name']}: $qty قطعة';
    }).join('\n');

    return ChatMessage(
      text: '🔍 وجدت ${results.length} منتج مطابق:\n\n$productList',
      isUser: false,
      type: ChatMessageType.productList,
      data: {'products': topResults},
    );
  }

  Future<ChatMessage> _handleProductPrice(Map<String, dynamic> entities) async {
    // Build intelligent search term
    final smartTerm = entities['smartSearchTerm'];
    final searchTerm = smartTerm ?? entities['name'] ?? entities['searchTerm'];
    
    if (searchTerm == null) {
      return ChatMessage(
        text: 'من فضلك حدد اسم المنتج. مثال: "سعر كشاف ليبر 100 واط"\n\n💡 يمكنني فهم:\n• الأرقام العربية (مية واط)\n• أسماء الماركات (ليبر، فيتايا)\n• أنواع المنتجات (كشاف، لمبة، سلك)',
        isUser: false,
      );
    }

    // Use smart search for fuzzy matching
    final results = await _smartSearch.smartSearchProducts(searchTerm.toString());

    if (results.isEmpty) {
      // Try suggestions
      final suggestions = await _smartSearch.getSuggestions(searchTerm.toString());
      if (suggestions.isNotEmpty) {
        return ChatMessage(
          text: 'لم أجد "$searchTerm" بالضبط\n\n💡 هل تقصد:\n${suggestions.take(5).map((s) => '• $s').join('\n')}',
          isUser: false,
        );
      }
      return ChatMessage(
        text: 'لم أجد منتج مطابق لـ "$searchTerm"',
        isUser: false,
      );
    }

    if (results.length == 1) {
      final product = results.first;
      final price = (product['price'] as num?)?.toDouble() ?? 0;
      final cost = (product['cost_price'] as num?)?.toDouble() ?? 0;
      final profit = price - cost;
      return ChatMessage(
        text: '''
💰 **${product['name']}**
├ سعر البيع: ${_currencyFormat.format(price)}
├ سعر التكلفة: ${_currencyFormat.format(cost)}
├ الربح: ${_currencyFormat.format(profit)}
└ المخزون: ${product['quantity']} قطعة
''',
        isUser: false,
        type: ChatMessageType.productList,
        data: {'products': results},
      );
    }

    // Show best matches with prices
    final topResults = results.take(10).toList();
    final productList = topResults.map((p) => 
      '• ${p['name']}: ${_currencyFormat.format(p['price'])}'
    ).join('\n');

    return ChatMessage(
      text: 'الأسعار:\n$productList',
      isUser: false,
      type: ChatMessageType.productList,
    );
  }

  Future<ChatMessage> _handleProductSearch(Map<String, dynamic> entities) async {
    // Build intelligent search term
    final smartTerm = entities['smartSearchTerm'];
    final searchTerm = smartTerm ?? entities['name'] ?? entities['searchTerm'];
    
    if (searchTerm == null) {
      return ChatMessage(
        text: 'ابحث عن أي منتج! مثال:\n• "كشاف ليبر"\n• "لمبة 100 واط"\n• "سلك 2.5"\n\n💡 يمكنني فهم العربية والإنجليزية معاً',
        isUser: false,
      );
    }

    // Use smart search for fuzzy matching
    final results = await _smartSearch.smartSearchProducts(searchTerm.toString());

    if (results.isEmpty) {
      final suggestions = await _smartSearch.getSuggestions(searchTerm.toString());
      if (suggestions.isNotEmpty) {
        return ChatMessage(
          text: 'لم أجد "$searchTerm"\n\n💡 اقتراحات:\n${suggestions.take(5).map((s) => '• $s').join('\n')}',
          isUser: false,
        );
      }
      return ChatMessage(
        text: 'لم أجد منتج مطابق. جرب كلمات مختلفة.',
        isUser: false,
      );
    }

    // Show comprehensive results
    final topResults = results.take(15).toList();
    final buffer = StringBuffer('🔍 نتائج البحث عن "$searchTerm":\n\n');
    
    for (final p in topResults) {
      final qty = p['quantity'] as int? ?? 0;
      final status = qty > 10 ? '✅' : (qty > 0 ? '⚠️' : '❌');
      buffer.writeln('$status **${p['name']}**');
      buffer.writeln('   السعر: ${_currencyFormat.format(p['price'])} | المخزون: $qty');
    }
    
    if (results.length > 15) {
      buffer.writeln('\n... و ${results.length - 15} منتج آخر');
    }

    return ChatMessage(
      text: buffer.toString(),
      isUser: false,
      type: ChatMessageType.productList,
      data: {'products': topResults, 'totalCount': results.length},
    );
  }

  Future<ChatMessage> _handleTodaySales() async {
    final db = await _db.database;
    final today = _dateFormat.format(DateTime.now());
    
    final results = await Future.wait([
      db.rawQuery('''
        SELECT 
          COUNT(*) as invoice_count,
          COALESCE(SUM(final_amount), 0) as total_sales,
          COALESCE(SUM(paid_amount), 0) as total_paid
        FROM invoices 
        WHERE date(created_date) = date(?)
      ''', [today]),
      db.rawQuery('''
        SELECT COALESCE(SUM(profit), 0) as total_profit
        FROM sales
        WHERE date(sale_date) = date(?)
          AND product_id IS NOT NULL
      ''', [today]),
    ]);

    final data = results[0].first;
    final invoiceCount = data['invoice_count'] as int;
    final totalSales = (data['total_sales'] as num?)?.toDouble() ?? 0;
    final totalProfit = (results[1].first['total_profit'] as num?)?.toDouble() ?? 0;
    final totalPaid = (data['total_paid'] as num?)?.toDouble() ?? 0;
    final unpaid = totalSales - totalPaid;

    return ChatMessage(
      text: '''
📊 **مبيعات اليوم** ($today)
├ عدد الفواتير: $invoiceCount
├ إجمالي المبيعات: ${_currencyFormat.format(totalSales)}
├ المدفوع: ${_currencyFormat.format(totalPaid)}
├ الآجل: ${_currencyFormat.format(unpaid)}
└ **الربح: ${_currencyFormat.format(totalProfit)}**
''',
      isUser: false,
      type: ChatMessageType.salesReport,
    );
  }

  Future<ChatMessage> _handleMonthSales() async {
    final db = await _db.database;
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as invoice_count,
        COALESCE(SUM(final_amount), 0) as total_sales,
        COALESCE(SUM(total_profit), 0) as total_profit
      FROM invoices 
      WHERE date(created_date) >= date(?)
    ''', [_dateFormat.format(firstOfMonth)]);

    final data = result.first;
    final invoiceCount = data['invoice_count'] as int;
    final totalSales = (data['total_sales'] as num?)?.toDouble() ?? 0;
    final totalProfit = (data['total_profit'] as num?)?.toDouble() ?? 0;

    return ChatMessage(
      text: '''
📊 **مبيعات الشهر** (${DateFormat('MMMM yyyy').format(now)})
├ عدد الفواتير: $invoiceCount
├ إجمالي المبيعات: ${_currencyFormat.format(totalSales)}
└ **الربح: ${_currencyFormat.format(totalProfit)}**
''',
      isUser: false,
      type: ChatMessageType.salesReport,
    );
  }

  Future<ChatMessage> _handleTopProducts() async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT product_name, SUM(quantity) as total_qty, SUM(total_amount) as total_sales
      FROM sales 
      WHERE date(sale_date) >= date('now', '-30 days')
      GROUP BY product_id
      ORDER BY total_qty DESC
      LIMIT 5
    ''');

    if (results.isEmpty) {
      return ChatMessage(
        text: 'لا توجد مبيعات في الـ 30 يوم الماضية',
        isUser: false,
      );
    }

    final productList = results.asMap().entries.map((e) {
      final i = e.key + 1;
      final p = e.value;
      return '$i. ${p['product_name']} - ${p['total_qty']} قطعة (${_currencyFormat.format(p['total_sales'])})';
    }).join('\n');

    return ChatMessage(
      text: '🏆 **أكثر المنتجات مبيعاً (30 يوم)**\n$productList',
      isUser: false,
      type: ChatMessageType.productList,
    );
  }

  Future<ChatMessage> _handleLowStock() async {
    final db = await _db.database;
    
    final results = await db.rawQuery('''
      SELECT name, quantity, min_stock 
      FROM products 
      WHERE quantity <= min_stock AND quantity > 0
      ORDER BY quantity ASC
      LIMIT 10
    ''');

    final outOfStock = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE quantity = 0'
    );
    final outCount = outOfStock.first['count'] as int;

    if (results.isEmpty && outCount == 0) {
      return ChatMessage(
        text: '✅ جميع المنتجات متوفرة بكميات كافية',
        isUser: false,
      );
    }

    var text = '';
    if (outCount > 0) {
      text += '❌ **$outCount منتج نفد من المخزون**\n\n';
    }
    
    if (results.isNotEmpty) {
      text += '⚠️ **منتجات قليلة المخزون:**\n';
      text += results.map((p) => 
        '• ${p['name']}: ${p['quantity']}/${p['min_stock']}'
      ).join('\n');
    }

    return ChatMessage(
      text: text,
      isUser: false,
      type: ChatMessageType.productList,
    );
  }

  Future<ChatMessage> _handleTotalDebt() async {
    final db = await _db.database;
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT c.id) as customer_count,
        COALESCE(SUM(i.final_amount - i.paid_amount), 0) as total_debt
      FROM customers c
      JOIN invoices i ON c.id = i.customer_id
      WHERE i.final_amount > i.paid_amount
    ''');

    final data = result.first;
    final customerCount = data['customer_count'] as int;
    final totalDebt = (data['total_debt'] as num?)?.toDouble() ?? 0;

    // Get top 5 debtors
    final topDebtors = await db.rawQuery('''
      SELECT c.name, SUM(i.final_amount - i.paid_amount) as debt
      FROM customers c
      JOIN invoices i ON c.id = i.customer_id
      WHERE i.final_amount > i.paid_amount
      GROUP BY c.id
      ORDER BY debt DESC
      LIMIT 5
    ''');

    var text = '''
💳 **إجمالي الذمم المدينة**
├ عدد العملاء المدينين: $customerCount
└ **إجمالي الديون: ${_currencyFormat.format(totalDebt)}**
''';

    if (topDebtors.isNotEmpty) {
      text += '\n📋 **أكبر المدينين:**\n';
      text += topDebtors.map((d) => 
        '• ${d['name']}: ${_currencyFormat.format(d['debt'])}'
      ).join('\n');
    }

    return ChatMessage(
      text: text,
      isUser: false,
      type: ChatMessageType.customerInfo,
    );
  }

  Future<ChatMessage> _handleInvoiceInfo(Map<String, dynamic> entities) async {
    final invoiceNumber = entities['number'];
    if (invoiceNumber == null) {
      return ChatMessage(
        text: 'من فضلك حدد رقم الفاتورة. مثال: "فاتورة رقم 123"',
        isUser: false,
      );
    }

    final db = await _db.database;
    final results = await db.rawQuery('''
      SELECT i.*, c.name as customer_name
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      WHERE i.id = ? OR i.invoice_number LIKE ?
      LIMIT 1
    ''', [invoiceNumber, '%$invoiceNumber%']);

    if (results.isEmpty) {
      return ChatMessage(
        text: 'لم أجد فاتورة برقم "$invoiceNumber"',
        isUser: false,
      );
    }

    final inv = results.first;
    final finalAmount = (inv['final_amount'] as num).toDouble();
    final paidAmount = (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    final remaining = finalAmount - paidAmount;
    final status = remaining <= 0 ? '✅ مدفوعة' : '⏳ آجل: ${_currencyFormat.format(remaining)}';

    return ChatMessage(
      text: '''
🧾 **فاتورة #${inv['invoice_number']}**
├ العميل: ${inv['customer_name'] ?? 'زبون نقدي'}
├ التاريخ: ${inv['created_date']}
├ المبلغ: ${_currencyFormat.format(finalAmount)}
├ المدفوع: ${_currencyFormat.format(paidAmount)}
└ $status
''',
      isUser: false,
      type: ChatMessageType.invoiceInfo,
    );
  }

  ChatMessage _handleHelp() {
    return ChatMessage(
      text: '''
🤖 **أنا مساعدك الذكي! يمكنني مساعدتك في:**

� **البحث الذكي عن المنتجات:**
• اكتب اسم أي منتج وسأجده لك
• أفهم الأخطاء الإملائية (liber = ليبر)
• أفهم الأرقام العربية (مية واط = 100 واط)
• أفهم المرادفات (كشاف = فلاش = سبوت)
• مثال: "كشاف ليبر مية واط ابيض"
• مثال: "liper 50w" أو "فيتايا لمبة"

📋 **العملاء:**
• "رصيد محمد" أو "كم على أحمد"
• "معلومات العميل علي"

📊 **التقارير:**
• "مبيعات اليوم" / "مبيعات الشهر"
• "أكثر المنتجات مبيعاً"
• "منتجات قليلة المخزون"
• "إجمالي الديون"

🧾 **الفواتير:**
• "فاتورة 123"

💡 **نصيحة:** اكتب أي كلمة وسأحاول إيجاد المنتج المناسب!
''',
      isUser: false,
    );
  }

  Future<ChatMessage> _handleUnknown(String message) async {
    // Try smart search first - maybe user is looking for a product
    final results = await _smartSearch.smartSearchProducts(message);
    
    if (results.isNotEmpty) {
      // Found products - show them
      final topResults = results.take(5).toList();
      final productList = topResults.map((p) {
        final qty = p['quantity'] as int? ?? 0;
        final status = qty > 10 ? '✅' : (qty > 0 ? '⚠️' : '❌');
        return '$status ${p['name']}: ${_currencyFormat.format(p['price'])} (مخزون: $qty)';
      }).join('\n');
      
      return ChatMessage(
        text: '🔍 وجدت منتجات مطابقة:\n\n$productList',
        isUser: false,
        type: ChatMessageType.productList,
        data: {'products': topResults},
      );
    }
    
    // Try suggestions
    final suggestions = await _smartSearch.getSuggestions(message);
    if (suggestions.isNotEmpty) {
      return ChatMessage(
        text: 'لم أفهم طلبك بالضبط\n\n💡 هل تقصد:\n${suggestions.take(5).map((s) => '• $s').join('\n')}\n\nاكتب "مساعدة" لمعرفة ما يمكنني فعله.',
        isUser: false,
      );
    }
    
    return ChatMessage(
      text: 'لم أفهم طلبك. اكتب "مساعدة" لمعرفة ما يمكنني فعله.',
      isUser: false,
    );
  }
}
