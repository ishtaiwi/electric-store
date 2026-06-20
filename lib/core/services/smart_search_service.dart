import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Smart Search Service with fuzzy matching, learning from database, and NLU
class SmartSearchService {
  static final SmartSearchService _instance = SmartSearchService._internal();
  factory SmartSearchService() => _instance;
  SmartSearchService._internal();

  final DatabaseHelper _db = DatabaseHelper();
  
  // Learned vocabulary from database
  Set<String> _learnedBrands = {};
  Set<String> _learnedTypes = {};
  Map<String, int> _wordFrequency = {};
  bool _isInitialized = false;

  /// Arabic to English number words mapping (expanded)
  final Map<String, int> _arabicNumbers = {
    'واحد': 1, 'اثنين': 2, 'اتنين': 2, 'ثلاثة': 3, 'تلاتة': 3,
    'أربعة': 4, 'اربعة': 4, 'خمسة': 5, 'ستة': 6, 'سبعة': 7,
    'ثمانية': 8, 'تسعة': 9, 'عشرة': 10, 'عشر': 10,
    'عشرين': 20, 'ثلاثين': 30, 'تلاتين': 30, 'أربعين': 40, 'اربعين': 40,
    'خمسين': 50, 'ستين': 60, 'سبعين': 70, 'ثمانين': 80, 'تسعين': 90,
    'مئة': 100, 'مية': 100, 'مائة': 100, 'ميه': 100,
    'ميتين': 200, 'مئتين': 200, 'متين': 200,
    'ثلاثمئة': 300, 'ثلاثمية': 300, 'تلتمية': 300,
    'أربعمئة': 400, 'اربعمية': 400,
    'خمسمئة': 500, 'خمسمية': 500,
  };

  /// Comprehensive Arabic product synonyms
  final Map<String, List<String>> _arabicSynonyms = {
    'كشاف': ['كشاف', 'فلاش', 'ضوء', 'مصباح', 'سبوت', 'spot', 'spotlight', 'فلود', 'flood', 'بروجكتر', 'projector'],
    'سلك': ['سلك', 'كيبل', 'كابل', 'موصل', 'wire', 'cable'],
    'مفتاح': ['مفتاح', 'سويتش', 'قاطع', 'switch', 'breaker'],
    'بريزة': ['بريزة', 'فيشة', 'مقبس', 'بلج', 'plug', 'socket', 'outlet'],
    'لمبة': ['لمبة', 'لمبه', 'مصباح', 'ضوء', 'اضاءة', 'إضاءة', 'bulb', 'lamp', 'led'],
    'طاقة شمسية': ['طاقة شمسية', 'سولار', 'شمسي', 'شمسية', 'solar'],
    'بطارية': ['بطارية', 'بطاريه', 'شحن', 'battery', 'باور بانك', 'powerbank'],
    'شريط': ['شريط', 'استريب', 'strip', 'ليد ستريب', 'led strip'],
    'ترانس': ['ترانس', 'محول', 'transformer', 'adapter', 'ادابتر', 'أدابتر'],
    'ريموت': ['ريموت', 'تحكم', 'remote', 'controller'],
    'سنسور': ['سنسور', 'حساس', 'sensor', 'motion'],
    'فيوز': ['فيوز', 'فيش', 'fuse', 'circuit'],
  };

  /// Brand name variations (expanded)
  final Map<String, List<String>> _brandVariations = {
    'ليبر': ['ليبر', 'liber', 'liper', 'ليبير', 'لييبر', 'libr', 'leiber'],
    'فيتايا': ['فيتايا', 'vitaya', 'فيتاية', 'فتايا', 'فيتيا', 'vitaia'],
    'سبسان': ['سبسان', 'sepsan', 'سيبسان', 'سيبسن', 'sibsan'],
    'لوتيكا': ['لوتيكا', 'lotica', 'لوطيكا', 'lotika', 'لوتكا'],
    'فيليبس': ['فيليبس', 'philips', 'فلبس', 'فيلبس'],
    'اوسرام': ['اوسرام', 'osram', 'أوسرام'],
    'جنرال': ['جنرال', 'general', 'جينرال'],
    'تويوتا': ['تويوتا', 'toyota'],
    'ناشونال': ['ناشونال', 'national', 'ناشيونال'],
    'باناسونيك': ['باناسونيك', 'panasonic', 'بناسونيك'],
  };

  /// Common Arabic character variations
  final Map<String, String> _arabicNormalization = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
    'ة': 'ه', 'ى': 'ي', 'ئ': 'ي', 'ؤ': 'و',
  };

  /// Initialize and learn from database
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final db = await _db.database;
      
      // Learn from existing product names
      final products = await db.rawQuery('SELECT name FROM products');
      
      for (final product in products) {
        final name = (product['name'] as String).toLowerCase();
        final words = name.split(RegExp(r'[\s\-_،,./]+'));
        
        for (final word in words) {
          if (word.length >= 2) {
            _wordFrequency[word] = (_wordFrequency[word] ?? 0) + 1;
            
            // Detect potential brands (words that appear frequently with other pattern words)
            if (_wordFrequency[word]! >= 3 && !_isCommonWord(word)) {
              _learnedBrands.add(word);
            }
          }
        }
      }
      
      // Extract product type patterns
      _extractProductTypes(products);
      
      _isInitialized = true;
      debugPrint('SmartSearch initialized with ${_learnedBrands.length} brands, ${_learnedTypes.length} types');
    } catch (e) {
      debugPrint('SmartSearch initialization error: $e');
    }
  }

  void _extractProductTypes(List<Map<String, dynamic>> products) {
    final typePatterns = RegExp(r'(كشاف|لمبة|سلك|مفتاح|بريزة|ترانس|شريط|بطارية|ريموت|سنسور|فيوز|LED|SMD)');
    
    for (final product in products) {
      final name = product['name'] as String;
      final match = typePatterns.firstMatch(name);
      if (match != null) {
        _learnedTypes.add(match.group(0)!.toLowerCase());
      }
    }
  }

  bool _isCommonWord(String word) {
    const commonWords = {
      'led', 'smd', 'واط', 'وات', 'w', 'مم', 'سم', 'متر',
      'ابيض', 'اصفر', 'احمر', 'اخضر', 'ازرق', 'اسود',
      'صغير', 'كبير', 'وسط', 'عادي', 'قوي',
    };
    return commonWords.contains(word);
  }

  /// Search products with smart matching
  Future<List<Map<String, dynamic>>> smartSearchProducts(String query) async {
    if (query.trim().isEmpty) return [];
    
    // Ensure initialized
    await initialize();

    final db = await _db.database;
    final normalizedQuery = _normalizeQuery(query);
    final originalTokens = _tokenize(query.toLowerCase());
    final normalizedTokens = _tokenize(normalizedQuery);
    // Merge both token sets to search with both forms
    final allTokens = {...originalTokens, ...normalizedTokens}.toList();
    
    // Extract special patterns
    final wattage = _extractWattage(query);
    final size = _extractSize(query);
    final color = _extractColor(query);
    
    // Build multi-strategy search
    final results = <Map<String, dynamic>>[];
    final seenIds = <int>{};
    
    // Strategy 0: Exact barcode match (highest priority)
    results.addAll(await _searchByBarcode(db, query.trim(), seenIds));
    
    // Strategy 0b: Direct LIKE with original query (most reliable for exact substring)
    results.addAll(await _searchDirectLike(db, query.trim(), seenIds));
    
    // Strategy 1: Token matches with BOTH original and normalized tokens
    results.addAll(await _searchByTokens(db, allTokens, seenIds));
    
    // Strategy 1b: Synonym-expanded token search
    results.addAll(await _searchBySynonymTokens(db, allTokens, seenIds));
    
    // Strategy 2: Fuzzy matching with original tokens
    results.addAll(await _searchFuzzy(db, originalTokens, seenIds));
    
    // Strategy 3: N-gram matching for partial words
    results.addAll(await _searchByNgrams(db, normalizedQuery, seenIds));
    
    // Strategy 4: Phonetic matching for Arabic
    results.addAll(await _searchPhonetic(db, query, seenIds));

    if (results.isEmpty) {
      // Fallback: Very loose search
      results.addAll(await _searchLoose(db, query, seenIds));
    }

    // Rank and filter results - use original tokens for proper boosting
    return _rankResults(results, originalTokens, wattage, size, color);
  }

  /// Strategy 0b: Direct LIKE search with the original query (no normalization)
  /// This is the most reliable strategy for finding all products containing the search term.
  Future<List<Map<String, dynamic>>> _searchDirectLike(
    dynamic db,
    String query,
    Set<int> seenIds,
  ) async {
    if (query.isEmpty) return [];
    
    try {
      // Search with the raw query as-is against name, barcode, note, supplier
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE name LIKE ? OR barcode LIKE ? OR note LIKE ? OR supplier LIKE ? ORDER BY name ASC LIMIT 200',
        ['%$query%', '%$query%', '%$query%', '%$query%'],
      );
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Strategy 0: Exact barcode match
  Future<List<Map<String, dynamic>>> _searchByBarcode(
    dynamic db,
    String query,
    Set<int> seenIds,
  ) async {
    if (query.isEmpty) return [];
    
    try {
      // Exact barcode match
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE barcode = ? LIMIT 1',
        [query],
      );
      if (results.isNotEmpty) return _filterSeen(results, seenIds);
      
      // Partial barcode match (barcode contains query or query contains barcode)
      final partialResults = await db.rawQuery(
        'SELECT * FROM products WHERE barcode LIKE ? LIMIT 10',
        ['%$query%'],
      );
      return _filterSeen(partialResults, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Strategy 1: Token-based search
  Future<List<Map<String, dynamic>>> _searchByTokens(
    dynamic db,
    List<String> tokens,
    Set<int> seenIds,
  ) async {
    if (tokens.isEmpty) return [];
    
    // Deduplicate tokens
    final uniqueTokens = tokens.toSet().toList();
    
    // Use OR between tokens from different normalization forms,
    // but require ALL conceptual tokens to match.
    // Group tokens by their position: original and normalized are alternatives.
    final conditions = uniqueTokens.map((_) => 'name LIKE ?').join(' OR ');
    final args = uniqueTokens.map((t) => '%$t%').toList();
    
    try {
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE $conditions LIMIT 200',
        args,
      );
      
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Strategy 1b: Search using synonym-expanded tokens
  Future<List<Map<String, dynamic>>> _searchBySynonymTokens(
    dynamic db,
    List<String> tokens,
    Set<int> seenIds,
  ) async {
    if (tokens.isEmpty) return [];
    
    // For each token, get all synonym expansions
    final allConditions = <String>[];
    final allArgs = <String>[];
    
    for (final token in tokens.toSet()) {
      final synonyms = _getSynonymExpansions(token);
      if (synonyms.length > 1) {
        // Only use synonym expansion if there are actual synonyms
        final synConditions = synonyms.map((_) => 'name LIKE ?').join(' OR ');
        allConditions.add('($synConditions)');
        allArgs.addAll(synonyms.map((s) => '%$s%'));
      }
    }
    
    if (allConditions.isEmpty) return [];
    
    try {
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE ${allConditions.join(' AND ')} LIMIT 100',
        allArgs,
      );
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Strategy 2: Fuzzy matching 
  Future<List<Map<String, dynamic>>> _searchFuzzy(
    dynamic db,
    List<String> tokens,
    Set<int> seenIds,
  ) async {
    final fuzzyResults = <Map<String, dynamic>>[];
    
    // Get all products for fuzzy comparison (cached)
    final allProducts = await db.rawQuery('SELECT * FROM products');
    
    for (final product in allProducts) {
      if (seenIds.contains(product['id'])) continue;
      
      final name = (product['name'] as String).toLowerCase();
      // Also normalize the product name for comparison
      var normalizedName = name;
      _arabicNormalization.forEach((from, to) {
        normalizedName = normalizedName.replaceAll(from, to);
      });
      
      var matchScore = 0;
      
      for (final token in tokens) {
        // Check substring match on both original and normalized name
        if (name.contains(token) || normalizedName.contains(token)) {
          matchScore += 30;
          continue;
        }
        
        // Check fuzzy match (Levenshtein-like)
        final nameWords = name.split(RegExp(r'[\s\-_،,./]+'));
        for (final word in nameWords) {
          if (_isFuzzyMatch(token, word)) {
            matchScore += 20;
            break;
          }
        }
        
        // Check synonym match
        if (_isSynonymMatch(token, name)) {
          matchScore += 25;
        }
        
        // Check brand variation
        if (_isBrandMatch(token, name)) {
          matchScore += 25;
        }
      }
      
      // Require a meaningful match score - at least one strong match
      // (20 = one fuzzy word match, 25 = synonym/brand match, 30 = exact token)
      if (matchScore >= 20) {
        fuzzyResults.add({...product, 'fuzzy_score': matchScore});
      }
    }
    
    fuzzyResults.sort((a, b) => 
      (b['fuzzy_score'] as int).compareTo(a['fuzzy_score'] as int)
    );
    
    return _filterSeen(fuzzyResults.take(50).toList(), seenIds);
  }

  /// Check if two strings are fuzzy matches
  bool _isFuzzyMatch(String a, String b) {
    if (a.length < 2 || b.length < 2) return false;
    
    // One contains the other (exact substring match)
    if (a.contains(b) || b.contains(a)) return true;
    
    // Require at least 3-char prefix match AND similar length
    if (a.length >= 3 && b.length >= 3 && 
        a.substring(0, 3) == b.substring(0, 3) &&
        (a.length - b.length).abs() <= 1) {
      return true;
    }
    
    // Edit distance: scale allowed differences with word length
    // Short words (<=4 chars): allow only 1 difference
    // Medium words (5-7 chars): allow 1 difference
    // Long words (8+ chars): allow 2 differences
    if ((a.length - b.length).abs() <= 1) {
      final minLen = a.length < b.length ? a.length : b.length;
      final maxAllowed = minLen >= 8 ? 2 : 1;
      var differences = 0;
      for (var i = 0; i < minLen && differences <= maxAllowed; i++) {
        if (a[i] != b[i]) differences++;
      }
      // Also count length difference as a difference
      differences += (a.length - b.length).abs();
      return differences <= maxAllowed;
    }
    
    return false;
  }

  /// Check if token matches any synonym
  bool _isSynonymMatch(String token, String productName) {
    for (final entry in _arabicSynonyms.entries) {
      if (entry.value.any((syn) => syn.toLowerCase() == token)) {
        // Check if product has the standard term or any synonym
        if (productName.contains(entry.key) ||
            entry.value.any((syn) => productName.contains(syn.toLowerCase()))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Check if token matches any brand variation
  bool _isBrandMatch(String token, String productName) {
    for (final entry in _brandVariations.entries) {
      if (entry.value.any((v) => v.toLowerCase() == token || 
          _isFuzzyMatch(v.toLowerCase(), token))) {
        // Check if product contains standard brand or any variation
        if (productName.contains(entry.key) ||
            entry.value.any((v) => productName.contains(v.toLowerCase()))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Strategy 3: N-gram matching
  Future<List<Map<String, dynamic>>> _searchByNgrams(
    dynamic db,
    String query,
    Set<int> seenIds,
  ) async {
    // Generate 3-grams
    final ngrams = <String>[];
    final cleanQuery = query.replaceAll(RegExp(r'\s+'), '');
    
    for (var i = 0; i <= cleanQuery.length - 3; i++) {
      ngrams.add(cleanQuery.substring(i, i + 3));
    }
    
    if (ngrams.isEmpty) return [];
    
    // Search for products matching any n-gram
    final conditions = ngrams.take(5).map((_) => 'name LIKE ?').join(' OR ');
    final args = ngrams.take(5).map((ng) => '%$ng%').toList();
    
    try {
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE $conditions LIMIT 100',
        args,
      );
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Strategy 4: Phonetic matching for Arabic
  Future<List<Map<String, dynamic>>> _searchPhonetic(
    dynamic db,
    String query,
    Set<int> seenIds,
  ) async {
    // Normalize Arabic characters
    var phoneticQuery = query;
    _arabicNormalization.forEach((from, to) {
      phoneticQuery = phoneticQuery.replaceAll(from, to);
    });
    
    // Remove diacritics
    phoneticQuery = phoneticQuery.replaceAll(RegExp(r'[\u064B-\u065F]'), '');
    
    if (phoneticQuery == query) return []; // No change
    
    final tokens = _tokenize(phoneticQuery);
    if (tokens.isEmpty) return [];
    
    final conditions = tokens.map((_) => 'name LIKE ?').join(' OR ');
    final args = tokens.map((t) => '%$t%').toList();
    
    try {
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE $conditions LIMIT 15',
        args,
      );
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  /// Fallback loose search
  Future<List<Map<String, dynamic>>> _searchLoose(
    dynamic db,
    String query,
    Set<int> seenIds,
  ) async {
    // Try first 3 characters of each word
    final tokens = query.split(RegExp(r'\s+')).where((w) => w.length >= 3).toList();
    if (tokens.isEmpty) return [];
    
    final conditions = tokens.map((_) => '(name LIKE ? OR barcode LIKE ?)').join(' OR ');
    final args = tokens.map((t) => '%${t.substring(0, 3)}%').expand((t) => [t, t]).toList();
    
    try {
      final results = await db.rawQuery(
        'SELECT * FROM products WHERE $conditions LIMIT 20',
        args,
      );
      return _filterSeen(results, seenIds);
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _filterSeen(
    List<Map<String, dynamic>> results,
    Set<int> seenIds,
  ) {
    final filtered = <Map<String, dynamic>>[];
    for (final r in results) {
      final id = r['id'] as int?;
      if (id != null && !seenIds.contains(id)) {
        seenIds.add(id);
        filtered.add(r);
      }
    }
    return filtered;
  }

  /// Normalize query for better matching
  String _normalizeQuery(String query) {
    var normalized = query.toLowerCase().trim();
    
    // Normalize Arabic characters
    _arabicNormalization.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });
    
    // Replace brand variations with standard names
    _brandVariations.forEach((standard, variations) {
      for (final variant in variations) {
        normalized = normalized.replaceAll(variant.toLowerCase(), standard);
      }
    });
    
    // NOTE: Do NOT replace synonyms here. Synonym expansion is handled
    // in search strategies so exact matches are prioritized over synonyms.
    
    return normalized;
  }

  /// Get all synonym variants for a token (including the token itself)
  List<String> _getSynonymExpansions(String token) {
    final expansions = <String>{token};
    for (final entry in _arabicSynonyms.entries) {
      if (entry.key == token || entry.value.any((syn) => syn.toLowerCase() == token)) {
        expansions.addAll(entry.value.map((s) => s.toLowerCase()));
        expansions.add(entry.key);
      }
    }
    return expansions.toList();
  }

  /// Tokenize query into searchable parts
  List<String> _tokenize(String query) {
    final tokens = query.split(RegExp(r'[\s,،.\-_/]+'));
    return tokens.where((t) => t.length >= 2).toList();
  }

  /// Extract wattage from query
  int? _extractWattage(String query) {
    final patterns = [
      RegExp(r'(\d+)\s*(?:واط|وات|w|watt)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
    }
    
    // Check Arabic number words
    for (final entry in _arabicNumbers.entries) {
      if (query.contains(entry.key) && query.contains(RegExp(r'واط|وات|w', caseSensitive: false))) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Extract size/measurement
  String? _extractSize(String query) {
    final patterns = [
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:مم|ملم|mm)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:سم|cm)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:متر|م|m)(?!\w)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*(?:انش|بوصة|inch)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(query);
      if (match != null) {
        return match.group(0);
      }
    }
    return null;
  }

  /// Extract color
  String? _extractColor(String query) {
    final colors = {
      'ابيض': ['ابيض', 'أبيض', 'white', 'وايت'],
      'اصفر': ['اصفر', 'أصفر', 'yellow', 'يلو', 'warm', 'دافئ'],
      'احمر': ['احمر', 'أحمر', 'red', 'رد'],
      'اخضر': ['اخضر', 'أخضر', 'green', 'جرين'],
      'ازرق': ['ازرق', 'أزرق', 'blue', 'بلو'],
      'اسود': ['اسود', 'أسود', 'black', 'بلاك'],
      'rgb': ['rgb', 'ار جي بي', 'ملون', 'الوان'],
    };
    
    final lowerQuery = query.toLowerCase();
    for (final entry in colors.entries) {
      for (final colorVar in entry.value) {
        if (lowerQuery.contains(colorVar)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Rank results by relevance
  List<Map<String, dynamic>> _rankResults(
    List<Map<String, dynamic>> results,
    List<String> tokens,
    int? wattage,
    String? size,
    String? color,
  ) {
    final scored = results.map((r) {
      var score = (r['fuzzy_score'] as int?) ?? 50;
      final name = (r['name'] as String).toLowerCase();
      // Normalize product name too for matching
      var normalizedName = name;
      _arabicNormalization.forEach((from, to) {
        normalizedName = normalizedName.replaceAll(from, to);
      });
      
      // Boost for exact token matches (original query terms)
      for (final token in tokens) {
        if (name.contains(token) || normalizedName.contains(token)) {
          score += 30; // Strong boost for exact match on search term
          if (name.startsWith(token) || normalizedName.startsWith(token)) score += 15;
        } else {
          // Check if match is via synonym - lower boost
          final synonyms = _getSynonymExpansions(token);
          final isSynonymMatch = synonyms.any((syn) => syn != token && (name.contains(syn) || normalizedName.contains(syn)));
          if (isSynonymMatch) {
            score += 10; // Lower boost for synonym-only match
          }
        }
      }
      
      // Boost for wattage match
      if (wattage != null && name.contains('$wattage')) {
        score += 25;
      }
      
      // Boost for color match
      if (color != null && name.contains(color)) {
        score += 15;
      }
      
      // Boost for in-stock items
      final qty = r['quantity'] as int? ?? 0;
      if (qty > 0) score += 20;
      if (qty > 10) score += 10;
      
      // Boost for learned brands
      for (final brand in _learnedBrands) {
        if (name.contains(brand)) {
          score += 5;
          break;
        }
      }
      
      return {...r, 'score': score};
    }).toList();
    
    scored.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    // Don't aggressively filter - return all results sorted by relevance.
    // Only remove very low scores (likely noise from n-gram/fuzzy)
    const minScore = 30;
    final filtered = scored.where((r) => (r['score'] as int) >= minScore).toList();
    
    return filtered.isNotEmpty ? filtered : scored.take(10).toList();
  }

  /// Get search suggestions with fuzzy matching
  Future<List<String>> getSuggestions(String partial) async {
    if (partial.length < 2) return [];
    
    await initialize();
    
    final db = await _db.database;
    final normalized = _normalizeQuery(partial);
    
    // Get direct matches
    final directResults = await db.rawQuery('''
      SELECT DISTINCT name FROM products 
      WHERE name LIKE ? 
      ORDER BY name 
      LIMIT 10
    ''', ['%$normalized%']);
    
    final suggestions = directResults.map((r) => r['name'] as String).toList();
    
    // Also search synonym expansions
    if (suggestions.length < 10) {
      final tokens = _tokenize(normalized);
      for (final token in tokens) {
        final synonyms = _getSynonymExpansions(token);
        for (final syn in synonyms) {
          if (syn == token) continue;
          final synResults = await db.rawQuery('''
            SELECT DISTINCT name FROM products 
            WHERE name LIKE ? 
            ORDER BY name 
            LIMIT 5
          ''', ['%$syn%']);
          for (final r in synResults) {
            final name = r['name'] as String;
            if (!suggestions.contains(name)) {
              suggestions.add(name);
            }
            if (suggestions.length >= 10) break;
          }
          if (suggestions.length >= 10) break;
        }
        if (suggestions.length >= 10) break;
      }
    }
    
    // Add fuzzy suggestions if needed
    if (suggestions.length < 5) {
      final allProducts = await db.rawQuery('SELECT DISTINCT name FROM products LIMIT 200');
      
      for (final product in allProducts) {
        if (suggestions.length >= 10) break;
        
        final name = product['name'] as String;
        if (suggestions.contains(name)) continue;
        
        final nameWords = name.toLowerCase().split(RegExp(r'[\s\-]+'));
        for (final word in nameWords) {
          if (_isFuzzyMatch(partial.toLowerCase(), word)) {
            suggestions.add(name);
            break;
          }
        }
      }
    }
    
    return suggestions;
  }

  /// Find similar products
  Future<List<Map<String, dynamic>>> findSimilar(String productName) async {
    await initialize();
    
    final tokens = _tokenize(productName.toLowerCase());
    if (tokens.isEmpty) return [];
    
    // Remove common words, keep brand and type
    final meaningfulTokens = tokens.where((t) => 
      !_isCommonWord(t) && t.length >= 3
    ).toList();
    
    if (meaningfulTokens.isEmpty) return [];
    
    return smartSearchProducts(meaningfulTokens.take(3).join(' '));
  }
}
