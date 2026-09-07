import '../domain/team_result.dart';

abstract interface class TeamHistoryRepository {
  Future<List<TeamResult>> loadAll();
  Future<void> save(TeamResult result);
  Future<void> delete(String resultId);
}
