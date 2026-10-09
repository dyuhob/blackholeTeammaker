import 'member.dart';

enum ParticipantType {
  regular(0),
  manualTemporary(1),
  autoTemporary(2);

  const ParticipantType(this.order);

  final int order;

  bool get isTemporary => this != ParticipantType.regular;
}

class Participant {
  Participant({
    required this.id,
    this.sourceMemberId,
    required String name,
    required this.score,
    required this.type,
    this.gender = MemberGender.male,
    this.handicapScore = 0,
  }) : name = name.trim() {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'ID는 비어 있을 수 없습니다.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', '이름을 입력해 주세요.');
    }
    if (score < 0 || score > 300) {
      throw ArgumentError.value(score, 'score', '점수는 0~300이어야 합니다.');
    }
  }

  final String id;
  final String? sourceMemberId;
  final String name;
  final int score;
  final ParticipantType type;
  final MemberGender gender;
  final int handicapScore;

  int get effectiveScore => score + handicapScore;

  Participant copyWith({
    String? name,
    int? score,
    MemberGender? gender,
    int? handicapScore,
  }) => Participant(
    id: id,
    sourceMemberId: sourceMemberId,
    name: name ?? this.name,
    score: score ?? this.score,
    type: type,
    gender: gender ?? this.gender,
    handicapScore: handicapScore ?? this.handicapScore,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'sourceMemberId': sourceMemberId,
    'name': name,
    'score': score,
    'type': type.name,
    'gender': gender.storageValue,
    'handicapScore': handicapScore,
  };

  factory Participant.fromJson(Map<String, Object?> json) => Participant(
    id: json['id']! as String,
    sourceMemberId: json['sourceMemberId'] as String?,
    name: json['name']! as String,
    score: json['score']! as int,
    type: ParticipantType.values.byName(json['type']! as String),
    gender: MemberGender.fromStorage(json['gender']),
    handicapScore: json['handicapScore'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Participant &&
          other.id == id &&
          other.sourceMemberId == sourceMemberId &&
          other.name == name &&
          other.score == score &&
          other.type == type &&
          other.gender == gender &&
          other.handicapScore == handicapScore;

  @override
  int get hashCode =>
      Object.hash(id, sourceMemberId, name, score, type, gender, handicapScore);
}
