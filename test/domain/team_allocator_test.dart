import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_allocator.dart';

void main() {
  Participant regular(String id, int score) => Participant(
    id: id,
    sourceMemberId: id,
    name: '회원 $id',
    score: score,
    type: ParticipantType.regular,
  );

  Participant manual(String id, int score) => Participant(
    id: id,
    name: '임시 $id',
    score: score,
    type: ParticipantType.manualTemporary,
  );

  Participant automatic(String id) => Participant(
    id: id,
    name: '참가자 (자동)',
    score: 160,
    type: ParticipantType.autoTemporary,
  );

  test('allocation fills every team and balances temporary counts', () {
    var nextId = 0;
    final allocator = TeamAllocator(
      random: Random(7),
      idFactory: () => 'auto-${nextId++}',
    );
    final regulars = [
      regular('1', 180),
      regular('2', 160),
      regular('3', 190),
      regular('4', 140),
      regular('5', 175),
      regular('6', 155),
      regular('7', 145),
    ];

    final teams = allocator.allocate(
      regularMembers: regulars,
      manualTemporaryMembers: [manual('m1', 150)],
      teamSize: 3,
    );

    expect(teams, hasLength(3));
    expect(teams.every((team) => team.participants.length == 3), isTrue);
    final temporaryCounts = teams
        .map(
          (team) => team.participants
              .where((participant) => participant.type.isTemporary)
              .length,
        )
        .toList();
    expect(
      temporaryCounts.reduce(max) - temporaryCounts.reduce(min),
      lessThanOrEqualTo(1),
    );
    final automaticParticipants = teams
        .expand((team) => team.participants)
        .where(
          (participant) => participant.type == ParticipantType.autoTemporary,
        )
        .toList();
    expect(automaticParticipants, hasLength(1));
    expect(automaticParticipants.single.name, '게스트 1 (자동)');
    expect(automaticParticipants.single.score, 160);
    expect(teams.map((team) => team.number), [1, 2, 3]);
    expect(
      teams.first.rawScore,
      teams.map((team) => team.rawScore).reduce(max),
    );
    for (final team in teams) {
      final automaticStart = team.participants.indexWhere(
        (participant) => participant.type == ParticipantType.autoTemporary,
      );
      final scoredParticipants = automaticStart == -1
          ? team.participants
          : team.participants.sublist(0, automaticStart);
      expect(
        scoredParticipants.map((participant) => participant.score),
        orderedEquals(
          scoredParticipants.map((participant) => participant.score).toList()
            ..sort((left, right) => right.compareTo(left)),
        ),
      );
      if (automaticStart != -1) {
        expect(
          team.participants
              .sublist(automaticStart)
              .every(
                (participant) =>
                    participant.type == ParticipantType.autoTemporary,
              ),
          isTrue,
        );
      }
    }
  });

  test(
    'score compensation reaches the highest score and shows full-team gap',
    () {
      final allocator = TeamAllocator(random: Random(1), idFactory: () => 'id');
      final teams = [
        Team(
          number: 1,
          participants: [
            regular('a', 180),
            regular('b', 160),
            manual('m', 150),
          ],
        ),
        Team(
          number: 2,
          participants: [regular('c', 190), regular('d', 140), automatic('x')],
        ),
        Team(
          number: 3,
          participants: [
            regular('e', 175),
            regular('f', 155),
            regular('g', 145),
          ],
        ),
      ];

      final balanced = allocator.compensateScores(teams);

      expect(balanced[0].rawScore, 490);
      expect(balanced[0].bonusScore, 0);
      expect(
        balanced[1].participants.last.score,
        160,
        reason: 'the automatic member must close the 160 point gap',
      );
      expect(balanced[1].rawScore, 490);
      expect(balanced[2].rawScore, 475);
      expect(balanced[2].bonusScore, 15);
    },
  );

  test(
    'automatic participant scores stay at 160 and remaining gap is shown',
    () {
      final allocator = TeamAllocator(random: Random(1), idFactory: () => 'id');

      final balanced = allocator.compensateScores([
        Team(
          number: 1,
          participants: [regular('high', 300), regular('high2', 151)],
        ),
        Team(number: 2, participants: [automatic('x'), automatic('y')]),
      ]);

      expect(
        balanced[1].participants.map((participant) => participant.score),
        orderedEquals([160, 160]),
      );
      expect(balanced[1].bonusScore, 131);
    },
  );

  test('large score gap does not change automatic participant scores', () {
    final allocator = TeamAllocator(random: Random(1), idFactory: () => 'id');

    final balanced = allocator.compensateScores([
      Team(
        number: 1,
        participants: [
          regular('high', 300),
          regular('high2', 300),
          regular('high3', 100),
        ],
      ),
      Team(number: 2, participants: [automatic('x'), automatic('y')]),
    ]);

    expect(
      balanced[1].participants.map((participant) => participant.score),
      orderedEquals([160, 160]),
    );
    expect(balanced[1].bonusScore, 380);
    expect(balanced[1].effectiveScore, 700);
  });
}
