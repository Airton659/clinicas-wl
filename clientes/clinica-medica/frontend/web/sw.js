// Service Worker para PWA com cache offline
const CACHE_NAME = 'analice-grubert-v1';
const RUNTIME_CACHE = 'runtime-cache-v1';

// Assets para cache imediato (install)
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/flutter.js',
  '/main.dart.js',
];

// Install - faz precache dos assets essenciais
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Precaching assets');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
  );
});

// Activate - limpa caches antigos
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME && name !== RUNTIME_CACHE)
          .map((name) => {
            console.log('[SW] Deleting old cache:', name);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch - estratégia Network First com fallback para cache
self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Ignora requisições não-HTTP
  if (!request.url.startsWith('http')) {
    return;
  }

  // Para requisições de API - Network First
  if (request.url.includes('/api/') || request.url.includes('firestore') || request.url.includes('firebase')) {
    event.respondWith(
      fetch(request)
        .then((response) => {
          // Clona a resposta para salvar no cache
          const responseClone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseClone);
          });
          return response;
        })
        .catch(() => {
          // Se offline, tenta buscar do cache
          return caches.match(request);
        })
    );
    return;
  }

  // Para assets estáticos - Cache First
  event.respondWith(
    caches.match(request)
      .then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }

        return fetch(request).then((response) => {
          // Não cacheia se não for uma resposta válida
          if (!response || response.status !== 200 || response.type === 'error') {
            return response;
          }

          const responseClone = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => {
            cache.put(request, responseClone);
          });

          return response;
        });
      })
      .catch(() => {
        // Fallback para página offline (opcional)
        if (request.destination === 'document') {
          return caches.match('/index.html');
        }
      })
  );
});

// Background Sync (para quando voltar online)
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync:', event.tag);
  if (event.tag === 'sync-data') {
    event.waitUntil(syncData());
  }
});

async function syncData() {
  // Implementar lógica de sincronização quando voltar online
  console.log('[SW] Syncing data...');
  // Aqui você pode implementar a lógica para sincronizar dados pendentes
}

// Push Notifications (Web Push VAPID + FCM híbrido)
self.addEventListener('push', (event) => {
  console.log('[SW] Push received:', event);

  let data = {};
  if (event.data) {
    try {
      data = event.data.json();
    } catch (e) {
      data = { title: 'Nova notificação', body: event.data.text() };
    }
  }

  const title = data.notification?.title || data.title || 'Analice Grubert';
  const body = data.notification?.body || data.body || 'Você tem uma nova notificação';
  const tipo = data.tipo || data.data?.tipo;

  const options = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.tag || tipo || 'default',
    requireInteraction: ['LEMBRETE_EXAME', 'TAREFA_ATRASADA', 'LEMBRETE_AGENDADO'].includes(tipo),
    data: {
      tipo: tipo,
      exame_id: data.exame_id || data.data?.exame_id,
      tarefa_id: data.tarefa_id || data.data?.tarefa_id,
      paciente_id: data.paciente_id || data.data?.paciente_id,
      url: data.url || data.data?.url
    },
    actions: data.actions || []
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Notification Click - Redireciona conforme tipo de notificação
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event);
  event.notification.close();

  const data = event.notification.data;
  let urlToOpen = '/';

  // Determinar URL baseado no tipo de notificação
  if (data.tipo === 'LEMBRETE_EXAME' && data.exame_id) {
    urlToOpen = `/exames/${data.exame_id}`;
  } else if (data.tipo === 'TAREFA_ATRASADA' && data.tarefa_id) {
    urlToOpen = `/tarefas/${data.tarefa_id}`;
  } else if (data.tipo === 'LEMBRETE_AGENDADO') {
    urlToOpen = '/notificacoes';
  } else if (data.url) {
    urlToOpen = data.url;
  }

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Tenta focar em uma janela existente
        for (const client of clientList) {
          if ('focus' in client) {
            return client.focus().then(() => {
              // Envia mensagem para navegação
              client.postMessage({
                type: 'NAVIGATE',
                url: urlToOpen
              });
            });
          }
        }
        // Abre nova janela se não existir
        if (clients.openWindow) {
          return clients.openWindow(urlToOpen);
        }
      })
  );
});

// Message - comunicação com o app
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);

  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data && event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(RUNTIME_CACHE).then((cache) => {
        return cache.addAll(event.data.urls);
      })
    );
  }
});
