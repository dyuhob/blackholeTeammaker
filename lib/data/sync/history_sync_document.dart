import '../../domain/team_result.dart';
import 'pending_mutation.dart';

class HistorySyncDocument {
  const HistorySyncDocument({
    this.records = const [],
    this.pendingMutations = const [],
  });

  final List<TeamResult> records;
  final List<PendingMutation> pendingMutations;

  HistorySyncDocument copyWith({
    List<TeamResult>? records,
    List<PendingMutation>? pendingMutations,
  }) => HistorySyncDocument(
    records: records ?? this.records,
    pendingMutations: pendingMutations ?? this.pendingMutations,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'records': records.map((value) => value.toJson()).toList(),
    'pendingMutations': pendingMutations
        .map((value) => value.toJson())
        .toList(),
  };
}
