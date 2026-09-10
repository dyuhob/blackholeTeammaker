import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/app/team_maker_app.dart';
import 'package:team_maker/domain/member.dart';

import '../support/memory_repositories.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Member> members = const [],
  }) async {
    final ids = SequenceIds();
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: MemoryMemberRepository(members),
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        idFactory: ids.next,
        random: Random(17),
        now: () => DateTime(2026, 9, 7, 20, 30),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('club member inputs enforce 90 to 200 and align score label', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('클럽원 관리'), findsWidgets);
    expect(find.text('회원 관리'), findsNothing);
    expect(find.text('클럽원 이름'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('member-name-input')), '홍길동');
    await tester.enterText(find.byKey(const Key('member-score-input')), '89');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    expect(find.text('이름과 90~200 사이의 점수를 입력해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-members-button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('member-score-input')), '201');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('save-members-button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('member-score-input')), '90');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pump();

    final label = tester.getRect(
      find.byKey(const ValueKey('member-score-label-id-0')),
    );
    final editor = tester.getRect(
      find.byKey(const ValueKey('member-score-id-0')),
    );
    expect(label.right, lessThan(editor.left));
    expect((label.center.dy - editor.center.dy).abs(), lessThan(1));
  });

  testWidgets('temporary club member dialog enforces score range', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();

    expect(find.text('미참여 클럽원'), findsOneWidget);
    await tester.tap(find.byKey(const Key('guest-add-card')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('temporary-name-input')),
      '게스트',
    );
    await tester.enterText(
      find.byKey(const Key('temporary-score-input')),
      '201',
    );
    await tester.tap(find.byKey(const Key('add-temporary-button')));
    await tester.pump();

    expect(find.text('점수는 90~200 사이여야 합니다.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('temporary-score-input')),
      '200',
    );
    await tester.tap(find.byKey(const Key('add-temporary-button')));
    await tester.pumpAndSettle();
    expect(find.text('게스트'), findsOneWidget);
    expect(find.byKey(const Key('guest-add-card')), findsOneWidget);
  });

  testWidgets('automatic filler is displayed as a 160 point participant', (
    tester,
  ) async {
    await pumpApp(
      tester,
      members: [Member(id: 'member-1', name: '홍길동', score: 180)],
    );
    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('team-size-input')), '2');
    await tester.tap(find.byKey(const Key('build-teams-button')));
    await tester.pumpAndSettle();

    expect(find.text('게스트 1 (자동)'), findsOneWidget);
    expect(find.text('게스트 2 (자동)'), findsOneWidget);
    expect(find.text('게스트 3 (자동)'), findsOneWidget);
    expect(find.text('160'), findsNWidgets(3));
  });
}
