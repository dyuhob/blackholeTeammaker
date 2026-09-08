{{flutter_js}}
{{flutter_build_config}}

window.addEventListener('flutter-first-frame', () => {
  document.getElementById('loading-indicator')?.remove();
});

_flutter.loader.load();
