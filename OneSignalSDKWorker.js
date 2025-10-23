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
  console.log('Service Worker: Notification object:', event.notification);
  console.log('Service Worker: Notification data:', event.notification.data);
  console.log('Service Worker: Notification tag:', event.notification.tag);
  console.log('Service Worker: Event action:', event.action);

  event.notification.close();

  // Get the notification data - try multiple locations
  const data = event.notification.data || {};

  // Try to extract from different possible locations (camelCase)
  let chatType = data.chatType;
  let chatId = data.chatId;

  // Fallback to snake_case for backward compatibility
  if (!chatType) {
    chatType = data.chat_type;
    chatId = data.chat_id;
  }

  // If not found, try nested in additionalData
  if (!chatType && data.additionalData) {
    chatType = data.additionalData.chatType || data.additionalData.chat_type;
    chatId = data.additionalData.chatId || data.additionalData.chat_id;
  }

  // If still not found, try to parse from notification tag or other fields
  if (!chatType && event.notification.tag) {
    console.log('Service Worker: Trying to parse from tag:', event.notification.tag);
  }

  console.log('Service Worker: Extracted chat info:', { chatType, chatId });

  // Construct URL with query parameters for deep linking
  let urlToOpen = self.location.origin + '/';

  if (chatType && chatId) {
    urlToOpen = `${self.location.origin}/?openChat=${chatId}&chatType=${chatType}`;
    console.log('Service Worker: Constructed URL with chat params:', urlToOpen);
  } else {
    console.log('Service Worker: No chat data found, using base URL');
    console.log('Service Worker: Available data keys:', Object.keys(data));
  }

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
          console.log('Service Worker: Focusing existing client and navigating to:', urlToOpen);
          // Always navigate to update the URL with chat parameters
          return client.focus().then(() => {
            if (chatType && chatId) {
              return client.navigate(urlToOpen);
            }
            return client;
          });
        }
      }

      // No existing client found, open new window
      console.log('Service Worker: Opening new client at:', urlToOpen);
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});