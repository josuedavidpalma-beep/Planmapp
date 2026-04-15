// Firebase cloud messaging integration (if used)
// importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
// importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

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
