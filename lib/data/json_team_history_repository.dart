import '../core/storage/json_object_store.dart';
import '../domain/team_result.dart';
import 'sync/history_sync_document.dart';
import 'sync/pending_mutation.dart';
import 'team_history_repository.dart';

class JsonTeamHistoryRepository implements TeamHistoryRepository {
  const JsonTeamHistoryRepository(this._store);

  final JsonObjectStore _store;

  @override
  Future<List<TeamResult>> loadAll() async {
    final results = [...(await readSyncDocument()).records];
    results.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return results;
  }

  Future<HistorySyncDocument> readSyncDocument() async {
    final json = await _store.read();
    if (json == null) return const HistorySyncDocument();
    final version = json['schemaVersion'];
    if (version != 1 && version != 2) {
      throw const FormatException('Unsupported history schema version.');
    }
    final records = (json['records']! as List<Object?>)
        .map((value) => TeamResult.fromJson(value! as Map<String, Object?>))
        .toList();
    final pending = version == 1
        ? <PendingMutation>[]
        : (json['pendingMutations']! as List<Object?>)
              .map(
                (value) =>
                    PendingMutation.fromJson(value! as Map<String, Object?>),
              )
              .toList();
    return HistorySyncDocument(records: records, pendingMutations: pending);
  }

  @override
  Future<void> save(TeamResult result) async {
    final document = await readSyncDocument();
    final records = [...document.records];
    final index = records.indexWhere((value) => value.id == result.id);
    if (index == -1) {
      records.add(result);
    } else {
      records[index] = result;
    }
    final mutation = PendingMutation(
      id: createMutationId(SyncMutationKind.upsert, result.id, result.hashCode),
      entityId: result.id,
      kind: SyncMutationKind.upsert,
      payload: result.toJson(),
    );
    await writeSyncDocument(
      HistorySyncDocument(
        records: records,
        pendingMutations: compactMutation(document.pendingMutations, mutation),
      ),
    );
  }

  @override
  Future<void> delete(String resultId) async {
    final document = await readSyncDocument();
    final records = [...document.records]
      ..removeWhere((value) => value.id == resultId);
    final mutation = PendingMutation(
      id: createMutationId(SyncMutationKind.delete, resultId, resultId),
      entityId: resultId,
      kind: SyncMutationKind.delete,
      payload: {'id': resultId},
    );
    await writeSyncDocument(
      HistorySyncDocument(
        records: records,
        pendingMutations: compactMutation(document.pendingMutations, mutation),
      ),
    );
  }

  Future<void> writeSyncDocument(HistorySyncDocument document) =>
      _store.write(document.toJson());

  Future<void> acknowledgeMutation(String mutationId) async {
    final document = await readSyncDocument();
    await writeSyncDocument(
      document.copyWith(
        pendingMutations: document.pendingMutations
            .where((value) => value.id != mutationId)
            .toList(),
      ),
    );
  }

  Future<void> replaceHistoryFromRemote(List<TeamResult> records) async {
    await writeSyncDocument(HistorySyncDocument(records: [...records]));
  }
}
