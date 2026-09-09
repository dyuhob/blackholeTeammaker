# Supabase Offline Sync and PWA Install Design

## Goal

Add a shared Supabase database to Club Member Management and Team History while preserving the existing local JSON behavior. The app must remain fully usable when Supabase is unavailable. Remote data must never overwrite visible data until the user explicitly chooses to load it when the contents differ.

The PWA must also show a custom installation prompt on first access, hide it for seven days after dismissal, and remain compatible with browsers that only support manual home-screen installation.

## Scope

This change includes:

- Shared Supabase persistence for club members and saved team results.
- Local-first JSON reads and writes on Android and the web.
- An offline operation queue stored with each local JSON document.
- Last-write-wins synchronization based on server-assigned `updated_at` values.
- Soft deletion with `deleted_at` tombstones.
- A confirmation dialog before a different remote snapshot replaces visible data.
- A transactional remote save for a team result and all of its participants.
- Build-time Supabase configuration for PWA and APK builds.
- A first-access PWA installation prompt with a seven-day dismissal period.

This change excludes:

- Login UI or Supabase anonymous authentication.
- Author-specific update or delete permissions.
- A secondary local backup key for corrupt-data recovery.
- Synchronization of the temporary Team Builder workspace.
- Persisting score correction values; they remain derived display data.

## User-Visible Behavior

### Local startup and menu entry

The app reads local JSON first and immediately renders it. Entering Club Member Management or History starts a background synchronization for that data set. The first tab follows the same behavior when the app initially opens.

The Team Builder workspace remains device-local. Remote member refreshes do not silently replace current Team Builder inputs.

### Saving

Club member edits remain drafts until the user presses Save. Pressing Save writes the complete member state and its pending remote operations to local JSON first. Saving, renaming, or deleting a team history entry follows the same local-first rule.

After the local write succeeds, the app attempts to send pending operations to Supabase. A failed request does not roll back the local write. The user can continue using the app, and the operation remains queued for a later synchronization.

Although the visible action is an insert or update, remote writes use client identifiers and idempotent upserts. This prevents duplicate members or history records when a request succeeds on the server but its response is lost and the app retries.

### Remote differences

After all queued operations have been uploaded successfully, the app fetches a complete remote snapshot into memory. It compares business fields with the currently visible screen state. Ordering and synchronization timestamps do not count as changes.

If the snapshots differ, the app shows:

> 변경된 내역이 있습니다.<br>
> 현재 입력된 내용은 사라집니다. 불러오시겠습니까?

The dialog provides these actions:

- **불러오기:** Write the staged remote snapshot to local JSON and reload the screen from that JSON.
- **취소:** Keep the current screen and local JSON, then discard the staged remote snapshot.

The remote snapshot is never written before confirmation. It exists only in memory and is not a recovery backup. If the user cancels, a later synchronization can offer the remote state again. Only one remote-change dialog may be visible at a time.

If pending uploads fail, the synchronization stops before the remote pull. This prevents an older remote snapshot from being offered while unsent local changes still exist.

### Offline feedback

Remote failures do not clear lists or block local use. When a user saves while offline, the app may show a concise message such as `기기에 저장됨 · 연결되면 동기화됩니다`. A tab-entry refresh failure does not replace the current list with an error screen.

## Data Architecture

### Existing boundaries

The existing domain models and repository interfaces remain the UI-facing boundary. JSON repositories continue to provide local persistence. Synchronization metadata is kept in persistence DTOs or envelopes so timestamps and queue state do not spread through the team allocation domain.

New components have narrow responsibilities:

- **Local repositories:** Read and atomically write local JSON documents.
- **Supabase data sources:** Map Supabase rows to remote DTOs and execute queries or RPC calls.
- **Outbox:** Store idempotent pending mutations inside the corresponding local JSON document.
- **Sync coordinators:** Upload the outbox, fetch a snapshot, compare semantic contents, and return a typed sync result.
- **Controllers/screens:** Decide when to sync and present the remote-change confirmation.
- **PWA install service:** Report installation capability, request installation after a user gesture, and store the dismissal time.

Separate member and history coordinators prevent a failure in one data set from blocking the other. Each coordinator serializes its own work so repeated tab changes cannot start overlapping uploads and pulls.

### Local JSON schema version 2

Both member and history JSON documents move from schema version 1 to schema version 2. Version 2 contains:

- The current active domain records.
- Persistence metadata for synchronized records.
- Ordered pending operations with unique operation IDs.
- The last accepted remote synchronization metadata needed for comparisons.

Version 1 documents are migrated in place without losing their records. Existing local records do not get uploaded merely because migration occurred. A subsequent explicit member Save or history mutation creates the required pending operations.

The outbox lives in the same JSON document as its data. Android retains atomic file replacement, and the web retains one local-storage value per document. No extra corrupt-data backup key is introduced.

## Supabase Schema

The existing public tables are retained and extended. The migration renames
the supplied `member` table to the final quoted `"user"` table, converts its
numeric IDs and participant references to strings, and preserves existing
`game.title`, `game.team_count`, and `game.team_size` data in the final game
columns.

### `public."user"`

| Column | Purpose |
|---|---|
| `id varchar` | App-generated member UUID string and primary identity. |
| `name text` | Club member name. |
| `average integer` | Club member score. |
| `created_at timestamptz` | Server creation time. |
| `updated_at timestamptz` | Server-controlled last-write time. |
| `deleted_at timestamptz null` | Member tombstone. |

The table name remains `user`, so all SQL must quote it as `"user"`.

### `public.game`

The existing bigint `id` remains the database key. The database supplies it using an identity or sequence.

| Column | Purpose |
|---|---|
| `id bigint` | Database primary key. |
| `client_id uuid unique` | App-generated `TeamResult.id`, used for idempotent upsert. |
| `name text` | Team arrangement title. |
| `group_count smallint` | Number of teams. |
| `group_size smallint` | Members per team. |
| `highest_average numeric` | Highest raw team total. |
| `created_at timestamptz` | Original result creation time. |
| `updated_at timestamptz` | Server-controlled last-write time. |
| `deleted_at timestamptz null` | Result tombstone. |

Score correction is not stored. It is recalculated as the difference between `highest_average` and each team total when rendering a result.

### `public.participants`

| Column | Purpose |
|---|---|
| `client_id text` | Existing app participant identifier. Unique within a game. |
| `game_id bigint` | Foreign key to `game.id`. |
| `user_id varchar null` | Nullable foreign key to `"user".id` for club members. |
| `name text` | Name snapshot used by saved history. |
| `average integer` | Participant score. |
| `team_no bigint` | Assigned team number. |
| `auto_insert smallint null` | Guest classification. |
| `updated_at timestamptz` | Server-controlled last-write time. |
| `deleted_at timestamptz null` | Participant tombstone. |

`client_id` is text rather than UUID because existing regular participant IDs use a `participant-<member-id>` format. Its uniqueness is scoped to `game_id`.

Participant types map as follows:

| Participant type | `user_id` | `auto_insert` |
|---|---:|---:|
| Club member | Member ID | `NULL` |
| Manually added guest | `NULL` | `0` |
| Automatically added guest | `NULL` | `1` |

`participants.user_id` therefore changes from `bigint NOT NULL` to the same string type as `"user".id` and permits null. The database does not add a CHECK constraint for the `auto_insert` mapping; the app enforces it.

### Timestamps and deletion

Database triggers assign `updated_at` using server time for inserts and meaningful updates. Clients do not choose the authoritative timestamp. Deletes performed by the app update `deleted_at` instead of physically deleting rows. Pulls include tombstones so other devices can remove deleted records from their active local view.

Tombstones are retained because a device may remain offline for an unbounded period. Automatic tombstone pruning is outside this scope.

### Transactional history writes

A Postgres RPC accepts one team result payload. In one transaction it:

1. Upserts `game` by `client_id`.
2. Resolves its bigint `game.id`.
3. Upserts the supplied participants by `(game_id, client_id)`.
4. Applies server timestamps.
5. Returns the canonical game and participant rows.

The RPC is idempotent so an outbox retry cannot duplicate a record. Title updates use the same record identity. History deletion writes the game tombstone and corresponding participant tombstones.

## Access Control

The app does not initialize or require Supabase Auth. It connects with the project URL and publishable key.

RLS policies and grants permit the unauthenticated `anon` role to select, insert, update, and delete shared club member and history data. The app itself uses soft-delete updates. This intentionally implements one public shared club with no per-author ownership restriction.

No secret or service-role key is present in source code, the PWA, or the APK. RLS is the only database authorization boundary exposed to the client.

## Synchronization Algorithm

Each data set follows this sequence:

1. Load local JSON and render it.
2. Acquire that coordinator's synchronization lock.
3. Read the latest outbox from local JSON.
4. Send operations in queue order.
5. After each acknowledged operation, persist its removal from the outbox.
6. If any upload fails, stop and return an offline/local-only result.
7. Fetch all active rows and relevant tombstones from Supabase.
8. Decode and validate the entire snapshot in memory.
9. Compare the remote business fields with the controller's current visible snapshot.
10. If equal, accept synchronization metadata without showing a dialog.
11. If different, return the staged snapshot for the confirmation dialog.
12. Write the staged snapshot to local JSON only when the user chooses **불러오기**, then reload the controller from JSON.

An invalid or partially decoded remote snapshot is rejected as a whole. It never partially rewrites local JSON.

### Last-write-wins

Supabase server arrival order defines the winner. Reconnecting offline operations receive a new server `updated_at` when uploaded, so a later accepted offline operation wins over an earlier remote update. Operations from one device remain ordered. Consecutive unsent operations for the same entity may be compacted to their final intent as long as save/delete ordering is preserved.

## PWA Installation

Web bootstrap code captures Chromium's `beforeinstallprompt` event and exposes a minimal callable bridge to Dart. Flutter shows the custom installation dialog only after local initialization finishes.

- If running in standalone display mode, no prompt appears.
- If a deferred browser prompt exists, **설치하기** calls it from the user's button gesture.
- If programmatic installation is unavailable, supported platforms show manual home-screen instructions. On iOS, this directs the user to Safari's Share menu and Add to Home Screen.
- Dismissal stores a timestamp in browser local storage.
- The prompt becomes eligible again seven full days after dismissal if the app is still not installed.
- The APK implementation is a no-op.

The dismissal value is a UI preference and is not used as a data backup.

## Configuration and Deployment

Supabase configuration uses compile-time Dart defines:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

The app enters local-only mode when either value is absent or Supabase initialization fails. Local development and APK builds can use an ignored define file. The Vercel GitHub Actions workflow reads both values from GitHub repository secrets and passes them to `flutter build web`.

The publishable key is expected to be present in the compiled client. Security relies on RLS. Secret and service-role keys must never be supplied to a Flutter build.

The repository includes a reviewed SQL migration for the table alterations, indexes, timestamp triggers, RLS policies, grants, and transactional history RPC. Applying that migration to the Supabase project is an explicit deployment step.

## Error Handling

- Local storage failure is shown as a save failure because offline durability was not achieved.
- Remote failure after a local save is reported as queued synchronization, not a failed save.
- Tab-entry remote failures leave current data visible.
- Malformed remote rows reject the entire staged snapshot.
- RPC retries use client identities and remain idempotent.
- Concurrent synchronization calls share one in-flight operation per data set.
- A disposed screen does not attempt to display a late dialog.

## Verification

Automated tests cover:

- JSON schema version 1 to version 2 migration.
- Local saves and durable outbox writes.
- Offline failure followed by successful idempotent retry.
- Member mapping through `"user".average`.
- Club member, manual guest, and automatic guest participant mappings.
- Tombstone creation and application.
- Semantic snapshot equality that ignores ordering and timestamps.
- Remote differences that do not modify JSON before confirmation.
- **불러오기** applying the remote snapshot and **취소** retaining local state.
- Rejected malformed snapshots and partial RPC failures.
- Serialization of overlapping synchronization requests.
- PWA install eligibility, seven-day dismissal, and standalone suppression.
- Existing member sorting and team allocation result ordering.

Repository-wide Flutter tests and static analysis run after the focused tests pass. The SQL migration also includes verification queries for columns, constraints, grants, policies, and RPC availability.

## Acceptance Criteria

- Members and history render from local JSON without network access.
- Pressing member Save or mutating history persists locally before remote work begins.
- Failed remote writes survive restart and retry later without duplicates.
- Entering Member Management or History checks Supabase without clearing the current list.
- A different remote result always requires explicit confirmation before replacing visible or local data.
- Team correction scores remain display-only derived values.
- All app users share the same Supabase club data without login or author ownership.
- The first eligible PWA visit offers installation and a dismissal suppresses the offer for seven days.
- Supabase credentials are injected at build time and no privileged key enters the client.
