import '../../domain/team_result.dart';
import '../json_team_history_repository.dart';
import '../supabase/history_remote_data_source.dart';
import 'history_sync.dart';
import 'sync_outcome.dart';

class HistorySyncCoordinator implements HistorySync {
  HistorySyncCoordinator({required this.local, required this.remote});

  final JsonTeamHistoryRepository local;
  final HistoryRemoteDataSource remote;
  Future<SyncOutcome<List<TeamResult>>>? _inFlight;

  @override
  Future<SyncOutcome<List<TeamResult>>> synchronize(List<TeamResult> visible) {
    final previous = _inFlight;
    final snapshot = [...visible];
    final future = previous == null
        ? _run(snapshot)
        : previous.then((_) => _run(snapshot));
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
  }

  Future<SyncOutcome<List<TeamResult>>> _run(List<TeamResult> visible) async {
    try {
      final document = await local.readSyncDocument();
      for (final mutation in document.pendingMutations) {
        await remote.push(mutation);
        await local.acknowledgeMutation(mutation.id);
      }
      final snapshot = await remote.fetchAll();
      if (_historyEqualIgnoringOrder(visible, snapshot)) {
        return const SyncOutcome.unchanged();
      }
      return SyncOutcome.remoteChanged(snapshot);
    } on Object catch (error) {
      return SyncOutcome.offline(error);
    }
  }

  @override
  Future<void> acceptRemote(List<TeamResult> snapshot) =>
      local.replaceHistoryFromRemote(snapshot);
}

bool _historyEqualIgnoringOrder(List<TeamResult> left, List<TeamResult> right) {
  if (left.length != right.length) return false;
  final leftById = {for (final value in left) value.id: value};
  final rightById = {for (final value in right) value.id: value};
  if (leftById.length != rightById.length) return false;
  for (final entry in leftById.entries) {
    if (rightById[entry.key] != entry.value) return false;
  }
  return true;
}
