// lib/services/cache_manager_factory.dart

import 'cache_manager.dart' if (dart.library.html) 'cache_manager_web.dart';

/// Factory para obter a implementação correta do CacheManager
/// baseada na plataforma (web ou mobile)
CacheManager getCacheManager() {
  return CacheManager.instance;
}
