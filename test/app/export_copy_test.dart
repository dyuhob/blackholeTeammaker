import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/domain/participant.dart';
import 'package:team_maker/domain/team.dart';
import 'package:team_maker/domain/team_result.dart';
import 'package:team_maker/features/history/history_controller.dart';
import 'package:team_maker/features/history/team_result_screen.dart';

import '../support/memory_repositories.dart';

void main() {
  testWidgets('result screen uses exporter-provided download labels', (
    tester,
  ) async {
    final historyController = HistoryController(MemoryHistoryRepository());
    addTearDown(historyController.dispose);
    final exporter = MemoryGalleryExporter(
      actionLabel: '이미지 다운로드',
      busyLabel: '준비 중…',
      successMessage: '이미지를 다운로드했습니다.',
      failureMessage: '이미지를 다운로드하지 못했습니다.',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TeamResultScreen(
          result: sampleResult,
          historyController: historyController,
          galleryExporter: exporter,
          initiallySaved: true,
        ),
      ),
    );

    expect(find.text('이미지 다운로드'), findsOneWidget);
    await tester.tap(find.text('이미지 다운로드'));
    await tester.pumpAndSettle();

    expect(exporter.saved, [sampleResult]);
    expect(find.text('이미지를 다운로드했습니다.'), findsOneWidget);
  });
}

final sampleResult = TeamResult(
  id: 'result-1',
  title: '웹 결과',
  createdAt: DateTime(2026, 9, 8, 21),
  teamSize: 1,
  teams: [
    Team(
      number: 1,
      participants: [
        Participant(
          id: 'participant-1',
          name: '김회원',
          score: 180,
          type: ParticipantType.regular,
        ),
      ],
    ),
  ],
);
