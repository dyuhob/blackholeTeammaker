{{flutter_js}}
{{flutter_build_config}}

(() => {
  const dismissedKey = 'team_maker.pwa_install_dismissed_at';
  const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
  let deferredPrompt = null;

  const isStandalone = () =>
    window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;

  window.addEventListener('beforeinstallprompt', (event) => {
    event.preventDefault();
    deferredPrompt = event;
  });

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    window.localStorage.removeItem(dismissedKey);
  });

  window.teamMakerPwaInstall = {
    shouldShow() {
      if (isStandalone()) return false;
      let raw = null;
      try {
        raw = window.localStorage.getItem(dismissedKey);
      } catch (_) {
        return true;
      }
      if (raw === null) return true;
      const dismissedAt = Number(raw);
      return !Number.isFinite(dismissedAt) ||
        Date.now() - dismissedAt >= sevenDaysMs;
    },
    canPrompt() {
      return deferredPrompt !== null;
    },
    isIos() {
      return /iphone|ipad|ipod/i.test(window.navigator.userAgent);
    },
    prompt() {
      if (deferredPrompt === null) return;
      const prompt = deferredPrompt;
      deferredPrompt = null;
      prompt.prompt();
      prompt.userChoice.then((choice) => {
        if (choice.outcome !== 'accepted') this.dismiss();
      });
    },
    dismiss() {
      try {
        window.localStorage.setItem(dismissedKey, String(Date.now()));
      } catch (_) {
        // Storage can be unavailable in private browsing; the app still works.
      }
    },
  };
})();

window.addEventListener('flutter-first-frame', () => {
  document.getElementById('loading-indicator')?.remove();
});

_flutter.loader.load();
