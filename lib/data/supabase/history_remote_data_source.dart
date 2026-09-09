import '../../domain/team_result.dart';
import '../sync/pending_mutation.dart';

abstract interface class HistoryRemoteDataSource {
  Future<void> push(PendingMutation mutation);
  Future<List<TeamResult>> fetchAll();
}
