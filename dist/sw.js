/*
 * 应用壳缓存：房源文字和媒体将由后续的 IndexedDB 逻辑保存，
 * 不会写入此缓存，也不会上传至任何服务器。
 */
// Keep this suffix in sync with window.__APP_VERSION__ in index.html.
const CACHE_NAME = 'property-record-shell-v1.0.0';
const APP_SHELL = ['./', './index.html', './manifest.json'];
const STATIC_PATHS = new Set(
  APP_SHELL.map((path) => new URL(path, self.registration.scope).pathname)
);

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith('property-record-shell-') && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Only static application-shell paths are intercepted. Listing media, JSON exports,
// IndexedDB-backed data, and any future runtime URLs are deliberately never cached.
self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);

  if (
    request.method !== 'GET' ||
    url.origin !== self.location.origin ||
    url.search ||
    !STATIC_PATHS.has(url.pathname)
  ) {
    return;
  }

  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;
      return fetch(request);
    })
  );
});
