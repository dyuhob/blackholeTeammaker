import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/data/supabase/history_row_codec.dart';
import 'package:team_maker/data/supabase/member_row_codec.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  test('member codec maps score to user average', () {
    final member = Member(id: 'member-1', name: '김회원', score: 180);

    expect(memberToRemoteRow(member), {
      'id': 'member-1',
      'name': '김회원',
      'average': 180,
      'deleted_at': null,
    });
    expect(
      memberFromRemoteRow({
        'id': 'member-1',
        'name': '김회원',
        'average': 180,
        'deleted_at': null,
      }),
      member,
    );
  });

  test('history codec preserves participant type and average', () {
    final result = TeamResult(
      id: '10000000-0000-0000-0000-000000000001',
      title: '저녁 경기',
      createdAt: DateTime.utc(2026, 9, 9, 10),
      teamSize: 2,
      teams: [
        Team(
          number: 1,
          participants: [
            Participant(
              id: 'participant-member-1',
              sourceMemberId: 'member-1',
              name: '클럽원',
              score: 180,
              type: ParticipantType.regular,
            ),
            Participant(
              id: 'manual-1',
              name: '수동',
              score: 170,
              type: ParticipantType.manualTemporary,
            ),
          ],
        ),
        Team(
          number: 2,
          bonusScore: 190,
          participants: [
            Participant(
              id: 'auto-1',
              name: '참가자1 (자동)',
              score: 160,
              type: ParticipantType.autoTemporary,
            ),
          ],
        ),
      ],
    );

    final payload = teamResultToRemotePayload(result);
    final participants = payload['participants']! as List<Object?>;

    expect(payload['highest_average'], 350);
    expect(participants[0], containsPair('average', 180));
    expect(participants[0], containsPair('user_id', 'member-1'));
    expect(participants[0], containsPair('auto_insert', null));
    expect(participants[1], containsPair('user_id', null));
    expect(participants[1], containsPair('auto_insert', 0));
    expect(participants[2], containsPair('auto_insert', 1));

    final decoded = teamResultFromRemoteRows({
      'client_id': result.id,
      'name': result.title,
      'created_at': result.createdAt.toIso8601String(),
      'group_size': result.teamSize,
      'highest_average': 350,
      'deleted_at': null,
    }, participants.cast<Map<String, Object?>>().reversed.toList());
    expect(decoded, result);
  });
}
