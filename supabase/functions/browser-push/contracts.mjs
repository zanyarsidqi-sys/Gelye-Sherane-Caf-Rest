export function validateSubscription(input) {
  if (!input || typeof input.endpoint !== 'string' || input.endpoint.length > 2048) throw Error('Invalid subscription');
  const url = new URL(input.endpoint);
  const allowed = ['fcm.googleapis.com','web.push.apple.com','updates.push.services.mozilla.com'];
  if (url.protocol !== 'https:' || !allowed.includes(url.hostname) || url.port || url.username || url.password || url.hash) throw Error('Unsupported push endpoint');
  if (!/^[A-Za-z0-9_-]{87}$/.test(input.keys?.p256dh) || !/^[A-Za-z0-9_-]{22}$/.test(input.keys?.auth)) throw Error('Invalid subscription keys');
  return {endpoint: url.href, keys: {p256dh: input.keys.p256dh, auth: input.keys.auth}};
}
export function validateExpiry(value, now = Date.now()) {
  if (value == null) return null;
  const time = Date.parse(value);
  if (typeof value !== 'string' || !Number.isFinite(time) || time <= now || time > now + 366 * 86400000) throw Error('Invalid notification expiry');
  return new Date(time).toISOString();
}
export function publicPayload(tag, version = null) {
  const payload = {tag: /^[a-z0-9_-]{1,100}$/i.test(tag) ? tag : 'cafe-update'};
  if (typeof version === 'string' && /^[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,9}$/.test(version)) payload.version = version;
  return JSON.stringify(payload);
}
