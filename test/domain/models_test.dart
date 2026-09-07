import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  test('member JSON round trip preserves identity, name, and score', () {
    final member = Member(id: 'member-1', name: '김회원', score: 180);

    expect(Member.fromJson(member.toJson()), member);
  });

  test('member rejects scores below zero and above 300', () {
    expect(
      () => Member(id: 'low', name: '낮음', score: -1),
      throwsArgumentError,
    );
    expect(
      () => Member(id: 'high', name: '높음', score: 301),
      throwsArgumentError,
    );
  });

  test('team result JSON round trip keeps a historical snapshot', () {
    final result = TeamResult(
      id: 'result-1',
      title: '일요일 팀 편성',
      createdAt: DateTime.parse('2026-09-07T20:30:00+09:00'),
      teamSize: 2,
      teams: [
        Team(
          number: 1,
          bonusScore: 15,
          participants: [
            Participant(
              id: 'participant-1',
              sourceMemberId: 'member-1',
              name: '김회원',
              score: 180,
              type: ParticipantType.regular,
            ),
            Participant(
              id: 'participant-2',
              name: '임시 회원 1',
              score: 150,
              type: ParticipantType.manualTemporary,
            ),
          ],
        ),
      ],
    );

    final restored = TeamResult.fromJson(result.toJson());

    expect(restored, result);
    expect(restored.teams.single.rawScore, 330);
    expect(restored.teams.single.effectiveScore, 345);
  });
}
