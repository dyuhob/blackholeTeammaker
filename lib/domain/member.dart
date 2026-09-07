class Member {
  Member({required this.id, required String name, required this.score})
    : name = name.trim() {
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
  final String name;
  final int score;

  Member copyWith({String? name, int? score}) => Member(
    id: id,
    name: name ?? this.name,
    score: score ?? this.score,
  );

  Map<String, Object> toJson() => {'id': id, 'name': name, 'score': score};

  factory Member.fromJson(Map<String, Object?> json) => Member(
    id: json['id']! as String,
    name: json['name']! as String,
    score: json['score']! as int,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Member &&
          other.id == id &&
          other.name == name &&
          other.score == score;

  @override
  int get hashCode => Object.hash(id, name, score);
}
