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

  test('build creates an unsaved result with a default title', () {
    controller.teamSize = 2;

    final result = controller.buildResult();

    expect(result.title, '2026-09-07 20:30 팀 편성');
    expect(result.teamSize, 2);
    expect(result.teams, hasLength(2));
    expect(controller.currentResult, result);
    expect(controller.isCurrentResultSaved, isFalse);
  });
}
