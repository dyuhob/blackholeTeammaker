import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/member_repository.dart';
import '../data/team_history_repository.dart';
import '../domain/member.dart';
import '../domain/team_allocator.dart';
import '../features/history/history_controller.dart';
import '../features/members/member_controller.dart';
import '../features/team_builder/team_builder_controller.dart';
import '../services/gallery_export_service.dart';
import 'app_shell.dart';

class TeamMakerApp extends StatefulWidget {
  TeamMakerApp({
    super.key,
    required this.memberRepository,
    required this.historyRepository,
    required this.galleryExporter,
    String Function()? idFactory,
    Random? random,
    DateTime Function()? now,
  }) : idFactory = idFactory ?? const Uuid().v4,
       random = random ?? Random(),
       now = now ?? DateTime.now;

  final MemberRepository memberRepository;
  final TeamHistoryRepository historyRepository;
  final GalleryExporter galleryExporter;
  final String Function() idFactory;
  final Random random;
  final DateTime Function() now;

  @override
  State<TeamMakerApp> createState() => _TeamMakerAppState();
}

class _TeamMakerAppState extends State<TeamMakerApp> {
  late final MemberController _memberController;
  late final TeamBuilderController _teamBuilderController;
  late final HistoryController _historyController;
  List<Member> _lastPublishedMembers = [];

  @override
  void initState() {
    super.initState();
    _memberController = MemberController(
      repository: widget.memberRepository,
      idFactory: widget.idFactory,
    )..addListener(_publishSavedMembers);
    _teamBuilderController = TeamBuilderController(
      allocator: TeamAllocator(
        random: widget.random,
        idFactory: widget.idFactory,
      ),
      idFactory: widget.idFactory,
      now: widget.now,
    );
    _historyController = HistoryController(widget.historyRepository);
    _memberController.initialize();
    _historyController.initialize();
  }

  @override
  void dispose() {
    _memberController
      ..removeListener(_publishSavedMembers)
      ..dispose();
    _teamBuilderController.dispose();
    _historyController.dispose();
    super.dispose();
  }

  void _publishSavedMembers() {
    final current = _memberController.savedMembers;
    if (_membersEqual(_lastPublishedMembers, current)) return;
    _lastPublishedMembers = [...current];
    _teamBuilderController.setSavedMembers(current);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '팀짜기',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3367D6)),
      inputDecorationTheme: const InputDecorationTheme(filled: true),
    ),
    home: AppShell(
      memberController: _memberController,
      teamBuilderController: _teamBuilderController,
      historyController: _historyController,
      galleryExporter: widget.galleryExporter,
    ),
  );
}

bool _membersEqual(List<Member> left, List<Member> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
