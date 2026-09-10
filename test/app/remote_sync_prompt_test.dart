import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/app/team_maker_app.dart';
import 'package:team_maker/data/sync/member_sync.dart';
import 'package:team_maker/data/sync/history_sync.dart';
import 'package:team_maker/data/sync/sync_outcome.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/services/pwa_install_service.dart';

import '../support/memory_repositories.dart';

void main() {
  testWidgets('loading remote members clears unfinished text input', (
    tester,
  ) async {
    final repository = MemoryMemberRepository([
      Member(id: 'one', name: '현재 회원', score: 180),
    ]);
    final sync = DelayedMemberSync(repository, [
      Member(id: 'one', name: '원격 회원', score: 190),
    ]);
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: repository,
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: sync,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('member-name-input')), '작성 중');
    await tester.enterText(find.byKey(const Key('member-score-input')), '175');

    sync.complete();
    await tester.pumpAndSettle();
    await tester.tap(find.text('불러오기'));
    await tester.pumpAndSettle();

    final name = tester.widget<TextField>(
      find.byKey(const Key('member-name-input')),
    );
    final score = tester.widget<TextField>(
      find.byKey(const Key('member-score-input')),
    );
    expect(name.controller?.text, isEmpty);
    expect(score.controller?.text, isEmpty);
  });

  testWidgets('eligible PWA visit shows install guidance and remembers later', (
    tester,
  ) async {
    final install = FakePwaInstallService();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository(),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        pwaInstallService: install,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈 화면에 설치'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pumpAndSettle();
    expect(install.dismissed, isTrue);
  });

  testWidgets('saving a team result requests history synchronization', (
    tester,
  ) async {
    final historySync = CountingHistorySync();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository([
          Member(id: 'member-1', name: '회원', score: 180),
        ]),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        historySync: historySync,
        random: Random(1),
        now: () => DateTime(2026, 9, 9),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-size-input')), '1');
    await tester.tap(find.byKey(const Key('build-teams-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-result-button')));
    await tester.pumpAndSettle();

    expect(historySync.calls, 1);
    expect(find.text('기록에 저장했습니다.'), findsOneWidget);
  });

  testWidgets('failed history synchronization never shows save completion', (
    tester,
  ) async {
    final historySync = SequenceHistorySync([
      SyncOutcome.offline(Exception('network unavailable')),
    ]);
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository([
          Member(id: 'member-1', name: '회원', score: 180),
        ]),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        historySync: historySync,
        random: Random(1),
        now: () => DateTime(2026, 9, 9),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-size-input')), '1');
    await tester.tap(find.byKey(const Key('build-teams-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-result-button')));
    await tester.pumpAndSettle();

    expect(find.text('기기에 저장됨 · 연결되면 동기화됩니다'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('기록에 저장했습니다.'), findsNothing);
  });

  testWidgets('saving members requests another synchronization', (
    tester,
  ) async {
    final sync = CountingMemberSync();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository(),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: sync,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();
    expect(sync.calls, 1);

    await tester.enterText(find.byKey(const Key('member-name-input')), '회원');
    await tester.enterText(find.byKey(const Key('member-score-input')), '180');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-members-button')));
    await tester.pumpAndSettle();

    expect(sync.calls, 2);
    expect(find.text('클럽원 명단을 저장했습니다.'), findsOneWidget);
  });

  testWidgets('an unchanged member roster can be explicitly synchronized', (
    tester,
  ) async {
    final sync = CountingMemberSync();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository([
          Member(id: 'one', name: '기존 회원', score: 180),
        ]),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: sync,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();
    expect(sync.calls, 1);

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('save-members-button')),
    );
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('save-members-button')));
    await tester.pumpAndSettle();

    expect(sync.calls, 2);
  });

  testWidgets('failed member synchronization never shows save completion', (
    tester,
  ) async {
    final sync = SequenceMemberSync([
      const SyncOutcome.unchanged(),
      SyncOutcome.offline(Exception('network unavailable')),
    ]);
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository([
          Member(id: 'one', name: '기존 회원', score: 180),
        ]),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: sync,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-members-button')));
    await tester.pumpAndSettle();

    expect(find.text('기기에 저장됨 · 연결되면 동기화됩니다'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('클럽원 명단을 저장했습니다.'), findsNothing);
  });

  testWidgets('remote member differences require confirmation before load', (
    tester,
  ) async {
    final local = Member(id: 'one', name: '현재 회원', score: 180);
    final remote = Member(id: 'one', name: '원격 회원', score: 190);
    final repository = MemoryMemberRepository([local]);
    final sync = FakeMemberSync(repository, [remote]);

    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: repository,
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: sync,
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('변경된 내역이 있습니다.\n현재 입력된 내용은 사라집니다. 불러오시겠습니까?'),
      findsOneWidget,
    );
    expect(repository.values.single, local);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('현재 회원'), findsOneWidget);
    expect(repository.values.single, local);
  });

  testWidgets('load action accepts remote JSON and reloads the screen', (
    tester,
  ) async {
    final repository = MemoryMemberRepository([
      Member(id: 'one', name: '현재 회원', score: 180),
    ]);
    final remote = Member(id: 'one', name: '원격 회원', score: 190);

    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: repository,
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        memberSync: FakeMemberSync(repository, [remote]),
        random: Random(1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('불러오기'));
    await tester.pumpAndSettle();

    expect(repository.values.single, remote);
    expect(find.text('원격 회원'), findsOneWidget);
    expect(find.text('현재 회원'), findsNothing);
  });
}

class CountingMemberSync implements MemberSync {
  int calls = 0;

  @override
  Future<void> acceptRemote(List<Member> snapshot) async {}

  @override
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible) async {
    calls++;
    return const SyncOutcome.unchanged();
  }
}

class CountingHistorySync implements HistorySync {
  int calls = 0;

  @override
  Future<void> acceptRemote(List<TeamResult> snapshot) async {}

  @override
  Future<SyncOutcome<List<TeamResult>>> synchronize(
    List<TeamResult> visible,
  ) async {
    calls++;
    return const SyncOutcome.unchanged();
  }
}

class SequenceHistorySync implements HistorySync {
  SequenceHistorySync(this.outcomes);

  final List<SyncOutcome<List<TeamResult>>> outcomes;
  var _nextOutcome = 0;

  @override
  Future<void> acceptRemote(List<TeamResult> snapshot) async {}

  @override
  Future<SyncOutcome<List<TeamResult>>> synchronize(
    List<TeamResult> visible,
  ) async => outcomes[_nextOutcome++];
}

class SequenceMemberSync implements MemberSync {
  SequenceMemberSync(this.outcomes);

  final List<SyncOutcome<List<Member>>> outcomes;
  var _nextOutcome = 0;

  @override
  Future<void> acceptRemote(List<Member> snapshot) async {}

  @override
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible) async =>
      outcomes[_nextOutcome++];
}

class FakePwaInstallService implements PwaInstallService {
  bool dismissed = false;

  @override
  bool get canPrompt => true;

  @override
  bool get isIos => false;

  @override
  Future<void> dismiss() async => dismissed = true;

  @override
  Future<void> requestInstall() async {}

  @override
  Future<bool> shouldOffer() async => true;
}

class FakeMemberSync implements MemberSync {
  FakeMemberSync(this.repository, this.remote);

  final MemoryMemberRepository repository;
  final List<Member> remote;

  @override
  Future<void> acceptRemote(List<Member> snapshot) async {
    repository.values = [...snapshot];
  }

  @override
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible) async =>
      SyncOutcome.remoteChanged([...remote]);
}

class DelayedMemberSync implements MemberSync {
  DelayedMemberSync(this.repository, this.remote);

  final MemoryMemberRepository repository;
  final List<Member> remote;
  final Completer<void> _ready = Completer<void>();

  void complete() => _ready.complete();

  @override
  Future<void> acceptRemote(List<Member> snapshot) async {
    repository.values = [...snapshot];
  }

  @override
  Future<SyncOutcome<List<Member>>> synchronize(List<Member> visible) async {
    await _ready.future;
    return SyncOutcome.remoteChanged([...remote]);
  }
}
