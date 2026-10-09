import 'dart:math';

import 'participant.dart';
import 'team.dart';

enum TeamAllocationMode { random, averageOrder }

class TeamAllocator {
  TeamAllocator({required this._random, required this._idFactory});

  final Random _random;
  final String Function() _idFactory;

  List<Team> allocate({
    required List<Participant> regularMembers,
    required List<Participant> manualTemporaryMembers,
    required int teamSize,
    TeamAllocationMode mode = TeamAllocationMode.random,
  }) {
    if (teamSize < 1) {
      throw ArgumentError.value(teamSize, 'teamSize', '팀당 인원은 1명 이상이어야 합니다.');
    }
    final selectedCount = regularMembers.length + manualTemporaryMembers.length;
    if (selectedCount == 0) {
      throw ArgumentError('참가자가 한 명 이상 필요합니다.');
    }

    final teamCount = max(2, (selectedCount / teamSize).ceil());
    final capacity = teamCount * teamSize;
    final automaticCount = capacity - selectedCount;

    if (mode == TeamAllocationMode.averageOrder) {
      return _allocateByAverage(
        participants: [...regularMembers, ...manualTemporaryMembers],
        teamCount: teamCount,
        automaticCount: automaticCount,
      );
    }

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
      for (
        var index = 0;
        index < teamSize - temporaryTargets[teamIndex];
        index++
      ) {
        slots.add(_Slot(teamIndex));
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
        temporarySlots.add(_Slot(teamIndex));
      }
    }
    temporarySlots.shuffle(_random);
    final shuffledManuals = [...manualTemporaryMembers]..shuffle(_random);
    for (var index = 0; index < shuffledManuals.length; index++) {
      teamMembers[temporarySlots[index].teamIndex].add(shuffledManuals[index]);
    }
    for (
      var index = shuffledManuals.length;
      index < temporarySlots.length;
      index++
    ) {
      final autoNumber = index - shuffledManuals.length + 1;
      teamMembers[temporarySlots[index].teamIndex].add(
        Participant(
          id: _idFactory(),
          name: '게스트 $autoNumber (자동)',
          score: 160,
          type: ParticipantType.autoTemporary,
        ),
      );
    }

    return _buildTeams(teamMembers);
  }

  List<Team> _allocateByAverage({
    required List<Participant> participants,
    required int teamCount,
    required int automaticCount,
  }) {
    final lowestScore = participants.map((value) => value.score).reduce(min);
    for (var index = 0; index < automaticCount; index++) {
      participants.add(
        Participant(
          id: _idFactory(),
          name: '게스트 ${index + 1} (자동)',
          score: lowestScore,
          type: ParticipantType.autoTemporary,
        ),
      );
    }

    final scoreGroups = <int, List<Participant>>{};
    for (final participant in participants) {
      (scoreGroups[participant.score] ??= []).add(participant);
    }
    final orderedParticipants = <Participant>[];
    final scores = scoreGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final score in scores) {
      final group = scoreGroups[score]!..shuffle(_random);
      orderedParticipants.addAll(group);
    }

    final teamMembers = List.generate(teamCount, (_) => <Participant>[]);
    for (var index = 0; index < orderedParticipants.length; index++) {
      teamMembers[index % teamCount].add(orderedParticipants[index]);
    }
    return _buildTeams(teamMembers);
  }

  List<Team> _buildTeams(List<List<Participant>> teamMembers) {
    final teams = List.generate(teamMembers.length, (index) {
      final participants = teamMembers[index]
        ..sort(_compareParticipantsForDisplay);
      return Team(number: index + 1, participants: participants);
    });
    return _orderTeamsForDisplay(compensateScores(teams));
  }

  List<Team> compensateScores(List<Team> teams) {
    if (teams.isEmpty) return const [];
    final targetScore = teams.map((team) => team.rawScore).reduce(min);

    return teams
        .map((team) => team.copyWith(bonusScore: targetScore - team.rawScore))
        .toList();
  }

  List<Team> _orderTeamsForDisplay(List<Team> teams) {
    if (teams.isEmpty) return const [];
    final shuffled = [...teams]..shuffle(_random);
    final lowestScore = shuffled.map((team) => team.rawScore).reduce(min);
    final lowestIndex = shuffled.indexWhere(
      (team) => team.rawScore == lowestScore,
    );
    final lowest = shuffled.removeAt(lowestIndex);
    final ordered = [lowest, ...shuffled];
    return [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(number: index + 1),
    ];
  }
}

int _compareParticipantsForDisplay(Participant left, Participant right) {
  final leftIsAutomatic = left.type == ParticipantType.autoTemporary;
  final rightIsAutomatic = right.type == ParticipantType.autoTemporary;
  if (leftIsAutomatic != rightIsAutomatic) return leftIsAutomatic ? 1 : -1;
  final scoreOrder = right.score.compareTo(left.score);
  if (scoreOrder != 0) return scoreOrder;
  return left.name.compareTo(right.name);
}

class _Slot {
  const _Slot(this.teamIndex);

  final int teamIndex;
}
