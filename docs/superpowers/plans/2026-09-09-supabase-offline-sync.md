# Supabase Offline Sync and PWA Install Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add shared Supabase persistence for club members and history while keeping local JSON authoritative until the user accepts a differing remote snapshot, and add the approved PWA installation prompt.

**Architecture:** Versioned local JSON documents keep active data plus an outbox. Separate member and history sync coordinators push the outbox, stage a complete Supabase snapshot, and let the UI accept or reject it. Supabase adapters map the existing `"user"`, `game`, and `participants` tables, while a web-only install bridge handles browser PWA prompts.

**Tech Stack:** Flutter 3.47.2, Dart 3.13, `supabase_flutter`, JSON file/localStorage persistence, Supabase Postgres/RLS/RPC, JavaScript PWA install events, Flutter Test.

**Spec:** `docs/superpowers/specs/2026-09-09-supabase-offline-sync-design.md`

## Global Constraints

- Do not commit or push any change until the user explicitly allows it.
- Keep the app usable with no Supabase configuration or network connection.
- Never embed a secret or service-role key in Flutter artifacts.
- Do not add a corrupt-data recovery backup key.
- Keep Team Builder workspace data device-local.
- Preserve the current uncommitted member/team sorting changes.
- Use `participants.average` as the saved participant score.
- Store correction scores only as derived UI values.

---

### Task 1: Versioned local sync documents

**Files:**
- Create: `lib/data/sync/pending_mutation.dart`
- Create: `lib/data/sync/member_sync_document.dart`
- Create: `lib/data/sync/history_sync_document.dart`
- Modify: `lib/data/json_member_repository.dart`
- Modify: `lib/data/json_team_history_repository.dart`
- Modify: `lib/data/member_repository.dart`
- Modify: `lib/data/team_history_repository.dart`
- Test: `test/data/json_repositories_test.dart`
- Test: `test/data/sync_documents_test.dart`

**Interfaces:**
- `PendingMutation(String id, String entityId, SyncMutationKind kind, Map<String, Object?> payload)`
- `MemberSyncDocument(List<Member> members, List<PendingMutation> pending)`
- `HistorySyncDocument(List<TeamResult> records, List<PendingMutation> pending)`
- `MemberSyncStore.readSyncDocument()`, `writeSyncDocument(...)`, and `replaceMembersFromRemote(...)`
- `HistorySyncStore.readSyncDocument()`, `writeSyncDocument(...)`, and `replaceHistoryFromRemote(...)`

- [ ] Write tests proving schema v1 loads as a v2 document with an empty outbox, member Save diffs the previous active list into upsert/tombstone operations, history mutations enqueue idempotent operations, and remote replacement preserves no acknowledged mutation.
- [ ] Run `flutter test test/data/json_repositories_test.dart test/data/sync_documents_test.dart` and confirm the new expectations fail before implementation.
- [ ] Implement strict JSON codecs and schema v1 migration. Store the outbox inside the same JSON object as the active data and compact repeated unsent changes for one entity to the latest intent.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Supabase row codecs and remote adapters

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/data/supabase/member_row_codec.dart`
- Create: `lib/data/supabase/history_row_codec.dart`
- Create: `lib/data/supabase/member_remote_data_source.dart`
- Create: `lib/data/supabase/history_remote_data_source.dart`
- Create: `lib/data/supabase/supabase_member_remote_data_source.dart`
- Create: `lib/data/supabase/supabase_history_remote_data_source.dart`
- Test: `test/data/supabase_row_codec_test.dart`

**Interfaces:**
- `MemberRemoteDataSource.push(PendingMutation mutation)` and `fetchAll()`
- `HistoryRemoteDataSource.push(PendingMutation mutation)` and `fetchAll()`
- Pure codec functions map `Member.score` to `"user".average` and `Participant.score` to `participants.average`.

- [ ] Add codec tests for club members, manual guests (`user_id=null`, `auto_insert=0`), automatic guests (`user_id=null`, `auto_insert=1`), regular participants (`user_id=sourceMemberId`, `auto_insert=null`), timestamps, and tombstones.
- [ ] Run `flutter test test/data/supabase_row_codec_test.dart` and confirm failure.
- [ ] Add `supabase_flutter` and implement the pure codecs plus Supabase adapters. Member mutations use upsert/update against `"user"`; history mutations call the transactional RPC and history pulls join canonical game and participant rows.
- [ ] Run the codec tests and `flutter analyze`.

### Task 3: Offline sync coordinators

**Files:**
- Create: `lib/data/sync/sync_outcome.dart`
- Create: `lib/data/sync/member_sync_coordinator.dart`
- Create: `lib/data/sync/history_sync_coordinator.dart`
- Test: `test/data/member_sync_coordinator_test.dart`
- Test: `test/data/history_sync_coordinator_test.dart`

**Interfaces:**
- `SyncOutcome<T>` variants: `unchanged`, `remoteChanged(T snapshot)`, and `offline(Object error)`.
- `MemberSyncCoordinator.synchronize(List<Member> visible)` and `acceptRemote(List<Member> snapshot)`.
- `HistorySyncCoordinator.synchronize(List<TeamResult> visible)` and `acceptRemote(List<TeamResult> snapshot)`.

- [ ] Write fake-store/fake-remote tests for ordered upload, stopping before pull on upload failure, idempotent retry, semantic equality that ignores ordering and metadata, staging a changed snapshot without writing it, accepting it explicitly, and coalescing overlapping calls.
- [ ] Run the two coordinator test files and confirm failure.
- [ ] Implement the coordinators with one in-flight Future per data set. Remove each acknowledged mutation durably, decode the entire pull before comparison, and return a staged snapshot without mutating the accepted local data.
- [ ] Run the coordinator tests and confirm they pass.

### Task 4: Screen integration and remote-change confirmation

**Files:**
- Modify: `lib/app/team_maker_app.dart`
- Modify: `lib/app/app_shell.dart`
- Modify: `lib/features/members/member_controller.dart`
- Modify: `lib/features/members/member_screen.dart`
- Modify: `lib/features/history/history_controller.dart`
- Modify: `lib/features/history/history_screen.dart`
- Modify: `lib/features/history/team_result_screen.dart`
- Modify: `lib/features/team_builder/team_builder_screen.dart`
- Test: `test/app/app_flow_test.dart`
- Test: `test/features/members/member_controller_test.dart`
- Test: `test/features/history/history_controller_test.dart`

**Interfaces:**
- Controllers expose `reloadFromLocal()` so accepted remote JSON becomes the only source used to rebuild visible state.
- `TeamMakerApp` owns tab-entry and post-save synchronization callbacks.
- One shared dialog uses the exact message `변경된 내역이 있습니다. 현재 입력된 내용은 사라집니다. 불러오시겠습니까?` with `취소` and `불러오기`.

- [ ] Add tests showing tab entry triggers the correct coordinator, a differing member snapshot includes unsaved member drafts in comparison, Cancel preserves UI and JSON, Load rewrites JSON then reloads, and history save/delete requests synchronization.
- [ ] Run the focused app/controller tests and confirm failure.
- [ ] Wire coordinators through app factories and screens. Serialize dialogs, guard disposed contexts, and show `기기에 저장됨 · 연결되면 동기화됩니다` after a local save whose remote phase fails.
- [ ] Run the focused tests and confirm they pass.

### Task 5: Supabase schema migration and build configuration

**Files:**
- Create: `supabase/migrations/20260909000000_shared_club_sync.sql`
- Create: `lib/bootstrap/supabase_sync_factory.dart`
- Modify: `lib/bootstrap/app_factory_web.dart`
- Modify: `lib/bootstrap/app_factory_io.dart`
- Modify: `.github/workflows/deploy-vercel.yml`
- Modify: `.gitignore`
- Create: `config/supabase.example.json`
- Modify: `README.md`

**Interfaces:**
- `createSyncServices(JsonMemberRepository members, JsonTeamHistoryRepository history)` reads `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` through `String.fromEnvironment` and returns nullable coordinators.

- [ ] Write the SQL migration that alters the supplied existing schema without dropping user data: add server timestamps/tombstones, add `game.client_id`, add `participants.game_id` and scoped text `client_id`, convert nullable `participants.user_id` to match `"user".id`, add indexes/triggers, configure public anon grants/RLS, and create idempotent transactional history save/delete RPCs.
- [ ] Add SQL verification queries as comments that inspect columns, foreign keys, policies, and functions after execution.
- [ ] Implement local-only fallback when Dart defines are absent or the Supabase client cannot be constructed.
- [ ] Pass the two GitHub secrets to `flutter build web` and document equivalent `--dart-define-from-file=config/supabase.local.json` commands for web/APK builds. Keep the local file ignored.
- [ ] Run `flutter analyze` and the data tests.

### Task 6: PWA install prompt

**Files:**
- Create: `lib/services/pwa_install_service.dart`
- Create: `lib/services/pwa_install_service_io.dart`
- Create: `lib/services/pwa_install_service_web.dart`
- Create: `lib/services/pwa_install_policy.dart`
- Modify: `web/flutter_bootstrap.js`
- Modify: `lib/app/team_maker_app.dart`
- Test: `test/services/pwa_install_policy_test.dart`
- Test: `test/app/app_flow_test.dart`

**Interfaces:**
- `PwaInstallService.shouldOffer()`, `canPrompt`, `requestInstall()`, and `dismiss()`.
- Web JavaScript exposes `window.teamMakerPwaInstall.shouldShow()`, `canPrompt()`, `prompt()`, and `dismiss()`.

- [ ] Add pure policy tests for first access, standalone suppression, a dismissal younger than seven days, and eligibility after seven full days.
- [ ] Run `flutter test test/services/pwa_install_policy_test.dart` and confirm failure.
- [ ] Capture `beforeinstallprompt`, record dismissal in localStorage, expose the JS bridge, and implement conditional Dart services with an APK no-op.
- [ ] Show the Flutter installation dialog after local initialization. Invoke the native browser prompt from the install button when available; otherwise show manual Add to Home Screen instructions.
- [ ] Run the policy and app-flow tests.

### Task 7: Full verification and review

**Files:**
- Review all files changed by Tasks 1-6 plus the previously uncommitted sorting changes.

**Interfaces:**
- No new interface; this task verifies the complete integration.

- [ ] Run `dart format lib test`.
- [ ] Run `flutter test` and require all tests to pass.
- [ ] Run `flutter analyze` and require no issues.
- [ ] Run `git diff --check` and inspect `git diff --stat` plus `git status --short`.
- [ ] Confirm no service-role/secret key or real Supabase credential exists in tracked or untracked project files.
- [ ] Leave every change uncommitted and unpushed for user review.
