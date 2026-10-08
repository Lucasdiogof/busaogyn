{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: {
    // CanvasKit servido pelo próprio host (build/web/canvaskit/) em vez do
    // CDN gstatic: um terceiro a menos e o shell abre mesmo sem rede.
    canvasKitBaseUrl: 'canvaskit/',
  },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.getElementById('splash')?.remove();
  },
});
