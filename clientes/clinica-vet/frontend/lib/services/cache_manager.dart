// lib/services/cache_manager.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// ... (todo o resto da sua classe CacheEntry permanece igual) ...
class CacheEntry<T> {
  final String key;
  final T data;
  final DateTime timestamp;
  final Duration ttl;
  final String userId;
  final String negocioId;
  
  CacheEntry({
    required this.key,
    required this.data,
    required this.ttl,
    required this.userId,
    required this.negocioId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
  
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'data': jsonEncode(data),
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ttl_minutes': ttl.inMinutes,
      'user_id': userId,
      'negocio_id': negocioId,
    };
  }
  
  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    final storedTimestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp']);
    final ttlMinutes = map['ttl_minutes'] as int;
    
    return CacheEntry<T>(
      key: map['key'],
      data: jsonDecode(map['data']) as T,
      ttl: Duration(minutes: ttlMinutes),
      userId: map['user_id'],
      negocioId: map['negocio_id'],
      timestamp: storedTimestamp,
    );
  }
}

class CacheManager {
  static const String _dbName = 'cache_database.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'cache_entries';
  
  Database? _database;
  final Map<String, CacheEntry> _memoryCache = {};
  static CacheManager? _instance;
  
  CacheManager._internal();
  
  static CacheManager get instance {
    _instance ??= CacheManager._internal();
    return _instance!;
  }
  
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);
    
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createTables,
    );
  }
  
  Future<void> _createTables(Database db, int version) async {
    
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        ttl_minutes INTEGER NOT NULL,
        user_id TEXT NOT NULL,
        negocio_id TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        UNIQUE(key, user_id, negocio_id)
      )
    ''');
    
    // Índices para performance
    await db.execute('''
      CREATE INDEX idx_cache_key_user ON $_tableName (key, user_id, negocio_id)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_cache_timestamp ON $_tableName (timestamp)
    ''');
  }
  
  String _getCacheKey(String endpoint, String userId, String negocioId, [Map<String, dynamic>? params]) {
    final paramString = params?.entries.map((e) => '${e.key}=${e.value}').join('&') ?? '';
    return '${userId}_${negocioId}_${endpoint}_$paramString';
  }
  
  Future<T?> get<T>(
    String endpoint,
    String userId,
    String negocioId, {
    Map<String, dynamic>? params,
  }) async {
    final cacheKey = _getCacheKey(endpoint, userId, negocioId, params);
    
    // Tenta primeiro o cache em memória
    final memoryEntry = _memoryCache[cacheKey] as CacheEntry<T>?;
    if (memoryEntry != null && !memoryEntry.isExpired) {
      return memoryEntry.data;
    }
    
    // Se não encontrou na memória ou expirou, busca no SQLite
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'key = ? AND user_id = ? AND negocio_id = ?',
        whereArgs: [cacheKey, userId, negocioId],
        limit: 1,
      );
      
      if (result.isNotEmpty) {
        final entry = CacheEntry<T>.fromMap(result.first);
        
        if (!entry.isExpired) {
          // Cache SQLite válido - move para memória
          _memoryCache[cacheKey] = entry;
          return entry.data;
        } else {
          // Cache expirado - remove do SQLite
          await _removeExpired(cacheKey);
        }
      }
    } catch (e) {
    }
    
    return null;
  }
  
  Future<void> set<T>(
    String endpoint,
    T data,
    String userId,
    String negocioId, {
    Duration? ttl,
    Map<String, dynamic>? params,
  }) async {
    final cacheKey = _getCacheKey(endpoint, userId, negocioId, params);
    final defaultTtl = ttl ?? const Duration(minutes: 5);
    
    final entry = CacheEntry<T>(
      key: cacheKey,
      data: data,
      ttl: defaultTtl,
      userId: userId,
      negocioId: negocioId,
    );
    
    // Armazena na memória
    _memoryCache[cacheKey] = entry;
    
    // Armazena no SQLite de forma assíncrona
    _saveToDisk(entry);
    
  }
  
  void _saveToDisk<T>(CacheEntry<T> entry) async {
    try {
      final db = await database;
      await db.insert(
        _tableName,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
    }
  }
  
  Future<void> clear({String? pattern, String? userId, String? negocioId}) async {
    try {
      final db = await database;
      
      if (pattern != null) {
        // Remove por padrão
        if (userId != null && negocioId != null) {
          await db.delete(
            _tableName,
            where: 'key LIKE ? AND user_id = ? AND negocio_id = ?',
            whereArgs: ['%$pattern%', userId, negocioId],
          );
        } else {
          await db.delete(
            _tableName,
            where: 'key LIKE ?',
            whereArgs: ['%$pattern%'],
          );
        }
        _memoryCache.removeWhere((key, value) => key.contains(pattern));
      } else {
        // Remove tudo
        await db.delete(_tableName);
        _memoryCache.clear();
      }
    } catch (e) {
    }
  }
  
  Future<void> _removeExpired(String cacheKey) async {
    try {
      final db = await database;
      await db.delete(_tableName, where: 'key = ?', whereArgs: [cacheKey]);
      _memoryCache.remove(cacheKey);
    } catch (e) {
    }
  }
  
  Future<void> cleanupExpired() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Remove entradas expiradas do SQLite
      final result = await db.rawDelete('''
        DELETE FROM $_tableName 
        WHERE (timestamp + (ttl_minutes * 60 * 1000)) < ?
      ''', [now]);
      
      // Remove do cache em memória
      _memoryCache.removeWhere((key, entry) => entry.isExpired);
      
    } catch (e) {
    }
  }
  
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }
  
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          SUM(LENGTH(data)) as total_size_bytes,
          COUNT(CASE WHEN (timestamp + (ttl_minutes * 60 * 1000)) < ? THEN 1 END) as expired_entries
        FROM $_tableName
      ''', [DateTime.now().millisecondsSinceEpoch]);
      
      return {
        'total_entries': result.first['total_entries'] ?? 0,
        'total_size_kb': ((result.first['total_size_bytes'] ?? 0) as int) / 1024,
        'expired_entries': result.first['expired_entries'] ?? 0,
        'memory_entries': _memoryCache.length,
        'is_online': await isOnline(),
      };
    } catch (e) {
      return {};
    }
  }
  
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _memoryCache.clear();
  }

  // MÉTODO ADICIONADO AQUI
  Future<void> invalidatePatientCache(String pacienteId) async {
    // Presume que as chaves de cache para dados do paciente contêm o ID do paciente.
    // Ex: '.../pacientes/ID_DO_PACIENTE/...'
    await clear(pattern: pacienteId);
    debugPrint('   [CACHE] Cache invalidado para o paciente $pacienteId');
  }
}