// firebase-messaging-sw.js
importScripts("https://www.gstatic.com/firebasejs/10.12.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.1/firebase-messaging.js");

// Initialize Firebase (use your own config here)
firebase.initializeApp({
  apiKey: "AIzaSyCfNNgktvU_h0vP5TFqpuAifXBKtzx9MKU",
  authDomain: "friendle-9baaf.firebaseapp.com",
  projectId: "friendle-9baaf",
  storageBucket: "friendle-9baaf.firebasestorage.app",
  messagingSenderId: "336987179049",
  appId: "1:336987179049:web:218bbeba0b0d105a79b438",
  measurementId: "G-2CYHT7JYG6"
});

// Retrieve Firebase Messaging instance
const messaging = firebase.messaging();

// Handle background notifications
messaging.onBackgroundMessage((payload) => {
  console.log("Received background message:", payload);
  const { title, body } = payload.notification;
  self.registration.showNotification(title, {
    body,
    icon: "/icon-192.png" // optional: small icon for notification
  });
});
