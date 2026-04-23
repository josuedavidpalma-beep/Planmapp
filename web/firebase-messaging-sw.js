importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing config
firebase.initializeApp({
  apiKey: 'AIzaSyDV_cJqok1orHMKC2GcmfjoEQIOA9CcLig',
  appId: '1:215284322468:web:adca5f29737c1db7761631',
  messagingSenderId: '215284322468',
  projectId: 'plan-mapp2-dgp8y5',
  authDomain: 'plan-mapp2-dgp8y5.firebaseapp.com',
  storageBucket: 'plan-mapp2-dgp8y5.firebasestorage.app',
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || "Nueva Notificación (Planmapp)";
  const notificationOptions = {
    body: payload.notification?.body || "Tienes mensajes nuevos, entra a revisarlos.",
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data
  };
  
  if (payload.data?.action === 'debt_reminder') {
    notificationOptions.actions = [
      { action: 'pay_now', title: '📲 Pagar ahora' },
      { action: 'chat_org', title: '💬 Hablar con Organizador' }
    ];
  }

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Deep link handler for Push Notifications in PWA
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  
  let targetUrl = self.registration.scope + '?nav=notifications';
  
  if (event.notification.data?.action === 'debt_reminder') {
      if (event.action === 'chat_org') {
          targetUrl = self.registration.scope + '?nav=peer_chat&peer_id=' + event.notification.data.org_id;
      } else if (event.action === 'pay_now') {
          targetUrl = self.registration.scope + '?nav=debts'; // Optional: pass expense_id
      } else {
          targetUrl = self.registration.scope + '?nav=debts'; // Default if they just tap the notification
      }
  } else if (event.notification.data?.route) {
      targetUrl = self.registration.scope + '?nav=' + event.notification.data.route.replace('/', '');
  }
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          return client.focus().then(c => c.navigate(targetUrl));
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// PWA Cache Interceptor for Supabase Offline Data (Master System)
self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('plan_members') || event.request.url.includes('plans')) {
    event.respondWith(
      caches.open('planmaps-v1').then((cache) => {
        return fetch(event.request)
          .then((response) => { 
              cache.put(event.request, response.clone()); 
              return response; 
          })
          .catch(() => cache.match(event.request)); 
      })
    );
  }
});
