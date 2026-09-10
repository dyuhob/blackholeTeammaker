import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/member_repository.dart';
import '../data/sync/history_sync.dart';
import '../data/sync/member_sync.dart';
import '../data/sync/sync_outcome.dart';
import '../data/team_history_repository.dart';
import '../data/workspace_repository.dart';
import '../domain/member.dart';
import '../domain/team_allocator.dart';
import '../domain/workspace_state.dart';
import '../features/history/history_controller.dart';
import '../features/members/member_controller.dart';
import '../features/team_builder/team_builder_controller.dart';
import '../services/gallery_exporter.dart';
import '../services/pwa_install_service.dart';
import 'app_shell.dart';

class TeamMakerApp extends StatefulWidget {
  TeamMakerApp({
    super.key,
    required this.memberRepository,
    required this.historyRepository,
    required this.workspaceRepository,
    required this.galleryExporter,
    this.memberSync,
    this.historySync,
    this.pwaInstallService,
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
  final MemberSync? memberSync;
  final HistorySync? historySync;
  final PwaInstallService? pwaInstallService;
  final String Function() idFactory;
  final Random random;
  final DateTime Function() now;

  @override
  State<TeamMakerApp> createState() => _TeamMakerAppState();
}

class _TeamMakerAppState extends State<TeamMakerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final MemberController _memberController;
  late final TeamBuilderController _teamBuilderController;
  late final HistoryController _historyController;
  List<Member> _lastPublishedMembers = [];
  var _selectedTabIndex = 0;
  var _workspaceReady = false;
  var _dialogVisible = false;

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
    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runInitialTasks());
      });
    }
  }

  Future<void> _runInitialTasks() async {
    await _offerPwaInstall();
    await _syncTab(_selectedTabIndex);
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
    unawaited(_syncTab(index));
  }

  Future<bool> _syncTab(int index, {bool showOfflineMessage = false}) async {
    if (!mounted) return false;
    if (index == 0 && widget.memberSync != null) {
      final outcome = await widget.memberSync!.synchronize(
        _memberController.draftMembers,
      );
      if (!mounted) return false;
      if (outcome.kind == SyncOutcomeKind.remoteChanged) {
        final load = await _confirmRemoteLoad();
        if (load == true && mounted) {
          await widget.memberSync!.acceptRemote(outcome.snapshot!);
          await _memberController.reloadFromLocal();
        }
      } else if (showOfflineMessage &&
          outcome.kind == SyncOutcomeKind.offline) {
        _showMessage('기기에 저장됨 · 연결되면 동기화됩니다');
      }
      return outcome.kind != SyncOutcomeKind.offline;
    }
    if (index == 2 && widget.historySync != null) {
      final outcome = await widget.historySync!.synchronize(
        _historyController.results,
      );
      if (!mounted) return false;
      if (outcome.kind == SyncOutcomeKind.remoteChanged) {
        final load = await _confirmRemoteLoad();
        if (load == true && mounted) {
          await widget.historySync!.acceptRemote(outcome.snapshot!);
          await _historyController.reloadFromLocal();
        }
      } else if (showOfflineMessage &&
          outcome.kind == SyncOutcomeKind.offline) {
        _showMessage('기기에 저장됨 · 연결되면 동기화됩니다');
      }
      return outcome.kind != SyncOutcomeKind.offline;
    }
    return false;
  }

  Future<bool?> _confirmRemoteLoad() async {
    if (_dialogVisible) return false;
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null) return false;
    _dialogVisible = true;
    try {
      return await showDialog<bool>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          content: const Text(
            '변경된 내역이 있습니다.\n'
            '현재 입력된 내용은 사라집니다. 불러오시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('불러오기'),
            ),
          ],
        ),
      );
    } finally {
      _dialogVisible = false;
    }
  }

  Future<void> _offerPwaInstall() async {
    final service = widget.pwaInstallService;
    if (service == null || _dialogVisible || !await service.shouldOffer()) {
      return;
    }
    final dialogContext = _navigatorKey.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    _dialogVisible = true;
    try {
      final canPrompt = service.canPrompt;
      final action = await showDialog<_PwaInstallAction>(
        context: dialogContext,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('홈 화면에 설치'),
          content: Text(
            canPrompt
                ? '팀짜기 앱을 홈 화면에 설치하면 더 빠르게 실행할 수 있습니다.'
                : service.isIos
                ? 'Safari 공유 버튼을 누른 뒤 홈 화면에 추가를 선택해 주세요.'
                : '브라우저 메뉴에서 홈 화면에 추가 또는 앱 설치를 선택해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _PwaInstallAction.dismiss),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                canPrompt
                    ? _PwaInstallAction.install
                    : _PwaInstallAction.dismiss,
              ),
              child: Text(canPrompt ? '설치하기' : '확인'),
            ),
          ],
        ),
      );
      if (action == _PwaInstallAction.install) {
        await service.requestInstall();
      } else {
        await service.dismiss();
      }
    } finally {
      _dialogVisible = false;
    }
  }

  void _showMessage(String message) {
    final messageContext = _navigatorKey.currentContext;
    if (messageContext == null) return;
    ScaffoldMessenger.of(messageContext)
        .showSnackBar(SnackBar(content: Text(message)));
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
    navigatorKey: _navigatorKey,
    title: '팀짜기',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3367D6)),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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
            onMemberSaved: () => _syncTab(0, showOfflineMessage: true),
            onHistoryChanged: () => _syncTab(2, showOfflineMessage: true),
          )
        : const Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

enum _PwaInstallAction { install, dismiss }

bool _membersEqual(List<Member> left, List<Member> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
