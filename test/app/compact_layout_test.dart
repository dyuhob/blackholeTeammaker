import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/app/navigation_icon_assets.dart';
import 'package:team_maker/app/team_maker_app.dart';
import 'package:team_maker/domain/member.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_allocator.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/features/history/history_controller.dart';
import 'package:team_maker/features/history/team_result_content.dart';
import 'package:team_maker/features/team_builder/team_builder_controller.dart';
import 'package:team_maker/features/team_builder/team_builder_screen.dart';

import '../support/memory_repositories.dart';

void main() {
  TeamBuilderController createController() {
    var nextId = 0;
    final controller = TeamBuilderController(
      allocator: TeamAllocator(
        random: Random(23),
        idFactory: () => 'auto-${nextId++}',
      ),
      idFactory: () => 'guest-${nextId++}',
      now: () => DateTime(2026, 9, 8, 12),
    );
    controller.setSavedMembers([
      Member(id: '1', name: '김클럽', score: 180),
      Member(id: '2', name: '이클럽', score: 170),
      Member(id: '3', name: '박클럽', score: 160),
      Member(id: '4', name: '최클럽', score: 150),
    ]);
    controller.excludeMember('3');
    controller.excludeMember('4');
    return controller;
  }

  testWidgets('team builder uses compact two-column member grids', (
    tester,
  ) async {
    final controller = createController();
    addTearDown(controller.dispose);
    final history = HistoryController(MemoryHistoryRepository());
    addTearDown(history.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeamBuilderScreen(
            controller: controller,
            historyController: history,
            galleryExporter: MemoryGalleryExporter(),
          ),
        ),
      ),
    );

    expect(find.text('미참여 클럽원'), findsOneWidget);
    expect(find.text('제외된 클럽원'), findsNothing);
    expect(find.text('임시 클럽원 추가'), findsNothing);

    final firstParticipant = tester.getRect(
      find.byKey(const Key('participant-card-participant-1')),
    );
    final secondParticipant = tester.getRect(
      find.byKey(const Key('participant-card-participant-2')),
    );
    expect(firstParticipant.top, secondParticipant.top);
    expect(
      secondParticipant.left - firstParticipant.right,
      greaterThanOrEqualTo(8),
    );
    expect(firstParticipant.height, 36);
    expect(firstParticipant.width, closeTo(secondParticipant.width, 1));
    final firstParticipantScore = tester.getRect(
      find.byKey(const Key('participant-score-participant-1')),
    );
    expect(firstParticipantScore.top - firstParticipant.top, closeTo(6, 0.1));
    expect(
      firstParticipant.bottom - firstParticipantScore.bottom,
      closeTo(2, 0.1),
    );

    final guestAdd = tester.getRect(find.byKey(const Key('guest-add-card')));
    final firstUnselected = tester.getRect(
      find.byKey(const Key('unselected-card-3')),
    );
    expect(guestAdd.top, firstUnselected.top);
    expect(guestAdd.width, closeTo(firstUnselected.width, 1));
    expect(guestAdd.height, 36);
    expect(firstUnselected.height, 36);
    final guestCard = tester.widget<Card>(
      find.byKey(const Key('guest-add-card')),
    );
    expect(guestCard.color, const Color(0xFFA7B9ED));
    final guestShape = guestCard.shape! as RoundedRectangleBorder;
    expect(
      guestShape.side.color,
      Theme.of(tester.element(find.byKey(const Key('guest-add-card'))))
          .colorScheme
          .primary,
    );
    expect(guestShape.side.width, 1);
    expect(
      find.descendant(
        of: find.byKey(const Key('guest-add-card')),
        matching: find.byType(CircularAssetIconButton),
      ),
      findsOneWidget,
    );

    final unselectedAddButton = find.descendant(
      of: find.byKey(const Key('unselected-card-3')),
      matching: find.byType(CircularAssetIconButton),
    );
    expect(tester.getSize(unselectedAddButton), const Size.square(24));
    final unselectedAddRect = tester.getRect(unselectedAddButton);
    expect(firstUnselected.right - unselectedAddRect.right, 8);

    expect(find.widgetWithText(TextButton, '전체 추가'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '전체 추가'), findsNothing);

    final removeButton = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('participant-card-participant-1')),
        matching: find.byType(CircularAssetIconButton),
      ),
    );
    expect(removeButton.width, 24);
    expect(removeButton.height, 24);
    expect(
      firstParticipant.right - removeButton.right,
      greaterThanOrEqualTo(8),
    );
    final circularButton = tester.widget<CircularAssetIconButton>(
      find.descendant(
        of: find.byKey(const Key('participant-card-participant-1')),
        matching: find.byType(CircularAssetIconButton),
      ),
    );
    expect(circularButton.backgroundColor, const Color(0xFFF3F4F6));
    expect(
      find.descendant(
        of: find.byType(CircularAssetIconButton),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );

    final teamSize = tester.getRect(find.byKey(const Key('team-size-control')));
    final buildButton = tester.getRect(
      find.byKey(const Key('build-teams-button')),
    );
    final unselectedTitle = tester.getRect(
      find.byKey(const Key('unselected-section-title')),
    );
    expect(teamSize.top, buildButton.top);
    expect(teamSize.height, buildButton.height);
    expect(buildButton.width, greaterThan(teamSize.width * 1.8));
    expect(buildButton.bottom, lessThanOrEqualTo(unselectedTitle.top));
  });

  testWidgets('inputs are white and guest dialog controls match top height', (
    tester,
  ) async {
    final members = MemoryMemberRepository([
      Member(id: '1', name: '김클럽', score: 180),
    ]);
    await tester.pumpWidget(
      TeamMakerApp(
        memberRepository: members,
        historyRepository: MemoryHistoryRepository(),
        workspaceRepository: MemoryWorkspaceRepository(),
        galleryExporter: MemoryGalleryExporter(),
        idFactory: SequenceIds().next,
        random: Random(31),
        now: () => DateTime(2026, 9, 8, 12),
      ),
    );
    await tester.pumpAndSettle();

    final inputContext = tester.element(
      find.byKey(const Key('member-name-input')),
    );
    final inputTheme = Theme.of(inputContext).inputDecorationTheme;
    expect(inputTheme.fillColor, Colors.white);
    final focusedBorder = inputTheme.focusedBorder! as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, const Color(0xFF42A5F5));
    final memberScore = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('member-score-1')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(
      memberScore.decoration.contentPadding,
      const EdgeInsets.symmetric(horizontal: 8),
    );
    final memberScoreField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('member-score-1')),
        matching: find.byType(TextField),
      ),
    );
    expect(memberScoreField.textAlignVertical, TextAlignVertical.center);
    expect(
      tester.getSize(find.byKey(const Key('member-score-1'))),
      const Size(76, 32),
    );
    final memberCard = tester.getRect(find.byKey(const Key('member-card-1')));
    final trashButton = tester.getRect(find.byType(BorderedAssetIconButton));
    expect(memberCard.right - trashButton.right, greaterThanOrEqualTo(8));
    final scoreField = tester.getRect(find.byKey(const Key('member-score-1')));
    expect(trashButton.left - scoreField.right, greaterThanOrEqualTo(8));

    final memberAppBar = tester.widget<AppBar>(find.byType(AppBar));
    final memberAppBarBorder = memberAppBar.shape! as Border;
    expect(memberAppBarBorder.bottom.color, const Color(0xFFF3F4F6));

    final saveButton = find.byKey(const Key('save-members-button'));
    expect(
      find.descendant(
        of: saveButton,
        matching: find.byIcon(Icons.save_outlined),
      ),
      findsNothing,
    );

    await tester.tap(find.text('팀짜기').last);
    await tester.pumpAndSettle();
    final participantScoreField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('participant-score-participant-1')),
        matching: find.byType(TextField),
      ),
    );
    expect(participantScoreField.textAlignVertical, TextAlignVertical.center);
    expect(
      participantScoreField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 4),
    );
    expect(
      tester.getSize(find.byKey(const Key('participant-score-participant-1'))),
      const Size(45, 28),
    );
    final topControlHeight = tester
        .getRect(find.byKey(const Key('team-size-control')))
        .height;
    await tester.tap(find.byKey(const Key('guest-add-card')));
    await tester.pumpAndSettle();

    final nameRect = tester.getRect(
      find.byKey(const Key('temporary-name-input')),
    );
    final scoreRect = tester.getRect(
      find.byKey(const Key('temporary-score-input')),
    );
    expect(nameRect.height, closeTo(topControlHeight, 1));
    expect(scoreRect.height, closeTo(topControlHeight, 1));
    expect(scoreRect.top - nameRect.bottom, greaterThanOrEqualTo(8));
    for (final key in ['temporary-name-input', 'temporary-score-input']) {
      final field = tester.widget<TextField>(find.byKey(Key(key)));
      expect(field.decoration?.border, isA<OutlineInputBorder>());
    }
  });

  testWidgets('team total uses a top divider and colored score labels', (
    tester,
  ) async {
    final result = TeamResult(
      id: 'result',
      title: '테스트',
      createdAt: DateTime(2026, 9, 8),
      teamSize: 1,
      teams: [
        Team(
          number: 1,
          participants: [
            Participant(
              id: 'member',
              name: '김클럽',
              score: 180,
              type: ParticipantType.regular,
            ),
          ],
          bonusScore: 15,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TeamResultContent(result: result)),
      ),
    );

    final panel = tester.widget<Container>(
      find.byKey(const Key('team-total-panel-1')),
    );
    expect(panel.color, Colors.white);
    expect(panel.decoration, isNull);
    final divider = tester.widget<Divider>(
      find.descendant(
        of: find.byKey(const Key('team-total-panel-1')),
        matching: find.byType(Divider),
      ),
    );
    expect(divider.indent, 16);
    expect(divider.endIndent, 16);
    expect(divider.color, Colors.black);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('team-total-score-1')))
          .style
          ?.color,
      Colors.black,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('team-bonus-score-1')))
          .style
          ?.color,
      const Color(0xFF1976D2),
    );
    final totalRow = tester.widget<Row>(
      find.byKey(const Key('team-total-row-1')),
    );
    expect(totalRow.crossAxisAlignment, CrossAxisAlignment.baseline);
    expect(totalRow.textBaseline, TextBaseline.alphabetic);
    final bonusRect = tester.getRect(
      find.byKey(const Key('team-bonus-score-1')),
    );
    final totalRect = tester.getRect(
      find.byKey(const Key('team-total-score-1')),
    );
    expect(bonusRect.right, lessThan(totalRect.left));
  });

  testWidgets('exported result uses the app background color', (tester) async {
    final result = TeamResult(
      id: 'result',
      title: '테스트',
      createdAt: DateTime(2026, 9, 8),
      teamSize: 2,
      teams: const [],
    );
    await tester.pumpWidget(
      MaterialApp(home: TeamResultExportWidget(result: result)),
    );

    final background = tester.widget<Container>(
      find.byKey(const Key('team-result-export-background')),
    );
    expect(background.color, const Color(0xFFF3F4F6));
    final metadata = tester.widget<Text>(
      find.byKey(const Key('team-result-export-metadata')),
    );
    expect(metadata.style?.color, const Color(0xFF1976D2));
    expect(metadata.data, contains('  ·  '));
  });
}
