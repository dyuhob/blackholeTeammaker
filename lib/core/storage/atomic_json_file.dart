import 'dart:convert';
import 'dart:io';

import 'json_object_store.dart';

class AtomicJsonFile implements JsonObjectStore {
  const AtomicJsonFile({
    required this.directoryProvider,
    required this.fileName,
  });

  final Future<Directory> Function() directoryProvider;
  final String fileName;

  @override
  Future<Map<String, Object?>?> read() async {
    final directory = await directoryProvider();
    final mainFile = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    final backupFile = File('${mainFile.path}.bak');

    if (!await mainFile.exists()) {
      return _readFileIfValid(backupFile);
    }

    try {
      return await _readFileIfValid(mainFile);
    } on FormatException {
      final backup = await _readFileIfValid(backupFile);
      if (backup == null) rethrow;

      final corruptFile = File(
        '${mainFile.path}.corrupt-${DateTime.now().microsecondsSinceEpoch}',
      );
      await mainFile.rename(corruptFile.path);
      await backupFile.copy(mainFile.path);
      return backup;
    }
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    final directory = await directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final mainFile = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );
    final temporaryFile = File('${mainFile.path}.tmp');
    final backupFile = File('${mainFile.path}.bak');
    await temporaryFile.writeAsString(jsonEncode(value), flush: true);

    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    if (await mainFile.exists()) {
      await mainFile.rename(backupFile.path);
    }
    await temporaryFile.rename(mainFile.path);
  }

  Future<Map<String, Object?>?> _readFileIfValid(File file) async {
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('JSON root must be an object.');
    }
    return decoded;
  }
}
