import 'package:flutter/material.dart';

import '../features/history/history_controller.dart';
import '../features/history/history_screen.dart';
import '../features/members/member_controller.dart';
import '../features/members/member_screen.dart';
import '../features/team_builder/team_builder_controller.dart';
import '../features/team_builder/team_builder_screen.dart';
import '../services/gallery_export_service.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.memberController,
    required this.teamBuilderController,
    required this.historyController,
    required this.galleryExporter,
  });

  final MemberController memberController;
  final TeamBuilderController teamBuilderController;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _titles = ['클럽원 관리', '팀짜기', '기록'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[_index])),
    body: IndexedStack(
      index: _index,
      children: [
        MemberScreen(controller: widget.memberController),
        TeamBuilderScreen(
          controller: widget.teamBuilderController,
          historyController: widget.historyController,
          galleryExporter: widget.galleryExporter,
        ),
        HistoryScreen(
          controller: widget.historyController,
          galleryExporter: widget.galleryExporter,
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: '클럽원 관리',
        ),
        NavigationDestination(
          icon: Icon(Icons.shuffle_outlined),
          selectedIcon: Icon(Icons.shuffle),
          label: '팀짜기',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: '기록',
        ),
      ],
    ),
  );
}
