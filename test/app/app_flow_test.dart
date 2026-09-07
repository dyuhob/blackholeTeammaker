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

    await tester.tap(find.text('회원 관리'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-members-button')));
    await tester.pumpAndSettle();
    expect(members.values.single.name, '김회원');

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    expect(find.text('김회원'), findsOneWidget);
    expect(find.text('제외된 회원이 없습니다.'), findsOneWidget);
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
}
