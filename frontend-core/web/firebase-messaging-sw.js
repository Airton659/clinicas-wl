// Service Worker combinado: Firebase Messaging + APNs + PWA Cache
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Configuração do Firebase
firebase.initializeApp({
  apiKey: "AIzaSyC073ifaNVWcVwFi4e3agdl-yX7aaKsMwk",
  authDomain: "teste-notificacao-barbearia.firebaseapp.com",
  projectId: "teste-notificacao-barbearia",
  storageBucket: "teste-notificacao-barbearia.firebasestorage.app",
  messagingSenderId: "862082955632",
  appId: "1:862082955632:web:ae8823c881d702d79cb7b5"
});

const messaging = firebase.messaging();
const CACHE_NAME = 'concierge-analice-grubert-v2'; // Atualizado para forçar refresh do cache

// ===== FUNÇÕES AUXILIARES PARA DETECTAR TIPO DE NOTIFICAÇÃO =====

/**
 * Verifica se a mensagem é do FCM (Firebase Cloud Messaging)
 */
function isFCMMessage(payload) {
  return payload.from || payload.fcmMessageId || payload.notification || payload.data;
}

/**
 * Verifica se a mensagem é do APNs (Apple Push Notification service)
 * APNs usa o formato {aps: {alert: {title, body}}}
 */
function isAPNsMessage(payload) {
  return payload.aps && payload.aps.alert;
}

/**
 * Processa payload e extrai informações padronizadas
 */
function extractNotificationData(payload) {
  let title, body, data, tipo;

  if (isAPNsMessage(payload)) {
    // Formato APNs
    console.log('[SW] 🍎 Processando mensagem APNs');
    title = payload.aps.alert.title || 'Nova Notificação';
    body = payload.aps.alert.body || '';
    data = { ...payload }; // Todos os dados extras do APNs
    tipo = payload.tipo || payload.type || 'default';

  } else if (isFCMMessage(payload)) {
    // Formato FCM
    console.log('[SW] 🔥 Processando mensagem FCM');
    title = payload.notification?.title || payload.data?.title || 'Nova Notificação';
    body = payload.notification?.body || payload.data?.body || payload.data?.message || 'Você tem uma atualização';
    data = payload.data || {};
    tipo = data.tipo || data.type || 'default';

  } else {
    // Formato desconhecido
    console.log('[SW] ❓ Formato de mensagem desconhecido');
    title = 'Nova Notificação';
    body = 'Você tem uma atualização';
    data = payload;
    tipo = 'default';
  }

  return { title, body, data, tipo };
}

// Handle generic push events (FCM e APNs)
self.addEventListener('push', (event) => {
  console.log('[SW] 📩 Received push event');

  if (!event.data) {
    console.log('[SW] ⚠️ Push event sem dados');
    return;
  }

  try {
    const payload = event.data.json();
    console.log('[SW] 📦 Push payload:', JSON.stringify(payload, null, 2));

    // Verifica se algum cliente (tab) está focado
    event.waitUntil(
      self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
        const isAnyClientFocused = clients.some(client => client.focused);

        if (isAnyClientFocused) {
          console.log('[SW] ⚠️ App está aberto e focado, NÃO mostrando notificação (Flutter vai processar)');
          // Apenas notifica os clientes, não mostra notificação
          clients.forEach(client => {
            client.postMessage({
              type: 'notification-received',
              data: payload.data
            });
          });
        } else {
          console.log('[SW] 🔔 App está em background, mostrando notificação do sistema');
          return handleNotificationMessage(payload);
        }
      })
    );
  } catch (error) {
    console.error('[SW] ❌ Erro ao processar push event:', error);
  }
});

/**
 * Processa e exibe uma notificação (FCM ou APNs)
 */
function handleNotificationMessage(payload) {
  console.log('[SW] 🔔 Processando notificação...');

  // Extrai dados padronizados
  const { title, body, data, tipo } = extractNotificationData(payload);

  console.log('[SW] 📝 Notificação extraída:', { title, body, tipo });

  // Gera tag única baseada no tipo e IDs
  let tag = tipo || 'default';
  if (data.consulta_id) tag += '-consulta-' + data.consulta_id;
  if (data.relatorioId || data.relatorio_id) tag += '-relatorio-' + (data.relatorioId || data.relatorio_id);
  if (data.pacienteId || data.paciente_id) tag += '-paciente-' + (data.pacienteId || data.paciente_id);
  if (data.tarefaId || data.tarefa_id) tag += '-tarefa-' + (data.tarefaId || data.tarefa_id);
  if (data.exame_id) tag += '-exame-' + data.exame_id;
  if (data.suporte_id) tag += '-suporte-' + data.suporte_id;

  console.log('[SW] 🏷️ Tag da notificação:', tag);

  const notificationOptions = {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: tag, // Mesma tag = substitui ao invés de duplicar
    requireInteraction: false,
    data: data,
    vibrate: [300, 100, 300, 100, 300],
    silent: false,
    renotify: false,
    timestamp: Date.now(),
    dir: 'auto',
    lang: 'pt-BR'
  };

  // Exibe notificação e atualiza badge
  return Promise.all([
    self.registration.showNotification(title, notificationOptions),
    // Incrementa badge
    navigator.setAppBadge ? navigator.setAppBadge(1).catch(() => {}) : Promise.resolve(),
    // Notifica todos os clientes (Flutter) para atualizar
    self.clients.matchAll({ includeUncontrolled: true, type: 'window' }).then(clients => {
      clients.forEach(client => {
        client.postMessage({
          type: 'notification-received',
          data: data
        });
      });
    })
  ]).then(() => {
    console.log('[SW] ✅ Notificação exibida com sucesso');
  }).catch((error) => {
    console.error('[SW] ❌ Erro ao exibir notificação:', error);
  });
}

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('Notification clicked:', event);
  event.notification.close();

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Try to focus existing window
      for (const client of clientList) {
        if (client.url === '/' && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new window if none exists
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
