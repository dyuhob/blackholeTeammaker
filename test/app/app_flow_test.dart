import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/app/team_maker_app.dart';
import 'package:team_maker/domain/member.dart';

import '../support/memory_repositories.dart';

void main() {
  testWidgets('member is published to team builder only after roster save', (
    tester,
  ) async {
    final members = MemoryMemberRepository();
    final history = MemoryHistoryRepository();
    final ids = SequenceIds();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: members,
        historyRepository: history,
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        idFactory: ids.next,
        random: Random(3),
        now: () => DateTime(2026, 9, 7, 20, 30),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('member-name-input')), '김회원');
    await tester.enterText(find.byKey(const Key('member-score-input')), '180');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    expect(find.text('김회원'), findsOneWidget);

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    expect(find.text('김회원'), findsNothing);

    await tester.tap(find.text('클럽원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-members-button')));
    await tester.pumpAndSettle();
    expect(members.values.single.name, '김회원');

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    expect(find.text('김회원'), findsOneWidget);
    expect(find.text('미참여 클럽원'), findsOneWidget);
    expect(find.byKey(const Key('guest-add-card')), findsOneWidget);
  });

  testWidgets('team result enters history only after explicit save', (
    tester,
  ) async {
    final members = MemoryMemberRepository([
      Member(id: 'member-1', name: '이회원', score: 165),
    ]);
    final history = MemoryHistoryRepository();
    final ids = SequenceIds();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: members,
        historyRepository: history,
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        idFactory: ids.next,
        random: Random(5),
        now: () => DateTime(2026, 9, 7, 20, 30),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-size-input')), '1');
    await tester.tap(find.byKey(const Key('build-teams-button')));
    await tester.pumpAndSettle();

    expect(find.text('2026-09-07 20:30 팀 편성'), findsOneWidget);
    expect(history.values, isEmpty);

    await tester.tap(find.byKey(const Key('save-result-button')));
    await tester.pumpAndSettle();
    expect(history.values, hasLength(1));
    expect(find.text('저장됨'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-07 20:30 팀 편성'), findsOneWidget);
  });

  testWidgets('share saves history without saving another gallery copy', (
    tester,
  ) async {
    final members = MemoryMemberRepository([
      Member(id: 'member-1', name: '공유 회원', score: 165),
    ]);
    final history = MemoryHistoryRepository();
    final gallery = MemoryGalleryExporter();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: members,
        historyRepository: history,
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: gallery,
        idFactory: SequenceIds().next,
        random: Random(9),
        now: () => DateTime(2026, 9, 9, 20, 30),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-size-input')), '1');
    await tester.tap(find.byKey(const Key('build-teams-button')));
    await tester.pumpAndSettle();

    expect(find.text('팀당 1명 · 2팀 · 2026-09-09 20:30'), findsOneWidget);
    final primaryColor = Theme.of(
      tester.element(find.byKey(const Key('save-result-button'))),
    ).colorScheme.primary;
    final galleryButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '갤러리에 저장'),
    );
    expect(
      galleryButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      primaryColor,
    );
    final shareButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('save-and-share-button')),
    );
    expect(
      shareButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      primaryColor,
    );
    expect(
      shareButton.style?.side?.resolve(<WidgetState>{})?.color,
      primaryColor,
    );

    expect(find.text('공유'), findsOneWidget);
    await tester.tap(find.byKey(const Key('save-and-share-button')));
    await tester.pumpAndSettle();

    expect(history.values, hasLength(1));
    expect(gallery.saved, isEmpty);
    expect(gallery.shared, hasLength(1));
  });

  testWidgets('unfinished inputs and team selection survive an app restart', (
    tester,
  ) async {
    final members = MemoryMemberRepository([
      Member(id: 'member-1', name: '기존 클럽원', score: 180),
    ]);
    final history = MemoryHistoryRepository();
    final workspace = MemoryWorkspaceRepository();
    final ids = SequenceIds();

    Widget buildApp() => TeamMakerApp(
      memberRepository: members,
      historyRepository: history,
      workspaceRepository: workspace,
      galleryExporter: MemoryGalleryExporter(),
      idFactory: ids.next,
      random: Random(7),
      now: () => DateTime(2026, 9, 8, 20),
    );

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('member-name-input')),
      '저장 전 클럽원',
    );
    await tester.enterText(find.byKey(const Key('member-score-input')), '165');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('member-name-input')),
      '입력 중 이름',
    );
    await tester.enterText(find.byKey(const Key('member-score-input')), '155');

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-title-input')), '화요일 경기');
    await tester.enterText(find.byKey(const Key('team-size-input')), '4');
    await tester.tap(find.byTooltip('참가자 제외'));
    await tester.tap(find.byKey(const Key('guest-add-card')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('temporary-name-input')),
      '입력 게스트',
    );
    await tester.enterText(
      find.byKey(const Key('temporary-score-input')),
      '150',
    );
    await tester.tap(find.byKey(const Key('add-temporary-button')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('team-title-input')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('team-title-input')))
          .controller
          ?.text,
      '화요일 경기',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('team-size-input')))
          .controller
          ?.text,
      '4',
    );
    expect(find.text('입력 게스트'), findsOneWidget);
    expect(find.text('기존 클럽원'), findsOneWidget);

    await tester.tap(find.text('클럽원 관리'));
    await tester.pumpAndSettle();
    expect(find.text('저장 전 클럽원'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('member-name-input')))
          .controller
          ?.text,
      '입력 중 이름',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('member-score-input')))
          .controller
          ?.text,
      '155',
    );
  });
}
