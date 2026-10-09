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
  Rect inputBorderRect(WidgetTester tester, Finder field) {
    final editableText = find.descendant(
      of: field,
      matching: find.byType(EditableText),
    );
    final container = InputDecorator.containerOf(tester.element(editableText))!;
    return container.localToGlobal(Offset.zero) & container.size;
  }

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
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    final firstParticipantScore = inputBorderRect(
      tester,
      find.byKey(const Key('participant-score-participant-1')),
    );
    expect(firstParticipantScore.height, closeTo(24, 0.1));
    expect(
      firstParticipantScore.center.dy,
      closeTo(firstParticipant.center.dy, 0.1),
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

    final teamTitle = tester.getRect(find.byKey(const Key('team-title-input')));
    final teamSize = tester.getRect(find.byKey(const Key('team-size-control')));
    final allocationMode = tester.getRect(
      find.byKey(const Key('allocation-mode-toggle')),
    );
    final femaleHandicap = tester.getRect(
      find.byKey(const Key('female-handicap-control')),
    );
    final buildButton = tester.getRect(
      find.byKey(const Key('build-teams-button')),
    );
    final unselectedTitle = tester.getRect(
      find.byKey(const Key('unselected-section-title')),
    );
    expect(teamTitle.top, teamSize.top);
    expect(teamTitle.height, teamSize.height);
    expect(teamTitle.width, closeTo(teamSize.width * 3, 1));
    expect(find.text('팀별 인원'), findsOneWidget);
    expect(allocationMode.top, buildButton.top);
    expect(allocationMode.height, buildButton.height);
    expect(femaleHandicap.height, guestAdd.height);
    expect(allocationMode.height, guestAdd.height);
    expect(buildButton.height, guestAdd.height);
    expect(allocationMode.width, closeTo(buildButton.width, 1));
    expect(femaleHandicap.width, lessThan(buildButton.width));
    expect(femaleHandicap.left, closeTo(teamTitle.left, 0.1));
    expect(femaleHandicap.left, lessThan(allocationMode.left));
    expect(allocationMode.left, lessThan(buildButton.left));
    expect(allocationMode.top, greaterThan(teamTitle.bottom));
    expect(buildButton.bottom, lessThanOrEqualTo(unselectedTitle.top));

    final toggle = tester.widget<SegmentedButton<TeamAllocationMode>>(
      find.byKey(const Key('allocation-mode-toggle')),
    );
    final segmentButtons = find.descendant(
      of: find.byKey(const Key('allocation-mode-toggle')),
      matching: find.byType(TextButton),
    );
    expect(segmentButtons, findsNWidgets(2));
    for (final button in segmentButtons.evaluate()) {
      expect(
        tester
            .getRect(find.byElementPredicate((element) => element == button))
            .height,
        closeTo(allocationMode.height, 0.1),
      );
    }
    final handicapCheckbox = tester.getRect(
      find.descendant(
        of: find.byKey(const Key('female-handicap-control')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(handicapCheckbox.left, closeTo(teamTitle.left, 0.1));
    final primaryColor = Theme.of(
      tester.element(find.byKey(const Key('build-teams-button'))),
    ).colorScheme.primary;
    final toggleShape = toggle.style?.shape?.resolve({WidgetState.selected});
    expect(toggleShape, isA<RoundedRectangleBorder>());
    expect(
      (toggleShape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(12),
    );
    expect(
      toggle.style?.backgroundColor?.resolve({WidgetState.selected}),
      primaryColor,
    );
    expect(
      toggle.style?.foregroundColor?.resolve({WidgetState.selected}),
      Colors.white,
    );
    expect(
      toggle.style?.textStyle?.resolve({WidgetState.selected})?.fontWeight,
      FontWeight.bold,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('female-handicap-control')),
              matching: find.text('여성핸디'),
            ),
          )
          .style
          ?.fontWeight,
      FontWeight.bold,
    );

    expect(controller.allocationMode, TeamAllocationMode.random);
    await tester.tap(find.text('에버순'));
    await tester.pump();
    expect(controller.allocationMode, TeamAllocationMode.averageOrder);
    expect(controller.femaleHandicapEnabled, isFalse);
    await tester.tap(find.byKey(const Key('female-handicap-control')));
    await tester.pump();
    expect(controller.femaleHandicapEnabled, isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('guest-add-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('temporary-gender-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('여').last);
    await tester.enterText(
      find.byKey(const Key('temporary-name-input')),
      '여성 게스트',
    );
    await tester.enterText(
      find.byKey(const Key('temporary-score-input')),
      '170',
    );
    await tester.tap(find.byKey(const Key('add-temporary-button')));
    await tester.pumpAndSettle();
    expect(controller.participants.last.gender, MemberGender.female);
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
    final memberNameInput = tester.getRect(
      find.byKey(const Key('member-name-input')),
    );
    final memberScoreInput = tester.getRect(
      find.byKey(const Key('member-score-input')),
    );
    expect(memberScoreInput.width, closeTo(72, 0.1));
    expect(memberNameInput.width, greaterThan(memberScoreInput.width));
    final memberNameField = tester.widget<TextField>(
      find.byKey(const Key('member-name-input')),
    );
    final newMemberScoreField = tester.widget<TextField>(
      find.byKey(const Key('member-score-input')),
    );
    expect(memberNameField.decoration?.labelStyle?.fontSize, 14);
    expect(newMemberScoreField.decoration?.labelStyle?.fontSize, 14);
    final memberScore = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('member-score-1')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(
      memberScore.decoration.contentPadding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
    final memberScoreField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('member-score-1')),
        matching: find.byType(TextField),
      ),
    );
    expect(memberScoreField.textAlignVertical, TextAlignVertical.center);
    expect(memberScoreField.expands, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('member-score-1'))),
      const Size(76, 32),
    );
    final memberCard = tester.getRect(find.byKey(const Key('member-card-1')));
    final memberScoreBorder = inputBorderRect(
      tester,
      find.byKey(const Key('member-score-1')),
    );
    expect(memberScoreBorder.height, closeTo(32, 0.1));
    expect(memberScoreBorder.center.dy, closeTo(memberCard.center.dy, 0.1));
    final trashButton = tester.getRect(find.byType(BorderedAssetIconButton));
    expect(memberCard.right - trashButton.right, greaterThanOrEqualTo(8));
    final scoreField = tester.getRect(find.byKey(const Key('member-score-1')));
    expect(trashButton.left - scoreField.right, greaterThanOrEqualTo(8));

    final memberAppBar = tester.widget<AppBar>(find.byType(AppBar));
    final memberAppBarBorder = memberAppBar.shape! as Border;
    expect(memberAppBarBorder.bottom.color, const Color(0xFFF3F4F6));

    final saveButton = find.byKey(const Key('save-members-button'));
    final memberList = find.ancestor(
      of: find.byKey(const Key('member-card-1')),
      matching: find.byType(ListView),
    );
    final memberListRect = tester.getRect(memberList);
    final saveButtonRect = tester.getRect(saveButton);
    final navigationRect = tester.getRect(find.byType(NavigationBar));
    expect(
      navigationRect.top - saveButtonRect.bottom,
      closeTo(saveButtonRect.top - memberListRect.bottom, 0.1),
    );
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
    expect(participantScoreField.expands, isTrue);
    expect(
      participantScoreField.decoration?.contentPadding,
      const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
    expect(
      tester.getSize(find.byKey(const Key('participant-score-participant-1'))),
      const Size(45, 24),
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
          bonusScore: -15,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TeamResultContent(result: result)),
      ),
    );

    expect(find.text('-15'), findsOneWidget);
    expect(find.text('+15'), findsNothing);
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

  testWidgets('result shows each female handicap and black numbering', (
    tester,
  ) async {
    final result = TeamResult(
      id: 'female-result',
      title: '여성 핸디',
      createdAt: DateTime(2026, 10, 9),
      teamSize: 2,
      teams: [
        Team(
          number: 1,
          participants: [
            Participant(
              id: 'female-1',
              name: '여성 1',
              score: 180,
              type: ParticipantType.regular,
              gender: MemberGender.female,
              handicapScore: 12,
            ),
            Participant(
              id: 'female-2',
              name: '여성 2',
              score: 170,
              type: ParticipantType.regular,
              gender: MemberGender.female,
              handicapScore: 12,
            ),
          ],
        ),
      ],
    );

    Future<void> expectResultContent() async {
      expect(
        find.byKey(const Key('participant-handicap-female-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('participant-handicap-female-2')),
        findsOneWidget,
      );
      expect(find.text('+12'), findsNWidgets(2));
      expect(find.text('180'), findsOneWidget);
      expect(find.text('170'), findsOneWidget);
      expect(find.text('374'), findsOneWidget);
      for (final id in ['female-1', 'female-2']) {
        expect(
          tester
              .widget<Text>(find.byKey(Key('participant-number-$id')))
              .style
              ?.color,
          Colors.black,
        );
        expect(
          tester
              .widget<Text>(find.byKey(Key('participant-handicap-$id')))
              .style
              ?.color,
          Colors.red,
        );
        expect(
          tester
              .widget<Text>(find.byKey(Key('participant-handicap-$id')))
              .style
              ?.fontWeight,
          FontWeight.bold,
        );
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TeamResultContent(result: result)),
      ),
    );
    await expectResultContent();

    await tester.pumpWidget(
      MaterialApp(home: TeamResultExportWidget(result: result)),
    );
    await expectResultContent();
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
