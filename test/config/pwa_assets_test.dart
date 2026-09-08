import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web manifest describes an installable Korean standalone app', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;

    expect(manifest['name'], '블랙홀 팀짜기');
    expect(manifest['short_name'], '팀짜기');
    expect(manifest['lang'], 'ko');
    expect(manifest['start_url'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['display'], 'standalone');
    expect(manifest['orientation'], 'portrait-primary');
    expect(manifest['theme_color'], '#1976D2');
    expect(manifest['background_color'], '#FFFFFF');

    final icons = manifest['icons']! as List<Object?>;
    expect(
      icons.whereType<Map<String, Object?>>().map((icon) => icon['sizes']),
      containsAll(['192x192', '512x512']),
    );
    expect(
      icons.whereType<Map<String, Object?>>().map((icon) => icon['purpose']),
      containsAll(['any', 'maskable']),
    );
  });

  test('web entrypoint loads Flutter and registers the service worker', () {
    final index = File('web/index.html').readAsStringSync();
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(index, contains('<html lang="ko">'));
    expect(
      index,
      contains(
        'name="viewport" content="width=device-width, initial-scale=1.0"',
      ),
    );
    expect(index, contains('href="manifest.json"'));
    expect(index, contains('src="flutter_bootstrap.js"'));
    expect(index, contains("register('/service_worker.js')"));
    expect(index, isNot(contains('flutter_service_worker_version')));
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('_flutter.loader.load();'));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
  });

  test(
    'service worker uses network-first caching with navigation fallback',
    () {
      final worker = File('web/service_worker.js').readAsStringSync();

      expect(worker, contains("const CACHE_NAME = 'team-maker-v2'"));
      expect(worker, contains("addEventListener('install'"));
      expect(worker, contains('skipWaiting()'));
      expect(worker, contains("addEventListener('activate'"));
      expect(worker, contains('clients.claim()'));
      expect(worker, contains("addEventListener('fetch'"));
      expect(worker, contains('await fetch(request)'));
      expect(worker, contains('cache.put(request, response.clone())'));
      expect(worker, contains('caches.match(request)'));
      expect(worker, contains("caches.match('/index.html')"));
      expect(worker, contains("'/assets/FontManifest.json'"));
      expect(worker, contains("'/assets/fonts/MaterialIcons-Regular.otf'"));
      expect(worker, contains("'/canvaskit/canvaskit.wasm'"));
      expect(worker, contains("'/canvaskit/chromium/canvaskit.wasm'"));
    },
  );

  test('PWA icons have their declared PNG dimensions', () {
    expect(pngSize('web/favicon.png'), (width: 48, height: 48));
    expect(pngSize('web/icons/Icon-192.png'), (width: 192, height: 192));
    expect(pngSize('web/icons/Icon-512.png'), (width: 512, height: 512));
    expect(pngSize('web/icons/Icon-maskable-192.png'), (
      width: 192,
      height: 192,
    ));
    expect(pngSize('web/icons/Icon-maskable-512.png'), (
      width: 512,
      height: 512,
    ));
  });
}

({int width, int height}) pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
  return (
    width: _readBigEndianInt(bytes, 16),
    height: _readBigEndianInt(bytes, 20),
  );
}

int _readBigEndianInt(List<int> bytes, int offset) =>
    (bytes[offset] << 24) |
    (bytes[offset + 1] << 16) |
    (bytes[offset + 2] << 8) |
    bytes[offset + 3];
