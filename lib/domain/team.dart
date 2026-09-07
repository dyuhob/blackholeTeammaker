import 'participant.dart';

class Team {
  const Team({
    required this.number,
    required this.participants,
    this.bonusScore = 0,
  });

  final int number;
  final List<Participant> participants;
  final int bonusScore;

  int get rawScore => participants.fold(0, (sum, member) => sum + member.score);
  int get effectiveScore => rawScore + bonusScore;

  Team copyWith({List<Participant>? participants, int? bonusScore}) => Team(
    number: number,
    participants: participants ?? this.participants,
    bonusScore: bonusScore ?? this.bonusScore,
  );

  Map<String, Object> toJson() => {
    'number': number,
    'bonusScore': bonusScore,
    'participants': participants.map((member) => member.toJson()).toList(),
  };

  factory Team.fromJson(Map<String, Object?> json) => Team(
    number: json['number']! as int,
    bonusScore: json['bonusScore']! as int,
    participants: (json['participants']! as List<Object?>)
        .map((value) => Participant.fromJson(value! as Map<String, Object?>))
        .toList(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          other.number == number &&
          other.bonusScore == bonusScore &&
          _listEquals(other.participants, participants);

  @override
  int get hashCode =>
      Object.hash(number, bonusScore, Object.hashAll(participants));
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
