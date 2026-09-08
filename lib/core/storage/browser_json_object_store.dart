import 'dart:convert';

import 'package:web/web.dart' as web;

import 'json_object_store.dart';

final class BrowserJsonObjectStore implements JsonObjectStore {
  const BrowserJsonObjectStore(this.key);

  final String key;

  @override
  Future<Map<String, Object?>?> read() async {
    final source = web.window.localStorage.getItem(key);
    if (source == null) return null;
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('JSON root must be an object.');
    }
    return decoded;
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    web.window.localStorage.setItem(key, jsonEncode(value));
  }
}
