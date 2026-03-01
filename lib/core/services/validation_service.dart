/// Validation result containing success status and error messages
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final Map<String, String> fieldErrors;

  ValidationResult._({
    required this.isValid,
    this.errors = const [],
    this.fieldErrors = const {},
  });

  factory ValidationResult.success() => ValidationResult._(isValid: true);
  
  factory ValidationResult.failure(List<String> errors, {Map<String, String>? fieldErrors}) {
    return ValidationResult._(
      isValid: false,
      errors: errors,
      fieldErrors: fieldErrors ?? {},
    );
  }

  factory ValidationResult.fieldError(String field, String error) {
    return ValidationResult._(
      isValid: false,
      errors: [error],
      fieldErrors: {field: error},
    );
  }

  String get firstError => errors.isNotEmpty ? errors.first : 'Validation failed';
}

/// Validation rules for common data types
class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  // ==================== Product Validation ====================
  
  ValidationResult validateProduct({
    required String name,
    String? barcode,
    required int quantity,
    required double price,
    required double costPrice,
    int? minStock,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Name validation
    if (name.trim().isEmpty) {
      errors.add('Product name is required');
      fieldErrors['name'] = 'Product name is required';
    } else if (name.length > 100) {
      errors.add('Product name is too long (max 100 characters)');
      fieldErrors['name'] = 'Name is too long';
    }

    // Quantity validation
    if (quantity < 0) {
      errors.add('Quantity cannot be negative');
      fieldErrors['quantity'] = 'Cannot be negative';
    } else if (quantity > 999999) {
      errors.add('Quantity is too large');
      fieldErrors['quantity'] = 'Value is too large';
    }

    // Price validation
    if (price < 0) {
      errors.add('Price cannot be negative');
      fieldErrors['price'] = 'Cannot be negative';
    } else if (price > 9999999) {
      errors.add('Price is too large');
      fieldErrors['price'] = 'Value is too large';
    }

    // Cost price validation
    if (costPrice < 0) {
      errors.add('Cost price cannot be negative');
      fieldErrors['costPrice'] = 'Cannot be negative';
    } else if (costPrice > price && price > 0) {
      // Warning: cost > price (losing money), but allow it
    }

    // Barcode validation
    if (barcode != null && barcode.isNotEmpty) {
      if (!_isValidBarcode(barcode)) {
        errors.add('Invalid barcode format');
        fieldErrors['barcode'] = 'Invalid format';
      }
    }

    // Min stock validation
    if (minStock != null && minStock < 0) {
      errors.add('Minimum stock cannot be negative');
      fieldErrors['minStock'] = 'Cannot be negative';
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== Customer Validation ====================
  
  ValidationResult validateCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Name validation
    if (name.trim().isEmpty) {
      errors.add('Customer name is required');
      fieldErrors['name'] = 'Name is required';
    } else if (name.length > 100) {
      errors.add('Customer name is too long');
      fieldErrors['name'] = 'Name is too long';
    }

    // Phone validation
    if (phone != null && phone.isNotEmpty) {
      if (!_isValidPhone(phone)) {
        errors.add('Invalid phone number format');
        fieldErrors['phone'] = 'Invalid phone format';
      }
    }

    // Email validation
    if (email != null && email.isNotEmpty) {
      if (!_isValidEmail(email)) {
        errors.add('Invalid email format');
        fieldErrors['email'] = 'Invalid email format';
      }
    }

    // Address validation
    if (address != null && address.length > 500) {
      errors.add('Address is too long');
      fieldErrors['address'] = 'Address is too long';
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== Invoice Validation ====================
  
  ValidationResult validateInvoice({
    required String invoiceNumber,
    required double totalAmount,
    required double finalAmount,
    double? paidAmount,
    double? discountAmount,
    int? customerId,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Invoice number validation
    if (invoiceNumber.trim().isEmpty) {
      errors.add('Invoice number is required');
      fieldErrors['invoiceNumber'] = 'Required';
    }

    // Amount validations
    if (totalAmount < 0) {
      errors.add('Total amount cannot be negative');
      fieldErrors['totalAmount'] = 'Cannot be negative';
    }

    if (finalAmount < 0) {
      errors.add('Final amount cannot be negative');
      fieldErrors['finalAmount'] = 'Cannot be negative';
    }

    if (paidAmount != null && paidAmount < 0) {
      errors.add('Paid amount cannot be negative');
      fieldErrors['paidAmount'] = 'Cannot be negative';
    }

    if (paidAmount != null && paidAmount > finalAmount) {
      errors.add('Paid amount cannot exceed final amount');
      fieldErrors['paidAmount'] = 'Exceeds final amount';
    }

    if (discountAmount != null) {
      if (discountAmount < 0) {
        errors.add('Discount cannot be negative');
        fieldErrors['discountAmount'] = 'Cannot be negative';
      } else if (discountAmount > totalAmount) {
        errors.add('Discount cannot exceed total amount');
        fieldErrors['discountAmount'] = 'Exceeds total';
      }
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== User Validation ====================
  
  ValidationResult validateUser({
    required String username,
    required String password,
    String? fullName,
    required String role,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Username validation
    if (username.trim().isEmpty) {
      errors.add('Username is required');
      fieldErrors['username'] = 'Required';
    } else if (username.length < 3) {
      errors.add('Username must be at least 3 characters');
      fieldErrors['username'] = 'Too short';
    } else if (username.length > 50) {
      errors.add('Username is too long');
      fieldErrors['username'] = 'Too long';
    } else if (!_isValidUsername(username)) {
      errors.add('Username can only contain letters, numbers, and underscores');
      fieldErrors['username'] = 'Invalid characters';
    }

    // Password validation
    if (password.isEmpty) {
      errors.add('Password is required');
      fieldErrors['password'] = 'Required';
    } else if (password.length < 6) {
      errors.add('Password must be at least 6 characters');
      fieldErrors['password'] = 'Too short';
    }

    // Role validation
    final validRoles = ['admin', 'manager', 'cashier', 'user'];
    if (!validRoles.contains(role.toLowerCase())) {
      errors.add('Invalid role');
      fieldErrors['role'] = 'Invalid role';
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== Expense Validation ====================
  
  ValidationResult validateExpense({
    required String description,
    required double amount,
    required String category,
    DateTime? expenseDate,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    // Description validation
    if (description.trim().isEmpty) {
      errors.add('Description is required');
      fieldErrors['description'] = 'Required';
    } else if (description.length > 500) {
      errors.add('Description is too long');
      fieldErrors['description'] = 'Too long';
    }

    // Amount validation
    if (amount <= 0) {
      errors.add('Amount must be greater than zero');
      fieldErrors['amount'] = 'Must be > 0';
    } else if (amount > 9999999) {
      errors.add('Amount is too large');
      fieldErrors['amount'] = 'Too large';
    }

    // Category validation
    if (category.trim().isEmpty) {
      errors.add('Category is required');
      fieldErrors['category'] = 'Required';
    }

    // Date validation
    if (expenseDate != null && expenseDate.isAfter(DateTime.now().add(const Duration(days: 1)))) {
      errors.add('Expense date cannot be in the future');
      fieldErrors['expenseDate'] = 'Cannot be future';
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== Payment Validation ====================
  
  ValidationResult validatePayment({
    required double amount,
    required double remainingBalance,
  }) {
    final errors = <String>[];
    final fieldErrors = <String, String>{};

    if (amount <= 0) {
      errors.add('Payment amount must be greater than zero');
      fieldErrors['amount'] = 'Must be > 0';
    }

    if (amount > remainingBalance) {
      errors.add('Payment amount exceeds remaining balance');
      fieldErrors['amount'] = 'Exceeds balance';
    }

    return errors.isEmpty 
        ? ValidationResult.success() 
        : ValidationResult.failure(errors, fieldErrors: fieldErrors);
  }

  // ==================== Helper Methods ====================

  bool _isValidBarcode(String barcode) {
    // Allow alphanumeric barcodes of reasonable length
    return RegExp(r'^[a-zA-Z0-9\-]{3,50}$').hasMatch(barcode);
  }

  bool _isValidPhone(String phone) {
    // Allow various phone formats
    return RegExp(r'^[\d\s\-\+\(\)]{7,20}$').hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  // ==================== Generic Validators ====================

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName must be a number';
    }
    if (number < 0) {
      return '$fieldName cannot be negative';
    }
    return null;
  }

  String? validateRange(String? value, String fieldName, {double? min, double? max}) {
    if (value == null || value.isEmpty) return null;
    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName must be a number';
    }
    if (min != null && number < min) {
      return '$fieldName must be at least $min';
    }
    if (max != null && number > max) {
      return '$fieldName must be at most $max';
    }
    return null;
  }

  String? validateLength(String? value, String fieldName, {int? min, int? max}) {
    if (value == null) return null;
    if (min != null && value.length < min) {
      return '$fieldName must be at least $min characters';
    }
    if (max != null && value.length > max) {
      return '$fieldName must be at most $max characters';
    }
    return null;
  }
}
