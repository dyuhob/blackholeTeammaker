import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/core/storage/json_object_store.dart';
import 'package:team_maker/data/json_member_repository.dart';
import 'package:team_maker/data/json_team_history_repository.dart';
import 'package:team_maker/data/supabase/history_remote_data_source.dart';
import 'package:team_maker/data/supabase/member_remote_data_source.dart';
import 'package:team_maker/data/sync/history_sync_coordinator.dart';
import 'package:team_maker/data/sync/member_sync_coordinator.dart';
import 'package:team_maker/data/sync/pending_mutation.dart';
import 'package:team_maker/data/sync/sync_outcome.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';

void main() {
  test('member sync uploads the outbox before pulling', () async {
    final local = JsonMemberRepository(MemoryStore());
    final member = Member(id: 'one', name: '회원', score: 180);
    await local.saveAll([member]);
    final remote = FakeMemberRemote([member]);
    final coordinator = MemberSyncCoordinator(local: local, remote: remote);

    final outcome = await coordinator.synchronize([member]);

    expect(outcome.kind, SyncOutcomeKind.unchanged);
    expect(remote.pushed.map((value) => value.entityId), ['one']);
    expect((await local.readSyncDocument()).pendingMutations, isEmpty);
  });

  test('member sync stops before pull when upload fails', () async {
    final local = JsonMemberRepository(MemoryStore());
    final member = Member(id: 'one', name: '회원', score: 180);
    await local.saveAll([member]);
    final remote = FakeMemberRemote([member], failPush: true);
    final coordinator = MemberSyncCoordinator(local: local, remote: remote);

    final outcome = await coordinator.synchronize([member]);

    expect(outcome.kind, SyncOutcomeKind.offline);
    expect(remote.fetchCount, 0);
    expect((await local.readSyncDocument()).pendingMutations, hasLength(1));
  });

  test('changed member snapshot is staged until accepted', () async {
    final local = JsonMemberRepository(MemoryStore());
    final localMember = Member(id: 'one', name: '기존', score: 180);
    final remoteMember = Member(id: 'one', name: '변경', score: 190);
    await local.replaceMembersFromRemote([localMember]);
    final coordinator = MemberSyncCoordinator(
      local: local,
      remote: FakeMemberRemote([remoteMember]),
    );

    final outcome = await coordinator.synchronize([localMember]);

    expect(outcome.kind, SyncOutcomeKind.remoteChanged);
    expect((await local.loadAll()).single, localMember);
    await coordinator.acceptRemote(outcome.snapshot!);
    expect((await local.loadAll()).single, remoteMember);
  });

  test('member comparison ignores list order', () async {
    final one = Member(id: 'one', name: '가', score: 180);
    final two = Member(id: 'two', name: '나', score: 170);
    final local = JsonMemberRepository(MemoryStore());
    final coordinator = MemberSyncCoordinator(
      local: local,
      remote: FakeMemberRemote([two, one]),
    );

    final outcome = await coordinator.synchronize([one, two]);

    expect(outcome.kind, SyncOutcomeKind.unchanged);
  });

  test(
    'member sync started during another run uploads the newer outbox',
    () async {
      final local = JsonMemberRepository(MemoryStore());
      final remote = BlockingMemberRemote();
      final coordinator = MemberSyncCoordinator(local: local, remote: remote);
      final member = Member(id: 'new-member', name: '새 회원', score: 180);

      final initialSync = coordinator.synchronize(const []);
      await remote.firstFetchStarted.future;
      await local.saveAll([member]);
      final saveSync = coordinator.synchronize([member]);
      remote.releaseFirstFetch.complete();

      expect((await initialSync).kind, SyncOutcomeKind.unchanged);
      expect((await saveSync).kind, SyncOutcomeKind.unchanged);
      expect(remote.pushed.map((value) => value.entityId), ['new-member']);
      expect(remote.fetchCount, 2);
      expect((await local.readSyncDocument()).pendingMutations, isEmpty);
    },
  );

  test('history sync stages a different complete history', () async {
    final local = JsonTeamHistoryRepository(MemoryStore());
    final localResult = result('one', '기존');
    final remoteResult = result('one', '변경');
    await local.replaceHistoryFromRemote([localResult]);
    final coordinator = HistorySyncCoordinator(
      local: local,
      remote: FakeHistoryRemote([remoteResult]),
    );

    final outcome = await coordinator.synchronize([localResult]);

    expect(outcome.kind, SyncOutcomeKind.remoteChanged);
    await coordinator.acceptRemote(outcome.snapshot!);
    expect((await local.loadAll()).single.title, '변경');
  });

  test(
    'history sync started during another run uploads the newer outbox',
    () async {
      final local = JsonTeamHistoryRepository(MemoryStore());
      final remote = BlockingHistoryRemote();
      final coordinator = HistorySyncCoordinator(local: local, remote: remote);
      final savedResult = result('new-result', '새 기록');

      final initialSync = coordinator.synchronize(const []);
      await remote.firstFetchStarted.future;
      await local.save(savedResult);
      final saveSync = coordinator.synchronize([savedResult]);
      remote.releaseFirstFetch.complete();

      expect((await initialSync).kind, SyncOutcomeKind.unchanged);
      expect((await saveSync).kind, SyncOutcomeKind.unchanged);
      expect(remote.pushed.map((value) => value.entityId), ['new-result']);
      expect(remote.fetchCount, 2);
      expect((await local.readSyncDocument()).pendingMutations, isEmpty);
    },
  );
}

class MemoryStore implements JsonObjectStore {
  Map<String, Object?>? value;

  @override
  Future<Map<String, Object?>?> read() async => value;

  @override
  Future<void> write(Map<String, Object?> value) async => this.value = value;
}

class FakeMemberRemote implements MemberRemoteDataSource {
  FakeMemberRemote(this.values, {this.failPush = false});

  final List<Member> values;
  final bool failPush;
  final List<PendingMutation> pushed = [];
  int fetchCount = 0;

  @override
  Future<List<Member>> fetchAll() async {
    fetchCount++;
    return [...values];
  }

  @override
  Future<void> push(PendingMutation mutation) async {
    if (failPush) throw Exception('offline');
    pushed.add(mutation);
  }
}

class FakeHistoryRemote implements HistoryRemoteDataSource {
  FakeHistoryRemote(this.values);

  final List<TeamResult> values;

  @override
  Future<List<TeamResult>> fetchAll() async => [...values];

  @override
  Future<void> push(PendingMutation mutation) async {}
}

class BlockingMemberRemote implements MemberRemoteDataSource {
  final firstFetchStarted = Completer<void>();
  final releaseFirstFetch = Completer<void>();
  final List<PendingMutation> pushed = [];
  final List<Member> _values = [];
  var fetchCount = 0;

  @override
  Future<List<Member>> fetchAll() async {
    fetchCount++;
    if (fetchCount == 1) {
      firstFetchStarted.complete();
      await releaseFirstFetch.future;
    }
    return [..._values];
  }

  @override
  Future<void> push(PendingMutation mutation) async {
    pushed.add(mutation);
    final member = Member.fromJson(mutation.payload);
    _values
      ..removeWhere((value) => value.id == member.id)
      ..add(member);
  }
}

class BlockingHistoryRemote implements HistoryRemoteDataSource {
  final firstFetchStarted = Completer<void>();
  final releaseFirstFetch = Completer<void>();
  final List<PendingMutation> pushed = [];
  final List<TeamResult> _values = [];
  var fetchCount = 0;

  @override
  Future<List<TeamResult>> fetchAll() async {
    fetchCount++;
    if (fetchCount == 1) {
      firstFetchStarted.complete();
      await releaseFirstFetch.future;
    }
    return [..._values];
  }

  @override
  Future<void> push(PendingMutation mutation) async {
    pushed.add(mutation);
    final savedResult = TeamResult.fromJson(mutation.payload);
    _values
      ..removeWhere((value) => value.id == savedResult.id)
      ..add(savedResult);
  }
}

TeamResult result(String id, String title) => TeamResult(
  id: id,
  title: title,
  createdAt: DateTime.utc(2026, 9, 9),
  teamSize: 1,
  teams: [
    Team(
      number: 1,
      participants: [
        Participant(
          id: 'p-$id',
          name: '회원',
          score: 180,
          type: ParticipantType.regular,
        ),
      ],
    ),
  ],
);
