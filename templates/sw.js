// 🌿 Greenmind Service Worker — PWA offline support
const CACHE = 'greenmind-v2';
const STATIC = [
  '/',
  '/static/style.css',
  '/static/manifest.json',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(STATIC)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // API & WS: không cache, luôn network
  if (url.pathname.startsWith('/api/') || url.pathname.startsWith('/ws/')) {
    return;
  }
  // Static + pages: cache-first
  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(resp => {
        if (resp.ok && e.request.method === 'GET') {
          const clone = resp.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return resp;
      }).catch(() => cached);
    })
  );
});

// Push notification khi có alert (từ dashboard qua postMessage)
self.addEventListener('message', e => {
  if (e.data && e.data.type === 'ALERT') {
    self.registration.showNotification('🚨 Greenmind Alert', {
      body: `${e.data.cam}: ${e.data.description || e.data.label_vn}`,
      icon: '/static/icon-192.png',
      badge: '/static/icon-192.png',
      tag: 'greenmind-alert',
      renotify: true,
      data: { cam: e.data.cam }
    });
  }
});

self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(clients.openWindow('/'));
});
