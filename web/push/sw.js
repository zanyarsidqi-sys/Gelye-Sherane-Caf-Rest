self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('push', event => {
  // Never put customer names, payment amounts, or confidential report text on a lock screen.
  let tag = 'cafe-update', version = null;
  try {
    const data = event.data?.json();
    if (/^[a-z0-9_-]{1,100}$/i.test(data?.tag)) tag = data.tag;
    if (typeof data?.version === 'string' && /^[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,9}$/.test(data.version)) version = data.version;
  } catch (_) {}
  event.waitUntil(self.registration.showNotification('Gelye Sherane Café & Restaurant', {
    body: version ? `Update ${version} is available. Save your work, then reopen the app.` : 'You have a new work notification. Open the app to view it.',
    icon: new URL('../icons/Icon-192.png', self.registration.scope).href,
    tag,
    data: {url: new URL('../', self.registration.scope).href},
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  // Always use our own application URL, never a URL supplied in a push payload.
  const url = new URL('../', self.registration.scope).href;
  event.waitUntil(clients.matchAll({type: 'window', includeUncontrolled: true}).then(async windows => {
    const found = windows.find(window => window.url.startsWith(url));
    if (found) return found.focus();
    return clients.openWindow(url);
  }));
});
