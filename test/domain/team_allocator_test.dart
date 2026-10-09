import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_allocator.dart';

void main() {
  Participant regular(
    String id,
    int score, {
    MemberGender gender = MemberGender.male,
  }) => Participant(
    id: id,
    sourceMemberId: id,
    name: '회원 $id',
    score: score,
    type: ParticipantType.regular,
    gender: gender,
  );

  Participant manual(
    String id,
    int score, {
    MemberGender gender = MemberGender.male,
  }) => Participant(
    id: id,
    name: '임시 $id',
    score: score,
    type: ParticipantType.manualTemporary,
    gender: gender,
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
      teams.map((team) => team.rawScore).reduce(min),
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

  test('average order spreads score groups and gives automatic guests the lowest score', () {
    var nextId = 0;
    final allocator = TeamAllocator(
      random: Random(7),
      idFactory: () => 'auto-${nextId++}',
    );

    final teams = allocator.allocate(
      regularMembers: [
        regular('high-1', 200),
        regular('high-2', 200),
        regular('high-3', 200),
        regular('low-1', 100),
        regular('low-2', 100),
      ],
      manualTemporaryMembers: const [],
      teamSize: 2,
      mode: TeamAllocationMode.averageOrder,
    );

    expect(teams, hasLength(3));
    expect(
      teams.map(
        (team) => team.participants.map((participant) => participant.score),
      ),
      everyElement(orderedEquals([200, 100])),
    );
    final automaticGuest = teams
        .expand((team) => team.participants)
        .singleWhere(
          (participant) => participant.type == ParticipantType.autoTemporary,
        );
    expect(automaticGuest.score, 100);
  });

  test('random order keeps automatic guests at 160', () {
    final allocator = TeamAllocator(random: Random(7), idFactory: () => 'auto');

    final teams = allocator.allocate(
      regularMembers: [regular('high', 200)],
      manualTemporaryMembers: const [],
      teamSize: 2,
      mode: TeamAllocationMode.random,
    );

    expect(
      teams
          .expand((team) => team.participants)
          .where(
            (participant) => participant.type == ParticipantType.autoTemporary,
          )
          .map((participant) => participant.score),
      everyElement(160),
    );
  });

  test('average order randomizes participants within equal-score groups', () {
    final assignments = <String>{};
    for (var seed = 1; seed <= 10; seed++) {
      final allocator = TeamAllocator(
        random: Random(seed),
        idFactory: () => 'unused',
      );
      final teams = allocator.allocate(
        regularMembers: [
          regular('high-1', 200),
          regular('high-2', 200),
          regular('high-3', 200),
          regular('low-1', 100),
          regular('low-2', 100),
          regular('low-3', 100),
        ],
        manualTemporaryMembers: const [],
        teamSize: 2,
        mode: TeamAllocationMode.averageOrder,
      );
      final pairs =
          teams
              .map(
                (team) =>
                    team.participants.map((value) => value.id).toList()..sort(),
              )
              .map((pair) => pair.join('/'))
              .toList()
            ..sort();
      assignments.add(pairs.join('|'));
    }

    expect(assignments.length, greaterThan(1));
  });

  test('female handicap is applied per participant after allocation', () {
    final allocator = TeamAllocator(
      random: Random(3),
      idFactory: () => 'unused',
    );
    final teams = allocator.allocate(
      regularMembers: [
        regular('female-high', 200, gender: MemberGender.female),
        regular('male-high', 190),
        regular('female-low', 180, gender: MemberGender.female),
        regular('male-low', 170),
      ],
      manualTemporaryMembers: const [],
      teamSize: 2,
      mode: TeamAllocationMode.averageOrder,
      applyFemaleHandicap: true,
    );

    final femaleTeam = teams.singleWhere(
      (team) =>
          team.participants
              .where((value) => value.gender == MemberGender.female)
              .length ==
          2,
    );
    expect(femaleTeam.participants.map((value) => value.handicapScore), [
      12,
      12,
    ]);
    expect(femaleTeam.rawScore, 404);
    expect(
      teams
          .expand((team) => team.participants)
          .where((value) => value.gender != MemberGender.female)
          .map((value) => value.handicapScore),
      everyElement(0),
    );
  });

  test('female manual guests get handicap but automatic guests do not', () {
    var nextId = 0;
    final allocator = TeamAllocator(
      random: Random(4),
      idFactory: () => 'auto-${nextId++}',
    );
    final teams = allocator.allocate(
      regularMembers: [regular('male', 180), regular('low', 150)],
      manualTemporaryMembers: [
        manual('female-guest', 170, gender: MemberGender.female),
      ],
      teamSize: 2,
      applyFemaleHandicap: true,
    );
    final participants = teams.expand((team) => team.participants);

    expect(
      participants
          .singleWhere((value) => value.id == 'female-guest')
          .handicapScore,
      12,
    );
    expect(
      participants
          .where((value) => value.type == ParticipantType.autoTemporary)
          .map((value) => value.handicapScore),
      everyElement(0),
    );
  });

  test('handicap does not change average-order team membership', () {
    List<String> memberships(bool applyHandicap) {
      final allocator = TeamAllocator(
        random: Random(5),
        idFactory: () => 'unused',
      );
      final teams = allocator.allocate(
        regularMembers: [
          regular('male-180', 180),
          regular('female-170', 170, gender: MemberGender.female),
          regular('male-160', 160),
          regular('male-150', 150),
        ],
        manualTemporaryMembers: const [],
        teamSize: 2,
        mode: TeamAllocationMode.averageOrder,
        applyFemaleHandicap: applyHandicap,
      );
      return teams
          .map(
            (team) =>
                team.participants.map((value) => value.id).toList()..sort(),
          )
          .map((ids) => ids.join('/'))
          .toList()
        ..sort();
    }

    expect(memberships(true), memberships(false));
  });

  test('disabled handicap leaves female adjustments at zero', () {
    final allocator = TeamAllocator(random: Random(6), idFactory: () => 'auto');
    final teams = allocator.allocate(
      regularMembers: [regular('female', 180, gender: MemberGender.female)],
      manualTemporaryMembers: const [],
      teamSize: 2,
    );

    expect(
      teams
          .expand((team) => team.participants)
          .map((value) => value.handicapScore),
      everyElement(0),
    );
  });

  test('score compensation deducts the full-team gap to the lowest score', () {
    final allocator = TeamAllocator(random: Random(1), idFactory: () => 'id');
    final teams = [
      Team(
        number: 1,
        participants: [regular('a', 180), regular('b', 160), manual('m', 150)],
      ),
      Team(
        number: 2,
        participants: [regular('c', 190), regular('d', 140), automatic('x')],
      ),
      Team(
        number: 3,
        participants: [regular('e', 175), regular('f', 155), regular('g', 145)],
      ),
    ];

    final balanced = allocator.compensateScores(teams);

    expect(balanced[0].rawScore, 490);
    expect(balanced[0].bonusScore, -15);
    expect(
      balanced[1].participants.last.score,
      160,
      reason: 'automatic participant scores must stay at 160',
    );
    expect(balanced[1].rawScore, 490);
    expect(balanced[2].rawScore, 475);
    expect(balanced[1].bonusScore, -15);
    expect(balanced[2].bonusScore, 0);
    expect(balanced.map((team) => team.effectiveScore), [475, 475, 475]);
  });

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
      expect(balanced[0].bonusScore, -131);
      expect(balanced[1].bonusScore, 0);
      expect(balanced.map((team) => team.effectiveScore), [320, 320]);
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
    expect(balanced[0].bonusScore, -380);
    expect(balanced[1].bonusScore, 0);
    expect(balanced.map((team) => team.effectiveScore), [320, 320]);
  });
}
