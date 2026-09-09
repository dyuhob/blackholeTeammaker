import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/core/storage/json_object_store.dart';
import 'package:team_maker/data/json_member_repository.dart';
import 'package:team_maker/data/json_team_history_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  test(
    'member repository returns an empty list when storage is empty',
    () async {
      final repository = JsonMemberRepository(MemoryJsonObjectStore());

      expect(await repository.loadAll(), isEmpty);
    },
  );

  test(
    'member repository stores and reads a versioned JSON document',
    () async {
      final store = MemoryJsonObjectStore();
      final repository = JsonMemberRepository(store);
      final members = [Member(id: '1', name: '김회원', score: 180)];

      await repository.saveAll(members);

      expect(store.value?['schemaVersion'], 2);
      expect(store.value?['members'], [
        {'id': '1', 'name': '김회원', 'score': 180},
      ]);
      final pending = store.value?['pendingMutations']! as List<Object?>;
      expect(pending, hasLength(1));
      expect(pending.single, isA<Map<String, Object?>>());
      expect(
        pending.single as Map<String, Object?>,
        containsPair('entityId', '1'),
      );
      expect(await repository.loadAll(), members);
    },
  );

  test('member repository rejects unsupported schemas', () async {
    final repository = JsonMemberRepository(
      MemoryJsonObjectStore({'schemaVersion': 99, 'members': <Object>[]}),
    );

    expect(repository.loadAll, throwsFormatException);
  });

  test('history repository saves updates sorts and deletes records', () async {
    final store = MemoryJsonObjectStore();
    final repository = JsonTeamHistoryRepository(store);
    final older = result('old', '이전 결과', DateTime(2026, 9, 1));
    final newer = result('new', '최근 결과', DateTime(2026, 9, 7));

    await repository.save(older);
    await repository.save(newer);
    expect((await repository.loadAll()).map((value) => value.id), [
      'new',
      'old',
    ]);

    await repository.save(newer.copyWith(title: '수정된 결과'));
    expect((await repository.loadAll()).first.title, '수정된 결과');

    await repository.delete('new');
    expect((await repository.loadAll()).map((value) => value.id), ['old']);
    expect(store.value?['schemaVersion'], 2);
  });

  test('history repository rejects unsupported schemas', () async {
    final repository = JsonTeamHistoryRepository(
      MemoryJsonObjectStore({'schemaVersion': 99, 'records': <Object>[]}),
    );

    expect(repository.loadAll, throwsFormatException);
  });
}

class MemoryJsonObjectStore implements JsonObjectStore {
  MemoryJsonObjectStore([this.value]);

  Map<String, Object?>? value;

  @override
  Future<Map<String, Object?>?> read() async => value;

  @override
  Future<void> write(Map<String, Object?> value) async {
    this.value = value;
  }
}

TeamResult result(String id, String title, DateTime createdAt) => TeamResult(
  id: id,
  title: title,
  createdAt: createdAt,
  teamSize: 1,
  teams: [
    Team(
      number: 1,
      participants: [
        Participant(
          id: 'participant-$id',
          name: '회원',
          score: 180,
          type: ParticipantType.regular,
        ),
      ],
    ),
  ],
);
