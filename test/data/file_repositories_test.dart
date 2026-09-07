import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/core/storage/atomic_json_file.dart';
import 'package:team_maker/data/file_member_repository.dart';
import 'package:team_maker/data/file_team_history_repository.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('team_maker_test_');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  AtomicJsonFile file(String name) => AtomicJsonFile(
    directoryProvider: () async => directory,
    fileName: name,
  );

  test('member repository returns empty list when file is missing', () async {
    final repository = FileMemberRepository(file('members_v1.json'));

    expect(await repository.loadAll(), isEmpty);
  });

  test('member repository saves and reloads the complete roster', () async {
    final repository = FileMemberRepository(file('members_v1.json'));
    final members = [
      Member(id: '1', name: '김회원', score: 180),
      Member(id: '2', name: '이회원', score: 165),
    ];

    await repository.saveAll(members);

    expect(await repository.loadAll(), members);
  });

  test('atomic JSON falls back to backup when the main file is corrupt', () async {
    final repository = FileMemberRepository(file('members_v1.json'));
    final first = [Member(id: '1', name: '복구 회원', score: 170)];
    await repository.saveAll(first);
    await repository.saveAll([
      ...first,
      Member(id: '2', name: '새 회원', score: 160),
    ]);
    await File('${directory.path}/members_v1.json').writeAsString('{broken');

    final restored = await repository.loadAll();

    expect(restored, first);
    expect(
      await File('${directory.path}/members_v1.json').readAsString(),
      contains('복구 회원'),
    );
  });

  test('history repository saves, updates, sorts, and deletes records', () async {
    final repository = FileTeamHistoryRepository(file('team_history_v1.json'));
    final older = result('old', '이전 결과', DateTime(2026, 9, 1));
    final newer = result('new', '최근 결과', DateTime(2026, 9, 7));

    await repository.save(older);
    await repository.save(newer);
    expect((await repository.loadAll()).map((value) => value.id), ['new', 'old']);

    await repository.save(newer.copyWith(title: '수정된 결과'));
    expect((await repository.loadAll()).first.title, '수정된 결과');

    await repository.delete('new');
    expect((await repository.loadAll()).map((value) => value.id), ['old']);
  });
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
