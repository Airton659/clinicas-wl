// web/safari-webpush.js
// Helper JavaScript para Web Push no Safari (APNs)
// Este arquivo contém funções para trabalhar com Web Push nativo do Safari

/**
 * Verifica se o navegador suporta Web Push
 */
function isWebPushSupported() {
  return 'serviceWorker' in navigator &&
         'PushManager' in window &&
         'Notification' in window;
}

/**
 * Verifica se é Safari
 */
function isSafari() {
  const ua = navigator.userAgent;
  return ua.indexOf('Safari') !== -1 &&
         ua.indexOf('Chrome') === -1 &&
         ua.indexOf('Chromium') === -1;
}

/**
 * Obtém o status atual da permissão de notificação
 */
function getNotificationPermissionStatus() {
  if (!('Notification' in window)) {
    return 'not-supported';
  }
  return Notification.permission; // 'default', 'granted', 'denied'
}

/**
 * Solicita permissão de notificação (Safari)
 * Retorna Promise<string> com o status: 'granted', 'denied', 'default'
 */
async function requestNotificationPermission() {
  console.log('[Safari WebPush] Solicitando permissão de notificação...');

  if (!('Notification' in window)) {
    console.error('[Safari WebPush] Notificações não suportadas neste navegador');
    throw new Error('Notificações não suportadas');
  }

  try {
    // No Safari, usa Notification.requestPermission() que retorna uma Promise
    const permission = await Notification.requestPermission();
    console.log('[Safari WebPush] Permissão:', permission);
    return permission;
  } catch (error) {
    console.error('[Safari WebPush] Erro ao solicitar permissão:', error);
    throw error;
  }
}

/**
 * Registra Service Worker e obtém subscription para Web Push
 * IMPORTANTE: Para Safari, não precisa de applicationServerKey (VAPID)
 * O Safari usa APNs automaticamente quando o site está instalado
 */
async function subscribeToWebPush() {
  console.log('[Safari WebPush] Iniciando inscrição para Web Push...');

  if (!isWebPushSupported()) {
    throw new Error('Web Push não suportado neste navegador');
  }

  try {
    // Aguarda o Service Worker estar pronto
    const registration = await navigator.serviceWorker.ready;
    console.log('[Safari WebPush] Service Worker pronto:', registration);

    // Verifica se já existe uma subscription ativa
    let subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      console.log('[Safari WebPush] ✅ Subscription já existe:', subscription);
      return subscription;
    }

    // Cria nova subscription
    // NOTA: Para Safari, não precisa passar applicationServerKey
    // O Safari usa APNs automaticamente
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      // applicationServerKey não é necessário para Safari
      // Safari usa APNs Web Push automaticamente
    });

    console.log('[Safari WebPush] ✅ Nova subscription criada:', subscription);
    return subscription;

  } catch (error) {
    console.error('[Safari WebPush] ❌ Erro ao criar subscription:', error);
    throw error;
  }
}

/**
 * Extrai o token APNs da subscription
 * Safari usa um formato diferente do FCM
 */
function extractApnsTokenFromSubscription(subscription) {
  if (!subscription) {
    throw new Error('Subscription é null ou undefined');
  }

  try {
    // Safari usa o endpoint da subscription como identificador
    // Formato: https://web.push.apple.com/[TOKEN]
    const endpoint = subscription.endpoint;
    console.log('[Safari WebPush] Endpoint:', endpoint);

    // Para Safari, o endpoint completo É o token que enviamos para o backend
    // O backend sabe processar esse formato
    return endpoint;

  } catch (error) {
    console.error('[Safari WebPush] Erro ao extrair token:', error);
    throw error;
  }
}

/**
 * Remove subscription de Web Push
 */
async function unsubscribeFromWebPush() {
  console.log('[Safari WebPush] Removendo subscription...');

  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      const successful = await subscription.unsubscribe();
      console.log('[Safari WebPush] Subscription removida:', successful);
      return successful;
    }

    console.log('[Safari WebPush] Nenhuma subscription ativa para remover');
    return true;

  } catch (error) {
    console.error('[Safari WebPush] Erro ao remover subscription:', error);
    throw error;
  }
}

/**
 * Fluxo completo: pedir permissão + criar subscription + retornar token
 * Esta é a função principal que o Flutter vai chamar
 */
async function initializeSafariWebPush() {
  console.log('//======================================================//');
  console.log('// 🍎 SAFARI WEB PUSH INITIALIZATION');
  console.log('//======================================================//');

  try {
    // 1. Verifica suporte
    if (!isWebPushSupported()) {
      throw new Error('Web Push não suportado');
    }
    console.log('   [✓] Web Push suportado');

    // 2. Verifica se é Safari
    const isSafariBrowser = isSafari();
    console.log('   [?] É Safari?', isSafariBrowser);

    // 3. Verifica permissão atual
    const currentPermission = getNotificationPermissionStatus();
    console.log('   [?] Permissão atual:', currentPermission);

    // 4. Se permissão não foi concedida, solicita
    if (currentPermission !== 'granted') {
      console.log('   [!] Solicitando permissão...');
      const permission = await requestNotificationPermission();

      if (permission !== 'granted') {
        throw new Error('Permissão de notificação negada pelo usuário');
      }
      console.log('   [✓] Permissão concedida!');
    } else {
      console.log('   [✓] Permissão já concedida anteriormente');
    }

    // 5. Cria subscription
    console.log('   [!] Criando subscription...');
    const subscription = await subscribeToWebPush();
    console.log('   [✓] Subscription criada!');

    // 6. Extrai token
    const apnsToken = extractApnsTokenFromSubscription(subscription);
    console.log('   [✓] Token APNs extraído!');
    console.log('   [TOKEN]:', apnsToken.substring(0, 50) + '...');

    console.log('//======================================================//');
    console.log('// ✅ SAFARI WEB PUSH PRONTO PARA USO');
    console.log('//======================================================//');

    return {
      success: true,
      token: apnsToken,
      subscription: subscription,
      endpoint: subscription.endpoint
    };

  } catch (error) {
    console.log('//======================================================//');
    console.log('// ❌ ERRO NA INICIALIZAÇÃO DO SAFARI WEB PUSH');
    console.log('//======================================================//');
    console.error('   [ERROR]:', error.message);
    console.error('   [STACK]:', error.stack);

    return {
      success: false,
      error: error.message,
      errorStack: error.stack
    };
  }
}

/**
 * Verifica se já existe subscription ativa
 */
async function checkExistingSubscription() {
  try {
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();

    if (subscription) {
      const token = extractApnsTokenFromSubscription(subscription);
      return {
        hasSubscription: true,
        token: token,
        endpoint: subscription.endpoint
      };
    }

    return {
      hasSubscription: false,
      token: null
    };

  } catch (error) {
    console.error('[Safari WebPush] Erro ao verificar subscription:', error);
    return {
      hasSubscription: false,
      error: error.message
    };
  }
}

// Expõe as funções globalmente para o Flutter poder chamar
window.SafariWebPush = {
  isSupported: isWebPushSupported,
  isSafari: isSafari,
  getPermissionStatus: getNotificationPermissionStatus,
  requestPermission: requestNotificationPermission,
  subscribe: subscribeToWebPush,
  unsubscribe: unsubscribeFromWebPush,
  extractToken: extractApnsTokenFromSubscription,
  initialize: initializeSafariWebPush,
  checkExisting: checkExistingSubscription
};

console.log('✅ Safari WebPush helper carregado');
