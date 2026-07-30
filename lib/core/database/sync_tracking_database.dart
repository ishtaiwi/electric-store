import 'package:sqflite/sqflite.dart';

typedef SyncWriteCallback = void Function();

/// Wraps a [Database] and notifies [onWrite] after any data mutation.
class SyncTrackingDatabase implements Database {
  SyncTrackingDatabase(this._db, this.onWrite, {this.shouldNotify});

  final Database _db;
  final SyncWriteCallback onWrite;
  final bool Function()? shouldNotify;

  int _txnDepth = 0;
  bool _dirty = false;

  void _markWrite() {
    if (shouldNotify != null && !shouldNotify!()) return;
    if (_txnDepth > 0) {
      _dirty = true;
    } else {
      onWrite();
    }
  }

  @override
  Database get database => this;

  @override
  String get path => _db.path;

  @override
  bool get isOpen => _db.isOpen;

  @override
  Future<void> close() => _db.close();

  @override
  Future<T> devInvokeMethod<T>(String method, [Object? arguments]) =>
      _db.devInvokeMethod<T>(method, arguments);

  @override
  Future<T> devInvokeSqlMethod<T>(
    String method,
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _db.devInvokeSqlMethod<T>(method, sql, arguments);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _db.execute(sql, arguments);
    final upper = sql.trimLeft().toUpperCase();
    if (upper.startsWith('INSERT') ||
        upper.startsWith('UPDATE') ||
        upper.startsWith('DELETE') ||
        upper.startsWith('REPLACE') ||
        upper.startsWith('CREATE') ||
        upper.startsWith('DROP') ||
        upper.startsWith('ALTER')) {
      _markWrite();
    }
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final id = await _db.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markWrite();
    return id;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final id = await _db.rawInsert(sql, arguments);
    _markWrite();
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final n = await _db.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markWrite();
    return n;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final n = await _db.rawUpdate(sql, arguments);
    _markWrite();
    return n;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final n = await _db.delete(table, where: where, whereArgs: whereArgs);
    _markWrite();
    return n;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final n = await _db.rawDelete(sql, arguments);
    _markWrite();
    return n;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _db.rawQuery(sql, arguments);

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _db.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _db.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  Batch batch() => _SyncTrackingBatch(_db.batch(), _markWrite);

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    _txnDepth++;
    try {
      return await _db.transaction<T>(
        (txn) => action(_SyncTrackingTransaction(txn, _markWrite)),
        exclusive: exclusive,
      );
    } finally {
      _txnDepth--;
      if (_txnDepth == 0 && _dirty) {
        _dirty = false;
        if (shouldNotify == null || shouldNotify!()) {
          onWrite();
        }
      }
    }
  }

  @override
  Future<T> readTransaction<T>(Future<T> Function(Transaction txn) action) =>
      _db.readTransaction(action);
}

class _SyncTrackingTransaction implements Transaction {
  _SyncTrackingTransaction(this._txn, this._markWrite);

  final Transaction _txn;
  final void Function() _markWrite;

  @override
  Database get database => _txn.database;

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    await _txn.execute(sql, arguments);
    final upper = sql.trimLeft().toUpperCase();
    if (upper.startsWith('INSERT') ||
        upper.startsWith('UPDATE') ||
        upper.startsWith('DELETE') ||
        upper.startsWith('REPLACE')) {
      _markWrite();
    }
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final id = await _txn.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markWrite();
    return id;
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) async {
    final id = await _txn.rawInsert(sql, arguments);
    _markWrite();
    return id;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final n = await _txn.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
    _markWrite();
    return n;
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) async {
    final n = await _txn.rawUpdate(sql, arguments);
    _markWrite();
    return n;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final n = await _txn.delete(table, where: where, whereArgs: whereArgs);
    _markWrite();
    return n;
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) async {
    final n = await _txn.rawDelete(sql, arguments);
    _markWrite();
    return n;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _txn.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) =>
      _txn.rawQuery(sql, arguments);

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) =>
      _txn.queryCursor(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
        bufferSize: bufferSize,
      );

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) =>
      _txn.rawQueryCursor(sql, arguments, bufferSize: bufferSize);

  @override
  Batch batch() => _SyncTrackingBatch(_txn.batch(), _markWrite);
}

class _SyncTrackingBatch implements Batch {
  _SyncTrackingBatch(this._batch, this._markWrite);

  final Batch _batch;
  final void Function() _markWrite;

  @override
  int get length => _batch.length;

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _batch.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  void rawInsert(String sql, [List<Object?>? arguments]) =>
      _batch.rawInsert(sql, arguments);

  @override
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) =>
      _batch.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );

  @override
  void rawUpdate(String sql, [List<Object?>? arguments]) =>
      _batch.rawUpdate(sql, arguments);

  @override
  void delete(String table, {String? where, List<Object?>? whereArgs}) =>
      _batch.delete(table, where: where, whereArgs: whereArgs);

  @override
  void rawDelete(String sql, [List<Object?>? arguments]) =>
      _batch.rawDelete(sql, arguments);

  @override
  void execute(String sql, [List<Object?>? arguments]) =>
      _batch.execute(sql, arguments);

  @override
  void query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) =>
      _batch.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

  @override
  void rawQuery(String sql, [List<Object?>? arguments]) =>
      _batch.rawQuery(sql, arguments);

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    final result = await _batch.commit(
      exclusive: exclusive,
      noResult: noResult,
      continueOnError: continueOnError,
    );
    _markWrite();
    return result;
  }

  @override
  Future<List<Object?>> apply({bool? noResult, bool? continueOnError}) async {
    final result = await _batch.apply(
      noResult: noResult,
      continueOnError: continueOnError,
    );
    _markWrite();
    return result;
  }
}
