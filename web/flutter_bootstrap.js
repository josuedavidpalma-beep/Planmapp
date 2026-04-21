{{flutter_js}}
{{flutter_build_config}}

function showUpdateBanner(worker) {
  const banner = document.createElement('div');
  banner.style.position = 'fixed';
  banner.style.bottom = '24px';
  banner.style.left = '50%';
  banner.style.transform = 'translateX(-50%)';
  banner.style.backgroundColor = '#6200EE'; // Planmapp primary brand purple
  banner.style.color = '#FFFFFF';
  banner.style.padding = '12px 24px';
  banner.style.borderRadius = '30px';
  banner.style.boxShadow = '0 10px 25px rgba(0,0,0,0.5)';
  banner.style.fontFamily = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';
  banner.style.fontSize = '14px';
  banner.style.fontWeight = 'bold';
  banner.style.zIndex = '9999999';
  banner.style.cursor = 'pointer';
  banner.style.display = 'flex';
  banner.style.alignItems = 'center';
  banner.style.gap = '8px';
  
  banner.innerHTML = '<span>🚀 ¡Nueva versión disponible! Toca para actualizar.</span>';
  
  banner.onclick = () => {
    banner.innerHTML = '<span>⏳ Limpiando sistema...</span>';
    // Tell old SW to skip waiting
    worker.postMessage({ type: 'SKIP_WAITING' });
    
    // Nuke all browser caches forcefully
    caches.keys().then((names) => {
        return Promise.all(names.map(name => caches.delete(name)));
    }).then(() => {
        // Hard reload bypassing cache
        window.location.reload(true);
    }).catch(()=> {
        window.location.reload(true);
    });
  };
  
  document.body.appendChild(banner);
}

// 1. Setup PWA Update Listener natively
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    // We register the service worker that Flutter will generate
    navigator.serviceWorker.register('flutter_service_worker.js').then((reg) => {
      
      // Listen for a new service worker being installed in the background
      reg.addEventListener('updatefound', () => {
        const newWorker = reg.installing;
        if (newWorker) {
          newWorker.addEventListener('statechange', () => {
            // Once the new code is fully downloaded and ready but waiting...
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              console.log("Nueva versión detectada y lista en caché.");
              showUpdateBanner(newWorker);
            }
          });
        }
      });
    });

    let refreshing = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      // The new SW just took control! Reload the page if we haven't already
      if (!refreshing) {
        refreshing = true;
        window.location.reload(true);
      }
    });

  });
}

// 2. Standard Flutter Bootstrapping
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }
});
