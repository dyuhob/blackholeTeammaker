import '../../domain/participant.dart';
import '../../domain/team.dart';
import '../../domain/team_result.dart';

Map<String, Object?> teamResultToRemotePayload(TeamResult result) => {
  'client_id': result.id,
  'name': result.title,
  'created_at': result.createdAt.toUtc().toIso8601String(),
  'group_count': result.teams.length,
  'group_size': result.teamSize,
  'highest_average': result.teams.fold<int>(
    0,
    (highest, team) => team.rawScore > highest ? team.rawScore : highest,
  ),
  'participants': [
    for (final team in result.teams)
      for (final participant in team.participants)
        {
          'client_id': participant.id,
          'user_id': participant.sourceMemberId,
          'name': participant.name,
          'average': participant.score,
          'team_no': team.number,
          'auto_insert': switch (participant.type) {
            ParticipantType.regular => null,
            ParticipantType.manualTemporary => 0,
            ParticipantType.autoTemporary => 1,
          },
          'deleted_at': null,
        },
  ],
};

TeamResult teamResultFromRemoteRows(
  Map<String, Object?> game,
  List<Map<String, Object?>> participantRows,
) {
  final highestScore = (game['highest_average']! as num).toInt();
  final byTeam = <int, List<Participant>>{};
  for (final row in participantRows) {
    if (row['deleted_at'] != null) continue;
    final teamNumber = (row['team_no']! as num).toInt();
    final memberId = row['user_id']?.toString();
    final autoInsert = (row['auto_insert'] as num?)?.toInt();
    final type = memberId != null
        ? ParticipantType.regular
        : autoInsert == 1
        ? ParticipantType.autoTemporary
        : ParticipantType.manualTemporary;
    byTeam
        .putIfAbsent(teamNumber, () => [])
        .add(
          Participant(
            id: row['client_id']! as String,
            sourceMemberId: memberId,
            name: row['name']! as String,
            score: (row['average']! as num).toInt(),
            type: type,
          ),
        );
  }
  for (final participants in byTeam.values) {
    participants.sort((left, right) {
      final leftAuto = left.type == ParticipantType.autoTemporary;
      final rightAuto = right.type == ParticipantType.autoTemporary;
      if (leftAuto != rightAuto) return leftAuto ? 1 : -1;
      final scoreOrder = right.score.compareTo(left.score);
      if (scoreOrder != 0) return scoreOrder;
      return left.name.compareTo(right.name);
    });
  }
  final teams =
      byTeam.entries
          .map(
            (entry) => Team(
              number: entry.key,
              participants: entry.value,
              bonusScore:
                  highestScore -
                  entry.value.fold<int>(0, (sum, value) => sum + value.score),
            ),
          )
          .toList()
        ..sort((left, right) => left.number.compareTo(right.number));
  return TeamResult(
    id: game['client_id']! as String,
    title: game['name']! as String,
    createdAt: DateTime.parse(game['created_at']! as String),
    teamSize: (game['group_size']! as num).toInt(),
    teams: teams,
  );
}
