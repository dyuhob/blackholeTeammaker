import '../../domain/member.dart';
import 'pending_mutation.dart';

class MemberSyncDocument {
  const MemberSyncDocument({
    this.members = const [],
    this.pendingMutations = const [],
  });

  final List<Member> members;
  final List<PendingMutation> pendingMutations;

  MemberSyncDocument copyWith({
    List<Member>? members,
    List<PendingMutation>? pendingMutations,
  }) => MemberSyncDocument(
    members: members ?? this.members,
    pendingMutations: pendingMutations ?? this.pendingMutations,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 2,
    'members': members.map((value) => value.toJson()).toList(),
    'pendingMutations': pendingMutations
        .map((value) => value.toJson())
        .toList(),
  };
}
