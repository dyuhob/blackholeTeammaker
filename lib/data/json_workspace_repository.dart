import '../core/storage/json_object_store.dart';
import '../domain/workspace_state.dart';
import 'workspace_repository.dart';

class JsonWorkspaceRepository implements WorkspaceRepository {
  const JsonWorkspaceRepository(this._store);

  final JsonObjectStore _store;

  @override
  Future<WorkspaceState?> load() async {
    final json = await _store.read();
    if (json == null) return null;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported workspace schema version.');
    }
    return WorkspaceState.fromJson(json['workspace']! as Map<String, Object?>);
  }

  @override
  Future<void> save(WorkspaceState state) =>
      _store.write({'schemaVersion': 1, 'workspace': state.toJson()});
}
