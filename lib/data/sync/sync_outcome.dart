enum SyncOutcomeKind { unchanged, remoteChanged, offline }

class SyncOutcome<T> {
  const SyncOutcome._(this.kind, {this.snapshot, this.error});

  const SyncOutcome.unchanged() : this._(SyncOutcomeKind.unchanged);

  const SyncOutcome.remoteChanged(T value)
    : this._(SyncOutcomeKind.remoteChanged, snapshot: value);

  const SyncOutcome.offline(Object value)
    : this._(SyncOutcomeKind.offline, error: value);

  final SyncOutcomeKind kind;
  final T? snapshot;
  final Object? error;
}
