import '../core/storage/json_object_store.dart';
import '../domain/team_result.dart';
import 'team_history_repository.dart';

class JsonTeamHistoryRepository implements TeamHistoryRepository {
  const JsonTeamHistoryRepository(this._store);

  final JsonObjectStore _store;

  @override
  Future<List<TeamResult>> loadAll() async {
    final json = await _store.read();
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
    final index = results.indexWhere((value) => value.id == result.id);
    if (index == -1) {
      results.add(result);
    } else {
      results[index] = result;
    }
    await _writeAll(results);
  }

  @override
  Future<void> delete(String resultId) async {
    final results = await loadAll();
    results.removeWhere((value) => value.id == resultId);
    await _writeAll(results);
  }

  Future<void> _writeAll(List<TeamResult> results) => _store.write({
    'schemaVersion': 1,
    'records': results.map((result) => result.toJson()).toList(),
  });
}
