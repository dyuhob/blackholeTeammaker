import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team_allocator.dart';
import 'package:team_maker/features/team_builder/team_builder_controller.dart';

void main() {
  late TeamBuilderController controller;
  late List<Member> members;
  var id = 0;

  setUp(() {
    members = [
      Member(id: '1', name: '김회원', score: 180),
      Member(id: '2', name: '이회원', score: 165),
      Member(id: '3', name: '박회원', score: 175),
    ];
    controller = TeamBuilderController(
      allocator: TeamAllocator(
        random: Random(11),
        idFactory: () => 'auto-${id++}',
      ),
      idFactory: () => 'id-${id++}',
      now: () => DateTime(2026, 9, 7, 20, 30),
    );
    controller.setSavedMembers(members);
  });

  test('all saved members start as selected participants', () {
    expect(controller.participants.map((value) => value.name), [
      '김회원',
      '이회원',
      '박회원',
    ]);
    expect(controller.availableMembers, isEmpty);
  });

  test('excluding and re-adding moves a member between the two lists', () {
    controller.excludeMember('2');

    expect(controller.participants.map((value) => value.name), ['김회원', '박회원']);
    expect(controller.availableMembers.map((value) => value.name), ['이회원']);

    controller.addSavedMember('2');
    expect(controller.availableMembers, isEmpty);
    expect(controller.participants.map((value) => value.name), [
      '김회원',
      '이회원',
      '박회원',
    ]);
  });

  test('session score edits do not mutate the saved member', () {
    controller.updateParticipantScore('participant-1', 200);

    expect(controller.participants.first.score, 200);
    expect(members.first.score, 180);
  });

  test('manual temporary members stay below regular members', () {
    controller.addManualTemporary('게스트', 150);

    expect(controller.participants.last.name, '게스트');
    expect(controller.participants.last.type, ParticipantType.manualTemporary);
  });

  test('manually entered participant scores must be between 90 and 200', () {
    expect(
      () => controller.addManualTemporary('낮은 점수', 89),
      throwsArgumentError,
    );
    expect(
      () => controller.addManualTemporary('높은 점수', 201),
      throwsArgumentError,
    );

    controller.addManualTemporary('최솟값', 90);
    controller.addManualTemporary('최댓값', 200);
    expect(
      controller.participants
          .where((participant) => participant.type.isTemporary)
          .map((participant) => participant.score),
      [90, 200],
    );

    expect(
      () => controller.updateParticipantScore('participant-1', 89),
      throwsArgumentError,
    );
    expect(controller.participants.first.score, 180);
  });

  test('build creates an unsaved result with a default title', () {
    controller.teamSize = 2;

    final result = controller.buildResult();

    expect(result.title, '2026-09-07 20:30 팀 편성');
    expect(result.teamSize, 2);
    expect(result.teams, hasLength(2));
    expect(controller.currentResult, result);
    expect(controller.isCurrentResultSaved, isFalse);
  });

  test('restores exclusions guests edited scores and form inputs', () {
    controller.restoreWorkspace(
      participants: [
        Participant(
          id: 'participant-1',
          sourceMemberId: '1',
          name: '김회원',
          score: 195,
          type: ParticipantType.regular,
        ),
        Participant(
          id: 'guest-1',
          name: '게스트',
          score: 150,
          type: ParticipantType.manualTemporary,
        ),
      ],
      teamSizeInput: '4',
      title: '저녁 경기',
    );

    expect(controller.participants.map((value) => value.id), [
      'participant-1',
      'guest-1',
    ]);
    expect(controller.participants.first.score, 195);
    expect(controller.availableMembers.map((value) => value.id), ['2', '3']);
    expect(controller.teamSizeInput, '4');
    expect(controller.teamSize, 4);
    expect(controller.title, '저녁 경기');
  });
}
