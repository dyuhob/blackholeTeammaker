import '../../domain/team_result.dart';
import 'sync_outcome.dart';

abstract interface class HistorySync {
  Future<SyncOutcome<List<TeamResult>>> synchronize(List<TeamResult> visible);
  Future<void> acceptRemote(List<TeamResult> snapshot);
}
