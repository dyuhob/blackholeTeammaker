import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/member_repository.dart';
import '../data/team_history_repository.dart';
import '../data/workspace_repository.dart';
import '../domain/member.dart';
import '../domain/team_allocator.dart';
import '../domain/workspace_state.dart';
import '../features/history/history_controller.dart';
import '../features/members/member_controller.dart';
import '../features/team_builder/team_builder_controller.dart';
import '../services/gallery_exporter.dart';
import 'app_shell.dart';

class TeamMakerApp extends StatefulWidget {
  TeamMakerApp({
    super.key,
    required this.memberRepository,
    required this.historyRepository,
    required this.workspaceRepository,
    required this.galleryExporter,
    String Function()? idFactory,
    Random? random,
    DateTime Function()? now,
  }) : idFactory = idFactory ?? const Uuid().v4,
       random = random ?? Random(),
       now = now ?? DateTime.now;

  final MemberRepository memberRepository;
  final TeamHistoryRepository historyRepository;
  final WorkspaceRepository workspaceRepository;
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
  var _selectedTabIndex = 0;
  var _workspaceReady = false;

  @override
  void initState() {
    super.initState();
    _memberController = MemberController(
      repository: widget.memberRepository,
      idFactory: widget.idFactory,
    )..addListener(_memberChanged);
    _teamBuilderController = TeamBuilderController(
      allocator: TeamAllocator(
        random: widget.random,
        idFactory: widget.idFactory,
      ),
      idFactory: widget.idFactory,
      now: widget.now,
    )..addListener(_persistWorkspace);
    _historyController = HistoryController(widget.historyRepository);
    _initialize();
  }

  @override
  void dispose() {
    _memberController
      ..removeListener(_memberChanged)
      ..dispose();
    _teamBuilderController
      ..removeListener(_persistWorkspace)
      ..dispose();
    _historyController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _memberController.initialize(),
      _historyController.initialize(),
    ]);
    try {
      final workspace = await widget.workspaceRepository.load();
      if (workspace != null) {
        _memberController.restoreWorkspace(
          draftMembers: workspace.draftMembers,
          pendingName: workspace.pendingMemberName,
          pendingScore: workspace.pendingMemberScore,
        );
        _teamBuilderController.restoreWorkspace(
          participants: workspace.participants,
          teamSizeInput: workspace.teamSizeInput,
          title: workspace.title,
        );
        _selectedTabIndex = workspace.selectedTabIndex.clamp(0, 2);
      }
    } on Object {
      // A damaged workspace draft must not prevent saved data from opening.
    }
    _workspaceReady = true;
    _persistWorkspace();
    if (mounted) setState(() {});
  }

  void _memberChanged() {
    _publishSavedMembers();
    _persistWorkspace();
  }

  void _publishSavedMembers() {
    final current = _memberController.savedMembers;
    if (_membersEqual(_lastPublishedMembers, current)) return;
    _lastPublishedMembers = [...current];
    _teamBuilderController.setSavedMembers(current);
  }

  void _selectTab(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
    _persistWorkspace();
  }

  void _persistWorkspace() {
    if (!_workspaceReady) return;
    final state = WorkspaceState(
      selectedTabIndex: _selectedTabIndex,
      draftMembers: _memberController.draftMembers,
      pendingMemberName: _memberController.pendingName,
      pendingMemberScore: _memberController.pendingScore,
      participants: _teamBuilderController.participants,
      teamSizeInput: _teamBuilderController.teamSizeInput,
      title: _teamBuilderController.title,
    );
    unawaited(widget.workspaceRepository.save(state).catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '팀짜기',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3367D6)),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFBDBDBD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF42A5F5), width: 2),
        ),
      ),
    ),
    home: _workspaceReady
        ? AppShell(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: _selectTab,
            memberController: _memberController,
            teamBuilderController: _teamBuilderController,
            historyController: _historyController,
            galleryExporter: widget.galleryExporter,
          )
        : const Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

bool _membersEqual(List<Member> left, List<Member> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
