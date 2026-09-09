enum SyncMutationKind { upsert, delete }

String createMutationId(
  SyncMutationKind kind,
  String entityId,
  Object payload,
) => '${kind.name}:$entityId:${payload.hashCode}';

class PendingMutation {
  const PendingMutation({
    required this.id,
    required this.entityId,
    required this.kind,
    required this.payload,
  });

  final String id;
  final String entityId;
  final SyncMutationKind kind;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'id': id,
    'entityId': entityId,
    'kind': kind.name,
    'payload': payload,
  };

  factory PendingMutation.fromJson(Map<String, Object?> json) =>
      PendingMutation(
        id: json['id']! as String,
        entityId: json['entityId']! as String,
        kind: SyncMutationKind.values.byName(json['kind']! as String),
        payload: Map<String, Object?>.from(json['payload']! as Map),
      );
}

List<PendingMutation> compactMutation(
  Iterable<PendingMutation> pending,
  PendingMutation next,
) => [...pending.where((value) => value.entityId != next.entityId), next];
