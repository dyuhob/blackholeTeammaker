import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/data/member_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/features/members/member_controller.dart';

void main() {
  test('draft additions do not change the saved roster before save', () async {
    final repository = MemoryMemberRepository([
      Member(id: '1', name: '김회원', score: 180),
    ]);
    var nextId = 2;
    final controller = MemberController(
      repository: repository,
      idFactory: () => '${nextId++}',
    );
    await controller.initialize();

    controller.addMember('이회원', 165);

    expect(controller.draftMembers.map((member) => member.name), [
      '김회원',
      '이회원',
    ]);
    expect(controller.savedMembers.map((member) => member.name), ['김회원']);
    expect(controller.hasUnsavedChanges, isTrue);
  });

  test('successful save publishes the entire edited roster', () async {
    final repository = MemoryMemberRepository([]);
    final controller = MemberController(
      repository: repository,
      idFactory: () => 'new-id',
    );
    await controller.initialize();
    controller.addMember('박회원', 175);

    expect(await controller.save(), isTrue);

    expect(controller.savedMembers.single.name, '박회원');
    expect(repository.members, controller.savedMembers);
    expect(controller.hasUnsavedChanges, isFalse);
  });

  test('failed save preserves the old roster and dirty draft', () async {
    final original = Member(id: '1', name: '김회원', score: 180);
    final repository = MemoryMemberRepository([original])..failWrites = true;
    final controller = MemberController(
      repository: repository,
      idFactory: () => '2',
    );
    await controller.initialize();
    controller.addMember('이회원', 165);

    expect(await controller.save(), isFalse);

    expect(controller.savedMembers, [original]);
    expect(controller.draftMembers, hasLength(2));
    expect(controller.hasUnsavedChanges, isTrue);
    expect(controller.errorMessage, isNotNull);
  });

  test('manually entered scores must be between 90 and 200', () async {
    final repository = MemoryMemberRepository([]);
    var nextId = 1;
    final controller = MemberController(
      repository: repository,
      idFactory: () => '${nextId++}',
    );
    await controller.initialize();

    expect(() => controller.addMember('낮은 점수', 89), throwsArgumentError);
    expect(() => controller.addMember('높은 점수', 201), throwsArgumentError);

    controller.addMember('최솟값', 90);
    controller.addMember('최댓값', 200);
    expect(controller.draftMembers.map((member) => member.score), [90, 200]);

    expect(
      () => controller.updateScore(controller.draftMembers.first.id, 201),
      throwsArgumentError,
    );
    expect(controller.draftMembers.first.score, 90);
  });
}

class MemoryMemberRepository implements MemberRepository {
  MemoryMemberRepository(List<Member> members) : members = [...members];

  List<Member> members;
  bool failWrites = false;

  @override
  Future<List<Member>> loadAll() async => [...members];

  @override
  Future<void> saveAll(List<Member> members) async {
    if (failWrites) throw const FileSystemException('write failed');
    this.members = [...members];
  }
}

class FileSystemException implements Exception {
  const FileSystemException(this.message);

  final String message;

  @override
  String toString() => message;
}
