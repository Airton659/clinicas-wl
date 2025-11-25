// lib/services/cache_manager_web.dart
// Implementação específica para Web usando localStorage/sessionStorage

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

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
      'data': data,
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
      data: map['data'] as T,
      ttl: Duration(minutes: ttlMinutes),
      userId: map['user_id'],
      negocioId: map['negocio_id'],
      timestamp: storedTimestamp,
    );
  }
}

class CacheManager {
  static const String _storagePrefix = 'cache_';
  final Map<String, CacheEntry> _memoryCache = {};
  static CacheManager? _instance;

  CacheManager._internal();

  static CacheManager get instance {
    _instance ??= CacheManager._internal();
    return _instance!;
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

    // Busca no localStorage
    try {
      final storageKey = '$_storagePrefix$cacheKey';
      final storedValue = web.window.localStorage.getItem(storageKey);

      if (storedValue != null) {
        final Map<String, dynamic> map = jsonDecode(storedValue);
        final entry = CacheEntry<T>.fromMap(map);

        if (!entry.isExpired) {
          _memoryCache[cacheKey] = entry;
          return entry.data;
        } else {
          // Cache expirado - remove do localStorage
          web.window.localStorage.removeItem(storageKey);
        }
      }
    } catch (e) {
      debugPrint('Erro ao ler cache: $e');
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

    // Armazena no localStorage
    try {
      final storageKey = '$_storagePrefix$cacheKey';
      final value = jsonEncode(entry.toMap());
      web.window.localStorage.setItem(storageKey, value);
    } catch (e) {
      debugPrint('Erro ao salvar cache: $e');
      // Se localStorage estiver cheio, tenta limpar caches expirados
      await cleanupExpired();
      try {
        final storageKey = '$_storagePrefix$cacheKey';
        final value = jsonEncode(entry.toMap());
        web.window.localStorage.setItem(storageKey, value);
      } catch (e2) {
        debugPrint('Erro ao salvar cache após limpeza: $e2');
      }
    }
  }

  Future<void> clear({String? pattern, String? userId, String? negocioId}) async {
    try {
      if (pattern != null) {
        // Remove por padrão no localStorage
        final keysToRemove = <String>[];
        final storage = web.window.localStorage;
        for (var i = 0; i < storage.length; i++) {
          final key = storage.key(i);
          if (key != null && key.startsWith(_storagePrefix) && key.contains(pattern)) {
            keysToRemove.add(key);
          }
        }
        for (var key in keysToRemove) {
          storage.removeItem(key);
        }
        _memoryCache.removeWhere((key, value) => key.contains(pattern));
      } else {
        // Remove tudo
        final keysToRemove = <String>[];
        final storage = web.window.localStorage;
        for (var i = 0; i < storage.length; i++) {
          final key = storage.key(i);
          if (key != null && key.startsWith(_storagePrefix)) {
            keysToRemove.add(key);
          }
        }
        for (var key in keysToRemove) {
          storage.removeItem(key);
        }
        _memoryCache.clear();
      }
    } catch (e) {
      debugPrint('Erro ao limpar cache: $e');
    }
  }

  Future<void> cleanupExpired() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final keysToRemove = <String>[];
      final storage = web.window.localStorage;

      for (var i = 0; i < storage.length; i++) {
        final key = storage.key(i);
        if (key == null || !key.startsWith(_storagePrefix)) continue;

        try {
          final value = storage.getItem(key);
          if (value != null) {
            final map = jsonDecode(value);
            final timestamp = map['timestamp'] as int;
            final ttlMinutes = map['ttl_minutes'] as int;
            final expiresAt = timestamp + (ttlMinutes * 60 * 1000);

            if (expiresAt < now) {
              keysToRemove.add(key);
            }
          }
        } catch (e) {
          // Se falhar ao parsear, remove a chave
          keysToRemove.add(key);
        }
      }

      for (var key in keysToRemove) {
        storage.removeItem(key);
      }

      _memoryCache.removeWhere((key, entry) => entry.isExpired);

      debugPrint('Cache cleanup: ${keysToRemove.length} entradas removidas');
    } catch (e) {
      debugPrint('Erro ao limpar cache expirado: $e');
    }
  }

  Future<bool> isOnline() async {
    try {
      return web.window.navigator.onLine;
    } catch (e) {
      return true;
    }
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      int totalEntries = 0;
      int totalSizeBytes = 0;
      int expiredEntries = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final storage = web.window.localStorage;

      for (var i = 0; i < storage.length; i++) {
        final key = storage.key(i);
        if (key == null || !key.startsWith(_storagePrefix)) continue;

        totalEntries++;
        final value = storage.getItem(key);
        if (value != null) {
          totalSizeBytes += value.length;

          try {
            final map = jsonDecode(value);
            final timestamp = map['timestamp'] as int;
            final ttlMinutes = map['ttl_minutes'] as int;
            final expiresAt = timestamp + (ttlMinutes * 60 * 1000);

            if (expiresAt < now) {
              expiredEntries++;
            }
          } catch (e) {
            // Ignora erros de parse
          }
        }
      }

      return {
        'total_entries': totalEntries,
        'total_size_kb': totalSizeBytes / 1024,
        'expired_entries': expiredEntries,
        'memory_entries': _memoryCache.length,
        'is_online': await isOnline(),
      };
    } catch (e) {
      return {};
    }
  }

  Future<void> dispose() async {
    _memoryCache.clear();
  }

  Future<void> invalidatePatientCache(String pacienteId) async {
    await clear(pattern: pacienteId);
    debugPrint('   [CACHE] Cache invalidado para o paciente $pacienteId');
  }
}
