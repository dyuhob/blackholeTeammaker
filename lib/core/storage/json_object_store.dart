abstract interface class JsonObjectStore {
  Future<Map<String, Object?>?> read();

  Future<void> write(Map<String, Object?> value);
}
