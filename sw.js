// Service Worker devre dışı — cache sorunu yaşatıyor
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.map(k => caches.delete(k))))
  );
  self.clients.claim();
});
// Fetch handler yok — tüm istekler direkt ağa gider
