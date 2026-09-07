import '../core/storage/atomic_json_file.dart';
import '../domain/team_result.dart';
import 'team_history_repository.dart';

class FileTeamHistoryRepository implements TeamHistoryRepository {
  const FileTeamHistoryRepository(this._file);

  final AtomicJsonFile _file;

  @override
  Future<List<TeamResult>> loadAll() async {
    final json = await _file.read();
    if (json == null) return <TeamResult>[];
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported history schema version.');
    }
    final results = (json['records']! as List<Object?>)
        .map((value) => TeamResult.fromJson(value! as Map<String, Object?>))
        .toList();
    results.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return results;
  }

  @override
  Future<void> save(TeamResult result) async {
    final results = await loadAll();
    final existingIndex = results.indexWhere((value) => value.id == result.id);
    if (existingIndex == -1) {
      results.add(result);
    } else {
      results[existingIndex] = result;
    }
    await _writeAll(results);
  }

  @override
  Future<void> delete(String resultId) async {
    final results = await loadAll();
    results.removeWhere((value) => value.id == resultId);
    await _writeAll(results);
  }

  Future<void> _writeAll(List<TeamResult> results) => _file.write({
    'schemaVersion': 1,
    'records': results.map((result) => result.toJson()).toList(),
  });
}
