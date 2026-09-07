import 'dart:math';

import 'participant.dart';
import 'team.dart';

class TeamAllocator {
  TeamAllocator({required Random random, required String Function() idFactory})
    : _random = random,
      _idFactory = idFactory;

  final Random _random;
  final String Function() _idFactory;

  List<Team> allocate({
    required List<Participant> regularMembers,
    required List<Participant> manualTemporaryMembers,
    required int teamSize,
  }) {
    if (teamSize < 1) {
      throw ArgumentError.value(teamSize, 'teamSize', '팀당 인원은 1명 이상이어야 합니다.');
    }
    final selectedCount = regularMembers.length + manualTemporaryMembers.length;
    if (selectedCount == 0) {
      throw ArgumentError('참가자가 한 명 이상 필요합니다.');
    }

    final teamCount = (selectedCount / teamSize).ceil();
    final capacity = teamCount * teamSize;
    final automaticCount = capacity - selectedCount;
    final totalTemporaryCount = manualTemporaryMembers.length + automaticCount;

    final temporaryTargets = List<int>.filled(
      teamCount,
      totalTemporaryCount ~/ teamCount,
    );
    final extraTargetTeams = List<int>.generate(teamCount, (index) => index)
      ..shuffle(_random);
    for (var index = 0; index < totalTemporaryCount % teamCount; index++) {
      temporaryTargets[extraTargetTeams[index]]++;
    }

    final slots = <_Slot>[];
    for (var teamIndex = 0; teamIndex < teamCount; teamIndex++) {
      for (var index = 0; index < teamSize - temporaryTargets[teamIndex]; index++) {
        slots.add(_Slot(teamIndex, false));
      }
    }
    slots.shuffle(_random);

    final teamMembers = List.generate(teamCount, (_) => <Participant>[]);
    final shuffledRegulars = [...regularMembers]..shuffle(_random);
    for (var index = 0; index < shuffledRegulars.length; index++) {
      teamMembers[slots[index].teamIndex].add(shuffledRegulars[index]);
    }

    final temporarySlots = <_Slot>[];
    for (var teamIndex = 0; teamIndex < teamCount; teamIndex++) {
      for (var index = 0; index < temporaryTargets[teamIndex]; index++) {
        temporarySlots.add(_Slot(teamIndex, true));
      }
    }
    temporarySlots.shuffle(_random);
    final shuffledManuals = [...manualTemporaryMembers]..shuffle(_random);
    for (var index = 0; index < shuffledManuals.length; index++) {
      teamMembers[temporarySlots[index].teamIndex].add(shuffledManuals[index]);
    }
    for (var index = shuffledManuals.length; index < temporarySlots.length; index++) {
      final autoNumber = index - shuffledManuals.length + 1;
      teamMembers[temporarySlots[index].teamIndex].add(
        Participant(
          id: _idFactory(),
          name: '자동 임시 회원 $autoNumber',
          score: 0,
          type: ParticipantType.autoTemporary,
        ),
      );
    }

    final teams = List.generate(teamCount, (index) {
      final participants = teamMembers[index]
        ..sort((left, right) => left.type.order - right.type.order);
      return Team(number: index + 1, participants: participants);
    });
    return compensateScores(teams);
  }

  List<Team> compensateScores(List<Team> teams) {
    if (teams.isEmpty) return const [];
    final targetScore = teams.map((team) => team.rawScore).reduce(max);

    return teams.map((team) {
      var remainingGap = max(0, targetScore - team.rawScore);
      final autoIndexes = <int>[];
      for (var index = 0; index < team.participants.length; index++) {
        if (team.participants[index].type == ParticipantType.autoTemporary) {
          autoIndexes.add(index);
        }
      }

      final updated = [...team.participants];
      for (var position = 0; position < autoIndexes.length; position++) {
        final slotsLeft = autoIndexes.length - position;
        final fairShare = (remainingGap / slotsLeft).ceil();
        final assigned = min(300, fairShare);
        final participantIndex = autoIndexes[position];
        updated[participantIndex] = updated[participantIndex].copyWith(score: assigned);
        remainingGap -= assigned;
      }

      return team.copyWith(
        participants: updated,
        bonusScore: max(0, remainingGap),
      );
    }).toList();
  }
}

class _Slot {
  const _Slot(this.teamIndex, this.temporary);

  final int teamIndex;
  final bool temporary;
}
