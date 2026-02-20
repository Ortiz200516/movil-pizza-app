importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.8.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDfNBRtaaEsbGYdqG2_WO5xIUsrCW9FXdY",
  authDomain: "app-pizzeria-ecuador-2005.firebaseapp.com",
  projectId: "app-pizzeria-ecuador-2005",
  storageBucket: "app-pizzeria-ecuador-2005.firebasestorage.app",
  messagingSenderId: "407730041770",
  appId: "1:407730041770:web:d9842f5093d43a9bc031d3"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('Mensaje recibido en background: ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});