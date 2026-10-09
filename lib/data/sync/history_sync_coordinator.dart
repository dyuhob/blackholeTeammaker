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
    final remote = rightById[entry.key];
    if (remote == null || !_persistedHistoryEqual(entry.value, remote)) {
      return false;
    }
  }
  return true;
}

bool _persistedHistoryEqual(TeamResult left, TeamResult right) {
  if (left.id != right.id ||
      left.title != right.title ||
      left.createdAt != right.createdAt ||
      left.teamSize != right.teamSize ||
      left.teams.length != right.teams.length) {
    return false;
  }
  for (var teamIndex = 0; teamIndex < left.teams.length; teamIndex++) {
    final leftTeam = left.teams[teamIndex];
    final rightTeam = right.teams[teamIndex];
    if (leftTeam.number != rightTeam.number ||
        leftTeam.bonusScore != rightTeam.bonusScore ||
        leftTeam.participants.length != rightTeam.participants.length) {
      return false;
    }
    for (
      var participantIndex = 0;
      participantIndex < leftTeam.participants.length;
      participantIndex++
    ) {
      final leftParticipant = leftTeam.participants[participantIndex];
      final rightParticipant = rightTeam.participants[participantIndex];
      if (leftParticipant.id != rightParticipant.id ||
          leftParticipant.sourceMemberId != rightParticipant.sourceMemberId ||
          leftParticipant.name != rightParticipant.name ||
          leftParticipant.score != rightParticipant.score ||
          leftParticipant.type != rightParticipant.type ||
          leftParticipant.handicapScore != rightParticipant.handicapScore) {
        return false;
      }
    }
  }
  return true;
}
