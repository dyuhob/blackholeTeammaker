import '../../domain/member.dart';

Map<String, Object?> memberToRemoteRow(Member member) => {
  'id': member.id,
  'name': member.name,
  'average': member.score,
  'deleted_at': null,
};

Member memberFromRemoteRow(Map<String, Object?> row) => Member(
  id: row['id']! as String,
  name: row['name']! as String,
  score: (row['average']! as num).toInt(),
);
