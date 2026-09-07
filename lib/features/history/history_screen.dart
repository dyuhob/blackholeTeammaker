import 'package:flutter/material.dart';

import '../../services/gallery_export_service.dart';
import 'history_controller.dart';
import 'team_result_content.dart';
import 'team_result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.controller,
    required this.galleryExporter,
  });

  final HistoryController controller;
  final GalleryExporter galleryExporter;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.results.isEmpty) {
        return const Center(child: Text('저장된 팀 편성 기록이 없습니다.'));
      }
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: controller.results.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final result = controller.results[index];
          return Card(
            child: ListTile(
              title: Text(result.title),
              subtitle: Text(
                '${formatDateTime(result.createdAt)} · ${result.teams.length}팀 · 팀당 ${result.teamSize}명',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TeamResultScreen(
                    result: result,
                    historyController: controller,
                    galleryExporter: galleryExporter,
                    initiallySaved: true,
                  ),
                ),
              ),
              trailing: IconButton(
                tooltip: '기록 삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, result.id),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _confirmDelete(BuildContext context, String resultId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기록을 삭제할까요?'),
        content: const Text('앱 내부 기록만 삭제되며 갤러리 이미지는 유지됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await controller.deleteResult(resultId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleted ? '기록을 삭제했습니다.' : '기록을 삭제하지 못했습니다.')),
      );
    }
  }
}
