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
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final MemberController memberController;
  final TeamBuilderController teamBuilderController;
  final HistoryController historyController;
  final GalleryExporter galleryExporter;

  static const _titles = ['클럽원 관리', '팀짜기', '기록'];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[selectedIndex])),
    body: IndexedStack(
      index: selectedIndex,
      children: [
        MemberScreen(controller: memberController),
        TeamBuilderScreen(
          controller: teamBuilderController,
          historyController: historyController,
          galleryExporter: galleryExporter,
        ),
        HistoryScreen(
          controller: historyController,
          galleryExporter: galleryExporter,
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
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
  );
}
