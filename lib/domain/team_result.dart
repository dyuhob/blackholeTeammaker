import 'team.dart';

class TeamResult {
  const TeamResult({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.teamSize,
    required this.teams,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int teamSize;
  final List<Team> teams;

  int get participantCount =>
      teams.fold(0, (sum, team) => sum + team.participants.length);

  TeamResult copyWith({String? title}) => TeamResult(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    teamSize: teamSize,
    teams: teams,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'teamSize': teamSize,
    'teams': teams.map((team) => team.toJson()).toList(),
  };

  factory TeamResult.fromJson(Map<String, Object?> json) => TeamResult(
    id: json['id']! as String,
    title: json['title']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    teamSize: json['teamSize']! as int,
    teams: (json['teams']! as List<Object?>)
        .map((value) => Team.fromJson(value! as Map<String, Object?>))
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamResult &&
          other.id == id &&
          other.title == title &&
          other.createdAt == createdAt &&
          other.teamSize == teamSize &&
          _listEquals(other.teams, teams);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    teamSize,
    Object.hashAll(teams),
  );
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
