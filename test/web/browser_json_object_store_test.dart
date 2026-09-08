@TestOn('browser')
library;

import 'package:team_maker/core/storage/browser_json_object_store.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  const key = 'team_maker.browser_store_test';
  const unrelatedKey = 'team_maker.browser_store_test.backup';

  setUp(() {
    web.window.localStorage.removeItem(key);
    web.window.localStorage.removeItem(unrelatedKey);
  });

  tearDown(() {
    web.window.localStorage.removeItem(key);
    web.window.localStorage.removeItem(unrelatedKey);
  });

  test('returns null when the browser key does not exist', () async {
    const store = BrowserJsonObjectStore(key);

    expect(await store.read(), isNull);
  });

  test('writes one JSON value and reads it back', () async {
    const store = BrowserJsonObjectStore(key);
    final value = {'schemaVersion': 1, 'members': <Object>[]};

    await store.write(value);

    expect(await store.read(), value);
    expect(web.window.localStorage.getItem(key), isNotNull);
    expect(web.window.localStorage.getItem(unrelatedKey), isNull);
  });

  test('a write replaces the value stored under the same key', () async {
    const store = BrowserJsonObjectStore(key);
    await store.write({'value': 1});

    await store.write({'value': 2});

    expect(await store.read(), {'value': 2});
  });

  test('throws FormatException for malformed JSON', () async {
    const store = BrowserJsonObjectStore(key);
    web.window.localStorage.setItem(key, '{broken');

    expect(store.read, throwsFormatException);
  });

  test('throws FormatException when the JSON root is not an object', () async {
    const store = BrowserJsonObjectStore(key);
    web.window.localStorage.setItem(key, '[]');

    expect(store.read, throwsFormatException);
  });
}
