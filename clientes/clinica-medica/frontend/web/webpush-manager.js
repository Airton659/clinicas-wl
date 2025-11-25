// webpush-manager.js
// Gerencia subscriptions Web Push VAPID no navegador

console.log('[VAPID-JS] WebPush Manager carregado');

window.WebPushManager = {
  /**
   * Cria uma subscription Web Push usando a chave VAPID
   * @param {string} vapidPublicKey - Chave pública VAPID em Base64
   * @returns {Promise<Object>} Subscription object ou null
   */
  async subscribe(vapidPublicKey) {
    try {
      console.log('[VAPID-JS] Iniciando subscription...');

      // 1. Verifica suporte
      if (!('serviceWorker' in navigator)) {
        console.error('[VAPID-JS] Service Worker não suportado');
        return null;
      }

      if (!('PushManager' in window)) {
        console.error('[VAPID-JS] Push não suportado neste navegador');
        return null;
      }

      // 2. Pega registration do service worker
      const registration = await navigator.serviceWorker.ready;
      console.log('[VAPID-JS] Service Worker pronto');

      // 3. Verifica se já existe subscription
      let subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        console.log('[VAPID-JS] Subscription existente encontrada');
        return this._serializeSubscription(subscription);
      }

      // 4. Converte chave VAPID para Uint8Array
      const applicationServerKey = this._urlBase64ToUint8Array(vapidPublicKey);

      // 5. Cria nova subscription
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: applicationServerKey
      });

      console.log('[VAPID-JS] ✅ Subscription criada com sucesso!');
      return this._serializeSubscription(subscription);

    } catch (error) {
      console.error('[VAPID-JS] ❌ Erro ao criar subscription:', error);
      return null;
    }
  },

  /**
   * Converte Base64 URL-safe para Uint8Array
   * @param {string} base64String - String Base64
   * @returns {Uint8Array}
   */
  _urlBase64ToUint8Array(base64String) {
    const padding = '='.repeat((4 - base64String.length % 4) % 4);
    const base64 = (base64String + padding)
      .replace(/\-/g, '+')
      .replace(/_/g, '/');

    const rawData = window.atob(base64);
    const outputArray = new Uint8Array(rawData.length);

    for (let i = 0; i < rawData.length; ++i) {
      outputArray[i] = rawData.charCodeAt(i);
    }
    return outputArray;
  },

  /**
   * Serializa subscription para formato JSON
   * @param {PushSubscription} subscription
   * @returns {Object}
   */
  _serializeSubscription(subscription) {
    const json = subscription.toJSON();

    return {
      endpoint: json.endpoint,
      keys: {
        p256dh: json.keys.p256dh,
        auth: json.keys.auth
      }
    };
  },

  /**
   * Remove subscription existente
   * @returns {Promise<boolean>}
   */
  async unsubscribe() {
    try {
      if (!('serviceWorker' in navigator)) {
        return false;
      }

      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        await subscription.unsubscribe();
        console.log('[VAPID-JS] Subscription removida');
        return true;
      }

      return false;
    } catch (error) {
      console.error('[VAPID-JS] Erro ao remover subscription:', error);
      return false;
    }
  },

  /**
   * Verifica se já existe uma subscription
   * @returns {Promise<Object|null>}
   */
  async getExistingSubscription() {
    try {
      if (!('serviceWorker' in navigator)) {
        return null;
      }

      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();

      if (subscription) {
        return this._serializeSubscription(subscription);
      }

      return null;
    } catch (error) {
      console.error('[VAPID-JS] Erro ao verificar subscription:', error);
      return null;
    }
  }
};

// Torna disponível globalmente
console.log('[VAPID-JS] ✅ WebPushManager pronto para uso');
