const CACHE_NAME = 'egesut-20260308-v2';
const ASSETS_TO_CACHE = [
  './',
  './index.html',
  './manifest.json',
  './js/api.js',
  './js/app.js',
  './js/ui.js',
  './js/forms.js',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(ASSETS_TO_CACHE))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  if (event.request.url.includes('supabase.co')) return;
  event.respondWith(
    caches.match(event.request).then(r => r || fetch(event.request))
  );
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then(wins => {
      if (wins.length > 0) wins[0].focus();
      else clients.openWindow('./index.html');
    })
  );
});
