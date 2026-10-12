(() => {
  const base = new URL('.', document.baseURI);
  const workerURL = new URL('push/sw.js', base);
  const scope = new URL('push/', base).href;
  const isIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const standalone = () => matchMedia('(display-mode: standalone)').matches || navigator.standalone === true;
  const status = () => !isSecureContext ? 'https_required' :
    isIOS() && !standalone() ? 'install_required' :
    !('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)
      ? 'unsupported' : Notification.permission;
  window.cafePushStatus = () => status();
  function publicKey(value) {
    const padded = value.replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(padded + '='.repeat((4 - padded.length % 4) % 4)), c => c.charCodeAt(0));
  }
  function validateConfig(config) {
    if (!config || typeof config !== 'object' || typeof config.url !== 'string' || typeof config.token !== 'string' || !config.token.trim() || typeof config.key !== 'string' || !config.key.trim()) throw Error('Push authentication is missing. Sign in again.');
    const url = new URL(config.url);
    if (url.protocol !== 'https:' || !/^[a-z0-9]{20}\.supabase\.co$/.test(url.hostname) || url.port || url.username || url.password || url.pathname !== '/' || url.search || url.hash) throw Error('Invalid push service');
    return url;
  }
  async function api(config, action, subscription) {
    const url = validateConfig(config);
    const response = await fetch(new URL('/functions/v1/browser-push', url), {
      method: 'POST', headers: {'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + config.token, 'apikey': config.key},
      body: JSON.stringify({action, subscription, expires_at: config.expires}),
      signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw Error('Push setup failed (' + response.status + '). Ask an administrator to check deployment.');
    // Successful endpoints may return 204 No Content; do not misreport success as failure.
    if (response.status === 204) return {};
    const body = await response.text();
    return body ? JSON.parse(body) : {};
  }
  window.cafePushEnable = async (raw) => {
    const config = JSON.parse(raw);
    validateConfig(config);
    if (!config.vapid) throw Error('Push service is not configured yet.');
    const state = status();
    if (state === 'install_required') throw Error('Add this website to your Home Screen, open its icon, then enable notifications.');
    if (['unsupported', 'https_required', 'denied'].includes(state)) throw Error('Notifications unavailable or blocked. Check browser notification settings.');
    // Must begin directly inside the user's tap, before any asynchronous work.
    const permission = Notification.permission === 'granted' ? 'granted' : await Notification.requestPermission();
    if (permission !== 'granted') throw Error('Notification permission was not granted.');
    // A worker and scope must belong to the current site; do not accept an external registration.
    if (workerURL.origin !== location.origin || new URL(scope).origin !== location.origin) throw Error('Invalid push worker origin');
    const registration = await navigator.serviceWorker.register(workerURL.href, {scope});
    if (!registration.active) {
      await new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(Error('Push service activation timed out')), 12000);
        const worker = registration.installing || registration.waiting;
        if (!worker) {clearTimeout(timer); reject(Error('Push service unavailable')); return;}
        const check = () => {if (worker.state === 'activated') {clearTimeout(timer); resolve();}};
        worker.addEventListener('statechange', check); check();
      });
    }
    // A new subscription prevents another employee inheriting this device's alerts.
    const previous = await registration.pushManager.getSubscription();
    if (previous) {
      await api(config, 'unsubscribe', previous.toJSON());
      if (!await previous.unsubscribe()) throw Error('Could not reset the previous notification subscription');
    }
    const subscription = await registration.pushManager.subscribe({userVisibleOnly: true, applicationServerKey: publicKey(config.vapid)});
    try { await api(config, 'subscribe', subscription.toJSON()); }
    catch (error) {await subscription.unsubscribe(); throw error;}
    return 'Notifications enabled on this device. Send a test to check delivery.';
  };
  window.cafePushTest = async (raw) => {
    const config = JSON.parse(raw);
    validateConfig(config);
    if (status() !== 'granted') throw Error('Browser notification permission is not granted.');
    const registration = await navigator.serviceWorker.getRegistration(scope);
    const subscription = await registration?.pushManager.getSubscription();
    if (!subscription) throw Error('Enable notifications first.');
    await api(config, 'test', subscription.toJSON());
    return 'Test accepted by the push service. Check your device notifications.';
  };
  window.cafePushDisable = async (raw) => {
    if (!('serviceWorker' in navigator)) return 'Notifications off';
    const registration = await navigator.serviceWorker.getRegistration(scope);
    const subscription = await registration?.pushManager.getSubscription();
    if (subscription) {
      if (!raw) throw Error('Sign in to turn off notifications securely.');
      const config = JSON.parse(raw);
      validateConfig(config);
      await api(config, 'unsubscribe', subscription.toJSON());
      if (!await subscription.unsubscribe()) throw Error('Could not turn off notifications');
    }
    return 'Notifications turned off on this device';
  };
})();
