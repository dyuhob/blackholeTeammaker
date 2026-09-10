import 'package:flutter/material.dart';

import '../features/history/history_controller.dart';
import '../features/history/history_screen.dart';
import '../features/members/member_controller.dart';
import '../features/members/member_screen.dart';
import '../features/team_builder/team_builder_controller.dart';
import '../features/team_builder/team_builder_screen.dart';
import '../services/gallery_exporter.dart';
import 'navigation_icon_assets.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.memberController,
    required this.teamBuilderController,
    required this.historyController,
    required this.galleryExporter,
    required this.onMemberSaved,
    required this.onHistoryChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MemberController memberController;
  final TeamBuilderController teamBuilderController;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;
  final Future<bool> Function() onMemberSaved;
  final Future<bool> Function() onHistoryChanged;

  static const _titles = ['클럽원 관리', '팀짜기', '기록'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_titles[selectedIndex]),
      shape: Border(
        bottom: BorderSide(
          color: selectedIndex == 0
              ? const Color(0xFFF3F4F6)
              : const Color(0xFFE5E7EB),
        ),
      ),
    ),
    body: IndexedStack(
      index: selectedIndex,
      children: [
        MemberScreen(controller: memberController, onSaved: onMemberSaved),
        TeamBuilderScreen(
          controller: teamBuilderController,
          historyController: historyController,
          galleryExporter: galleryExporter,
          onHistoryChanged: onHistoryChanged,
        ),
        HistoryScreen(
          controller: historyController,
          galleryExporter: galleryExporter,
          onHistoryChanged: onHistoryChanged,
        ),
      ],
    ),
    bottomNavigationBar: DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        elevation: 0,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: NavigationTabIcon(
              assetPath: NavigationIconAssets.membersOutline,
              fallback: Icons.people_outline,
            ),
            selectedIcon: NavigationTabIcon(
              assetPath: NavigationIconAssets.membersFilled,
              fallback: Icons.people,
            ),
            label: '클럽원 관리',
          ),
          NavigationDestination(
            icon: NavigationTabIcon(
              assetPath: NavigationIconAssets.teamsOutline,
              fallback: Icons.shuffle_outlined,
            ),
            selectedIcon: NavigationTabIcon(
              assetPath: NavigationIconAssets.teamsFilled,
              fallback: Icons.shuffle,
            ),
            label: '팀짜기',
          ),
          NavigationDestination(
            icon: NavigationTabIcon(
              assetPath: NavigationIconAssets.historyOutline,
              fallback: Icons.history_outlined,
            ),
            selectedIcon: NavigationTabIcon(
              assetPath: NavigationIconAssets.historyFilled,
              fallback: Icons.history,
            ),
            label: '기록',
          ),
        ],
      ),
    ),
  );
}
