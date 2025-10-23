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
  console.log('🔔 SW: Notification clicked', event);
  console.log('📦 SW: Full notification object:', JSON.stringify(event.notification, null, 2));

  event.notification.close();

  // Get the notification data - OneSignal stores it in event.notification.data
  const data = event.notification.data || {};
  console.log('📦 SW: Notification data:', JSON.stringify(data, null, 2));
  console.log('📦 SW: Data keys:', Object.keys(data));

  // Try to extract chat info from different possible locations
  let chatType = data.chatType || data.chat_type;
  let chatId = data.chatId || data.chat_id;

  // Check if data is nested (sometimes OneSignal nests custom data)
  if (!chatType && typeof data === 'object') {
    // Try to find chatType in any nested object
    for (const key in data) {
      if (data[key] && typeof data[key] === 'object') {
        chatType = data[key].chatType || data[key].chat_type;
        chatId = data[key].chatId || data[key].chat_id;
        if (chatType) {
          console.log('📦 SW: Found chat data nested in key:', key);
          break;
        }
      }
    }
  }

  console.log('✅ SW: Extracted chat info:', { chatType, chatId });

  // Construct URL with query parameters for deep linking
  let urlToOpen = self.location.origin + '/';

  if (chatType && chatId) {
    urlToOpen = `${self.location.origin}/?openChat=${chatId}&chatType=${chatType}`;
    console.log('🔗 SW: Constructed URL with chat params:', urlToOpen);
  } else {
    console.log('⚠️ SW: No chat data found, using base URL');
  }

  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    })
    .then(clientList => {
      console.log('👥 SW: Found', clientList.length, 'clients');

      // Try to focus an existing client
      for (let i = 0; i < clientList.length; i++) {
        const client = clientList[i];
        console.log('🔍 SW: Checking client', client.url);

        if (client.url.includes(self.location.origin)) {
          console.log('✅ SW: Focusing existing client and navigating to:', urlToOpen);
          // Always navigate to update the URL with chat parameters
          return client.focus().then(() => {
            if (chatType && chatId) {
              console.log('🚀 SW: Navigating client to:', urlToOpen);
              return client.navigate(urlToOpen);
            }
            return client;
          });
        }
      }

      // No existing client found, open new window
      console.log('🆕 SW: Opening new client at:', urlToOpen);
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});