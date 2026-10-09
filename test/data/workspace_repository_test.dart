import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/core/storage/json_object_store.dart';
import 'package:team_maker/data/json_workspace_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/workspace_state.dart';

void main() {
  test('workspace repository round-trips every unfinished input', () async {
    final store = _MemoryJsonObjectStore();
    final repository = JsonWorkspaceRepository(store);
    final state = WorkspaceState(
      selectedTabIndex: 1,
      draftMembers: [
        Member(
          id: 'draft-1',
          name: '새 클럽원',
          score: 170,
          gender: MemberGender.female,
        ),
      ],
      pendingMemberName: '입력 중 이름',
      pendingMemberScore: '155',
      pendingMemberGender: MemberGender.female,
      participants: [
        Participant(
          id: 'participant-1',
          sourceMemberId: 'saved-1',
          name: '기존 클럽원',
          score: 185,
          type: ParticipantType.regular,
          gender: MemberGender.female,
        ),
        Participant(
          id: 'guest-1',
          name: '입력 게스트',
          score: 150,
          type: ParticipantType.manualTemporary,
        ),
      ],
      teamSizeInput: '4',
      title: '화요일 경기',
    );

    await repository.save(state);

    expect(await repository.load(), state);
    expect(store.value?['schemaVersion'], 1);
  });

  test('legacy workspace data defaults missing gender and handicap', () {
    final restored = WorkspaceState.fromJson({
      'selectedTabIndex': 1,
      'draftMembers': [
        {'id': 'draft-1', 'name': '기존 회원', 'score': 170},
      ],
      'pendingMemberName': '입력 중',
      'pendingMemberScore': '160',
      'participants': [
        {
          'id': 'participant-1',
          'sourceMemberId': 'draft-1',
          'name': '기존 회원',
          'score': 170,
          'type': 'regular',
        },
      ],
      'teamSizeInput': '3',
      'title': '기존 경기',
    });

    expect(restored.pendingMemberGender, MemberGender.male);
    expect(restored.draftMembers.single.gender, MemberGender.male);
    expect(restored.participants.single.gender, MemberGender.male);
    expect(restored.participants.single.handicapScore, 0);
  });

  test('workspace repository returns null when no draft exists', () async {
    final repository = JsonWorkspaceRepository(_MemoryJsonObjectStore());

    expect(await repository.load(), isNull);
  });
}

class _MemoryJsonObjectStore implements JsonObjectStore {
  Map<String, Object?>? value;

  @override
  Future<Map<String, Object?>?> read() async => value;

  @override
  Future<void> write(Map<String, Object?> value) async {
    this.value = value;
  }
}
