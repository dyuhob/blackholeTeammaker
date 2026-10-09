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

  test('legacy gender and handicap fields default to zero values', () {
    final member = Member.fromJson({'id': 'm', 'name': '남성', 'score': 180});
    final participant = Participant.fromJson({
      'id': 'p',
      'sourceMemberId': 'm',
      'name': '남성',
      'score': 180,
      'type': 'regular',
    });

    expect(member.gender, MemberGender.male);
    expect(participant.gender, MemberGender.male);
    expect(participant.handicapScore, 0);
    expect(participant.effectiveScore, 180);
  });

  test('female gender and each applied handicap survive JSON round trips', () {
    final member = Member(
      id: 'female',
      name: '여성',
      score: 180,
      gender: MemberGender.female,
    );
    final first = Participant(
      id: 'first',
      name: '여성 1',
      score: 180,
      type: ParticipantType.regular,
      gender: MemberGender.female,
      handicapScore: 12,
    );
    final second = Participant(
      id: 'second',
      name: '여성 2',
      score: 170,
      type: ParticipantType.regular,
      gender: MemberGender.female,
      handicapScore: 12,
    );

    expect(Member.fromJson(member.toJson()), member);
    expect(Participant.fromJson(first.toJson()), first);
    expect(first.effectiveScore, 192);
    expect(Team(number: 1, participants: [first, second]).rawScore, 374);
  });

  test('member rejects scores below zero and above 300', () {
    expect(() => Member(id: 'low', name: '낮음', score: -1), throwsArgumentError);
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
