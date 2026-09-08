import '../domain/workspace_state.dart';

abstract interface class WorkspaceRepository {
  Future<WorkspaceState?> load();

  Future<void> save(WorkspaceState state);
}
