import 'package:flutter/foundation.dart';

/// Error types for categorization
enum ErrorType {
  database('DATABASE_ERROR'),
  network('NETWORK_ERROR'),
  validation('VALIDATION_ERROR'),
  authentication('AUTH_ERROR'),
  authorization('AUTHORIZATION_ERROR'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  unknown('UNKNOWN_ERROR');

  final String value;
  const ErrorType(this.value);
}

/// Custom application exception with detailed information
class AppException implements Exception {
  final String message;
  final ErrorType type;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  AppException({
    required this.message,
    this.type = ErrorType.unknown,
    this.code,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    return 'AppException(${type.value}): $message${code != null ? ' [Code: $code]' : ''}';
  }

  /// Create a user-friendly error message
  String toUserMessage() {
    switch (type) {
      case ErrorType.database:
        return 'A database error occurred. Please try again or contact support.';
      case ErrorType.network:
        return 'Network connection error. Please check your connection.';
      case ErrorType.validation:
        return message; // Validation errors are usually user-friendly
      case ErrorType.authentication:
        return 'Authentication failed. Please check your credentials.';
      case ErrorType.authorization:
        return 'You do not have permission to perform this action.';
      case ErrorType.notFound:
        return 'The requested item was not found.';
      case ErrorType.conflict:
        return 'A conflict occurred. The data may have been modified.';
      case ErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}

/// Result wrapper for operations that can fail
class Result<T> {
  final T? data;
  final AppException? error;
  final bool isSuccess;

  Result._({this.data, this.error, required this.isSuccess});

  factory Result.success(T data) => Result._(data: data, isSuccess: true);
  factory Result.failure(AppException error) => Result._(error: error, isSuccess: false);

  /// Execute a function and return success or failure
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Result.success(result);
    } on AppException catch (e) {
      return Result.failure(e);
    } catch (e, stackTrace) {
      return Result.failure(AppException(
        message: e.toString(),
        type: ErrorType.unknown,
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Transform the success value
  Result<R> map<R>(R Function(T) transform) {
    if (isSuccess && data != null) {
      return Result.success(transform(data as T));
    }
    return Result.failure(error!);
  }

  /// Get value or throw
  T getOrThrow() {
    if (isSuccess && data != null) return data as T;
    throw error ?? AppException(message: 'Unknown error');
  }

  /// Get value or default
  T getOrDefault(T defaultValue) {
    if (isSuccess && data != null) return data as T;
    return defaultValue;
  }
}

/// Error handling service for centralized error management
class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  final List<void Function(AppException)> _errorListeners = [];

  /// Add error listener for global error handling
  void addErrorListener(void Function(AppException) listener) {
    _errorListeners.add(listener);
  }

  /// Remove error listener
  void removeErrorListener(void Function(AppException) listener) {
    _errorListeners.remove(listener);
  }

  /// Handle an exception and notify listeners
  AppException handle(dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorType? type,
  }) {
    AppException appException;

    if (error is AppException) {
      appException = error;
    } else {
      // Determine error type from exception
      ErrorType errorType = type ?? _determineErrorType(error);
      
      appException = AppException(
        message: error.toString(),
        type: errorType,
        originalError: error,
        stackTrace: stackTrace,
        context: context != null ? {'context': context} : null,
      );
    }

    // Log the error
    _logError(appException);

    // Notify listeners
    for (final listener in _errorListeners) {
      try {
        listener(appException);
      } catch (e) {
        debugPrint('Error in error listener: $e');
      }
    }

    return appException;
  }

  /// Determine error type from exception
  ErrorType _determineErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('database') || 
        errorString.contains('sqlite') ||
        errorString.contains('sql')) {
      return ErrorType.database;
    }
    if (errorString.contains('network') || 
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return ErrorType.network;
    }
    if (errorString.contains('unauthorized') || 
        errorString.contains('unauthenticated')) {
      return ErrorType.authentication;
    }
    if (errorString.contains('forbidden') || 
        errorString.contains('permission')) {
      return ErrorType.authorization;
    }
    if (errorString.contains('not found') || 
        errorString.contains('404')) {
      return ErrorType.notFound;
    }
    if (errorString.contains('validation') || 
        errorString.contains('invalid')) {
      return ErrorType.validation;
    }
    
    return ErrorType.unknown;
  }

  /// Log error for debugging and monitoring
  void _logError(AppException error) {
    debugPrint('ERROR [${error.type.value}]: ${error.message}');
    if (error.code != null) {
      debugPrint('  Code: ${error.code}');
    }
    if (error.context != null) {
      debugPrint('  Context: ${error.context}');
    }
    if (kDebugMode && error.stackTrace != null) {
      debugPrint('  StackTrace: ${error.stackTrace}');
    }
  }

  /// Retry an operation with exponential backoff
  Future<T> retryWithBackoff<T>({
    required Future<T> Function() action,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempts++;
        return await action();
      } catch (e, stackTrace) {
        if (attempts >= maxAttempts) {
          throw handle(e, stackTrace: stackTrace, context: 'After $attempts retries');
        }
        
        debugPrint('Retry attempt $attempts failed, waiting ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffMultiplier).toInt(),
        );
      }
    }
  }

  /// Execute with timeout
  Future<T> withTimeout<T>({
    required Future<T> Function() action,
    Duration timeout = const Duration(seconds: 30),
    String? operationName,
  }) async {
    try {
      return await action().timeout(timeout);
    } catch (e, stackTrace) {
      throw handle(
        e, 
        stackTrace: stackTrace, 
        context: operationName ?? 'Operation timed out',
      );
    }
  }
}

/// Extension for easy error handling
extension FutureErrorHandling<T> on Future<T> {
  /// Convert Future to Result
  Future<Result<T>> toResult() async {
    try {
      final data = await this;
      return Result.success(data);
    } catch (e, stackTrace) {
      return Result.failure(AppException(
        message: e.toString(),
        originalError: e,
        stackTrace: stackTrace,
      ));
    }
  }
}
