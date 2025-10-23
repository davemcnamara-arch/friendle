importScripts('https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.sw.js');

const CACHE_NAME = 'friendle-v1';
const urlsToCache = [
  '/',
  '/index.html'
];

// Install event - cache core files
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch event - serve from cache when offline
self.addEventListener('fetch', event => {
  event.respondWith(
    fetch(event.request)
      .catch(() => caches.match(event.request))
  );
});

// Handle notification clicks - focus existing client instead of opening new window
self.addEventListener('notificationclick', event => {
  console.log('Service Worker: Notification clicked', event);

  event.notification.close();

  // Get the notification data
  const data = event.notification.data || {};
  const urlToOpen = data.url || '/';

  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    })
    .then(clientList => {
      console.log('Service Worker: Found', clientList.length, 'clients');

      // Try to focus an existing client
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        console.log('Service Worker: Checking client', client.url);

        if (client.url.includes(self.location.origin)) {
          console.log('Service Worker: Focusing existing client');
          // Navigate the client to the notification URL if needed
          if (urlToOpen && urlToOpen !== '/') {
            client.navigate(urlToOpen);
          }
          return client.focus();
        }
      }

      // No existing client found, open new window
      console.log('Service Worker: Opening new client');
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});