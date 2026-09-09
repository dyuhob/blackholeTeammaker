import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/core/storage/json_object_store.dart';
import 'package:team_maker/data/json_member_repository.dart';
import 'package:team_maker/data/json_team_history_repository.dart';
import 'package:team_maker/data/sync/pending_mutation.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  test('member schema v1 migrates without queuing an upload', () async {
    final store = MemoryStore({
      'schemaVersion': 1,
      'members': [
        {'id': 'member-1', 'name': '김회원', 'score': 180},
      ],
    });
    final repository = JsonMemberRepository(store);

    final document = await repository.readSyncDocument();

    expect(document.members.single.name, '김회원');
    expect(document.pendingMutations, isEmpty);
  });

  test('explicit member save queues an unchanged migrated roster', () async {
    final store = MemoryStore({
      'schemaVersion': 1,
      'members': [
        {'id': 'member-1', 'name': '김회원', 'score': 180},
      ],
    });
    final repository = JsonMemberRepository(store);
    final members = await repository.loadAll();

    await repository.saveAll(members);

    expect(
      (await repository.readSyncDocument()).pendingMutations,
      hasLength(1),
    );
  });

  test('member save queues changed rows and tombstones removed rows', () async {
    final store = MemoryStore({
      'schemaVersion': 1,
      'members': [
        {'id': 'keep', 'name': '가회원', 'score': 170},
        {'id': 'remove', 'name': '나회원', 'score': 160},
      ],
    });
    final repository = JsonMemberRepository(store);

    await repository.saveAll([Member(id: 'keep', name: '가회원', score: 180)]);
    final pending = (await repository.readSyncDocument()).pendingMutations;

    expect(pending, hasLength(2));
    expect(pending.map((value) => (value.entityId, value.kind)).toSet(), {
      ('keep', SyncMutationKind.upsert),
      ('remove', SyncMutationKind.delete),
    });
  });

  test('repeated unsent member edits compact to the latest payload', () async {
    final repository = JsonMemberRepository(MemoryStore());

    await repository.saveAll([Member(id: 'same', name: '회원', score: 150)]);
    await repository.saveAll([Member(id: 'same', name: '회원', score: 190)]);
    final pending = (await repository.readSyncDocument()).pendingMutations;

    expect(pending, hasLength(1));
    expect(pending.single.payload['score'], 190);
  });

  test('a newer member edit has a different acknowledgement id', () async {
    final repository = JsonMemberRepository(MemoryStore());
    await repository.saveAll([Member(id: 'same', name: '회원', score: 150)]);
    final first =
        (await repository.readSyncDocument()).pendingMutations.single.id;

    await repository.saveAll([Member(id: 'same', name: '회원', score: 190)]);
    final second =
        (await repository.readSyncDocument()).pendingMutations.single.id;

    expect(second, isNot(first));
  });

  test('accepting remote members discards pending local mutations', () async {
    final repository = JsonMemberRepository(MemoryStore());
    await repository.saveAll([Member(id: 'local', name: '로컬', score: 180)]);

    await repository.replaceMembersFromRemote([
      Member(id: 'remote', name: '원격', score: 170),
    ]);

    final document = await repository.readSyncDocument();
    expect(document.members.single.id, 'remote');
    expect(document.pendingMutations, isEmpty);
  });

  test('history save and delete queue idempotent operations', () async {
    final repository = JsonTeamHistoryRepository(MemoryStore());
    final value = _result('result-1');

    await repository.save(value);
    await repository.save(value.copyWith(title: '수정'));
    var pending = (await repository.readSyncDocument()).pendingMutations;
    expect(pending, hasLength(1));
    expect(pending.single.kind, SyncMutationKind.upsert);
    expect(pending.single.payload['title'], '수정');

    await repository.delete(value.id);
    pending = (await repository.readSyncDocument()).pendingMutations;
    expect(pending, hasLength(1));
    expect(pending.single.kind, SyncMutationKind.delete);
  });
}

class MemoryStore implements JsonObjectStore {
  MemoryStore([this.value]);

  Map<String, Object?>? value;

  @override
  Future<Map<String, Object?>?> read() async => value;

  @override
  Future<void> write(Map<String, Object?> value) async => this.value = value;
}

TeamResult _result(String id) => TeamResult(
  id: id,
  title: '기록',
  createdAt: DateTime.utc(2026, 9, 9),
  teamSize: 1,
  teams: [
    Team(
      number: 1,
      participants: [
        Participant(
          id: 'participant-1',
          sourceMemberId: 'member-1',
          name: '회원',
          score: 180,
          type: ParticipantType.regular,
        ),
      ],
    ),
  ],
);
