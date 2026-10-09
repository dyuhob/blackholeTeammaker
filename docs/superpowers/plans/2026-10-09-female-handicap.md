# Female Handicap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable M/W gender data and an optional per-female +12 result handicap, persist it locally and in Supabase history, then deploy the verified PWA to Vercel.

**Architecture:** Gender travels from `Member` into selected `Participant` drafts, while the applied `handicapScore` is baked into copied result participants only after base-score allocation. `Team.rawScore` sums base score plus the applied handicap, and local/Supabase history stores that applied value so old results remain stable.

**Tech Stack:** Flutter/Dart, Material 3, JSON repositories, Supabase/PostgreSQL, Flutter tests, GitHub Actions, Vercel

**Spec:** `docs/superpowers/specs/2026-10-09-female-handicap-design.md`

## Global Constraints

- Gender storage is exactly M = 0 and W = 1.
- Female handicap is exactly 12 points per female participant and defaults to disabled.
- Random and average-order membership decisions use base `Participant.score`; handicap changes totals only.
- Automatically generated guests never receive a gender handicap.
- Legacy local and remote records missing gender or handicap load as 0.
- Existing score validation, result compensation, sharing, and offline-first synchronization behavior remain intact.
- Use existing Flutter/Material facilities; add no dependency.
- Preserve the already completed, uncommitted Random/Average-order implementation.
- Do not push the application until the production Supabase migration has been applied.

## Review Focus

- Legacy member, participant, and workspace JSON without new keys must load as male with zero handicap; Task 2 pins each form.
- Two or more female participants on one team must contribute 12 each, not 12 once per team; Task 4 asserts a literal +24 total.
- Enabling handicap must not change average-order team membership when a woman's adjusted score crosses another base score; Task 4 compares member-ID team sets with the option off and on.
- Female manual guests receive +12 while automatic guests remain at 0; Task 4 covers both in one allocation.
- A narrow mobile control row must not overflow with three equal columns; Task 5 runs the widget at 360 logical pixels and checks recorded Flutter exceptions.

---

### Task 1: Commit the Existing Allocation-mode Work

**Files:**
- Modify: `lib/domain/team_allocator.dart`
- Modify: `lib/features/team_builder/team_builder_controller.dart`
- Modify: `lib/features/team_builder/team_builder_screen.dart`
- Test: `test/domain/team_allocator_test.dart`
- Test: `test/features/team_builder/team_builder_controller_test.dart`
- Test: `test/app/compact_layout_test.dart`

**Interfaces:**
- Consumes: Current working-tree implementation approved in the preceding task.
- Produces: Clean baseline with `TeamAllocationMode.random` and `TeamAllocationMode.averageOrder` available to later tasks.

- [ ] **Step 1: Verify the current allocation-mode diff**

Run: `git diff --check`

Expected: exit 0 and no whitespace errors.

- [ ] **Step 2: Run the existing focused tests**

Run: `flutter test test/domain/team_allocator_test.dart test/features/team_builder/team_builder_controller_test.dart test/app/compact_layout_test.dart`

Expected: all tests pass, including average-order base behavior and 5:1/2:1 controls.

- [ ] **Step 3: Commit only the existing allocation-mode files**

```bash
git add lib/domain/team_allocator.dart lib/features/team_builder/team_builder_controller.dart lib/features/team_builder/team_builder_screen.dart test/domain/team_allocator_test.dart test/features/team_builder/team_builder_controller_test.dart test/app/compact_layout_test.dart
git commit -m "feat: add average-order team allocation"
```

### Task 2: Add Gender and Applied-handicap Domain Data

**Files:**
- Modify: `lib/domain/member.dart`
- Modify: `lib/domain/participant.dart`
- Modify: `lib/domain/team.dart`
- Modify: `lib/domain/workspace_state.dart`
- Test: `test/domain/models_test.dart`
- Test: `test/data/workspace_repository_test.dart`

**Interfaces:**
- Consumes: Existing `Member`, `Participant`, `Team`, and `WorkspaceState` JSON contracts.
- Produces: `MemberGender`, `Member.gender`, `Participant.gender`, `Participant.handicapScore`, `Participant.effectiveScore`, and `WorkspaceState.pendingMemberGender`.

- [ ] **Step 1: Write failing legacy and round-trip model tests**

Add tests with hand-written literals asserting:

```dart
expect(Member.fromJson({'id': 'm', 'name': '남성', 'score': 180}).gender,
    MemberGender.male);
expect(Member.fromJson(female.toJson()), female);
expect(Participant.fromJson(legacyParticipantJson).handicapScore, 0);
expect(femaleParticipant.effectiveScore, 192);
expect(Team(number: 1, participants: [femaleParticipant, male]).rawScore, 372);
```

Also assert two female participants with `handicapScore: 12` add 24 in total.

- [ ] **Step 2: Write a failing workspace compatibility test**

Assert a legacy workspace JSON with no `pendingMemberGender`, member gender, or participant handicap restores M/0, and a new W pending selection round-trips as W.

- [ ] **Step 3: Run the domain and workspace tests to verify RED**

Run: `flutter test test/domain/models_test.dart test/data/workspace_repository_test.dart`

Expected: compile/assertion failures naming the missing gender and handicap APIs.

- [ ] **Step 4: Implement the domain interfaces**

In `member.dart`, add:

```dart
enum MemberGender {
  male(0, 'M'),
  female(1, 'W');

  const MemberGender(this.storageValue, this.label);
  final int storageValue;
  final String label;
  static MemberGender fromStorage(Object? value);
}
```

Extend `Member` with `MemberGender gender = MemberGender.male` and include it in `copyWith`, JSON, equality, and hash code. `fromStorage(null)` returns male; only numeric 0 and 1 are valid.

Extend `Participant` with `MemberGender gender = MemberGender.male`, `int handicapScore = 0`, and `int get effectiveScore => score + handicapScore`. Include both fields in `copyWith`, JSON, equality, and hash code; missing JSON uses M/0.

Change `Team.rawScore` to sum `Participant.effectiveScore`.

Extend `WorkspaceState` with `MemberGender pendingMemberGender = MemberGender.male`, serialize it as 0/1, and default a missing JSON key to M.

- [ ] **Step 5: Run tests to verify GREEN**

Run: `flutter test test/domain/models_test.dart test/data/workspace_repository_test.dart`

Expected: all tests pass.

- [ ] **Step 6: Commit the domain contract**

```bash
git add lib/domain/member.dart lib/domain/participant.dart lib/domain/team.dart lib/domain/workspace_state.dart test/domain/models_test.dart test/data/workspace_repository_test.dart
git commit -m "feat: add gender and participant handicap data"
```

### Task 3: Add Member Gender Editing and Supabase Member Sync

**Files:**
- Modify: `lib/features/members/member_controller.dart`
- Modify: `lib/features/members/member_screen.dart`
- Modify: `lib/app/team_maker_app.dart`
- Modify: `lib/data/supabase/member_row_codec.dart`
- Modify: `lib/data/supabase/supabase_member_remote_data_source.dart`
- Test: `test/features/members/member_controller_test.dart`
- Test: `test/app/ui_rules_test.dart`
- Test: `test/app/compact_layout_test.dart`
- Test: `test/data/supabase_row_codec_test.dart`
- Test: `test/data/supabase_member_remote_data_source_test.dart`
- Test: `test/app/app_flow_test.dart`

**Interfaces:**
- Consumes: `MemberGender` and `WorkspaceState.pendingMemberGender` from Task 2.
- Produces: `MemberController.pendingGender`, `addMember(String, int, {MemberGender gender})`, and `updateGender(String, MemberGender)`; member Supabase rows include `gender`.

- [ ] **Step 1: Write failing controller tests**

Assert that a W member added through `addMember('여성', 180, gender: MemberGender.female)` remains W, `updateGender(id, MemberGender.male)` marks the draft changed, clearing a pending member resets gender to M, and restoring an unfinished W input preserves W.

- [ ] **Step 2: Write failing member UI tests**

Assert `member-gender-input` defaults to M, selecting W before Add creates a female draft, and `member-gender-<id>` changes an existing member to W. Verify the row has no overflow at the existing mobile viewport.

- [ ] **Step 3: Write failing Supabase member tests**

Use literal maps to assert `memberToRemoteRow` emits `'gender': 1`, decoding reads W, and the remote data source GET select includes `gender` while its POST body contains `gender: 1`.

- [ ] **Step 4: Run focused tests to verify RED**

Run: `flutter test test/features/members/member_controller_test.dart test/app/ui_rules_test.dart test/app/compact_layout_test.dart test/data/supabase_row_codec_test.dart test/data/supabase_member_remote_data_source_test.dart`

Expected: failures for missing controller APIs, widgets, and remote field.

- [ ] **Step 5: Implement controller and Material selectors**

Track `_pendingGender`, expose a getter/setter, accept optional gender in `addMember`, reset it in `clearPendingMember`, restore it from workspace, and update draft gender through `updateGender`.

Add `DropdownButtonFormField<MemberGender>` to the new-member row and compact keyed `DropdownButton<MemberGender>` controls to member cards. Keep score controls and validation unchanged.

Update `TeamMakerApp` to pass `pendingMemberGender` between `WorkspaceState` and `MemberController` during restore/persist.

- [ ] **Step 6: Implement member row synchronization**

Add `gender: member.gender.storageValue` to `memberToRemoteRow`, decode with `MemberGender.fromStorage`, and change the Supabase select to `id,name,average,gender,deleted_at`.

- [ ] **Step 7: Run focused tests to verify GREEN**

Run the Step 4 command plus `test/app/app_flow_test.dart`.

Expected: all focused tests pass with no overflow exceptions.

- [ ] **Step 8: Commit member gender management**

```bash
git add lib/features/members/member_controller.dart lib/features/members/member_screen.dart lib/app/team_maker_app.dart lib/data/supabase/member_row_codec.dart lib/data/supabase/supabase_member_remote_data_source.dart test/features/members/member_controller_test.dart test/app/ui_rules_test.dart test/app/compact_layout_test.dart test/app/app_flow_test.dart test/data/supabase_row_codec_test.dart test/data/supabase_member_remote_data_source_test.dart
git commit -m "feat: manage and sync member gender"
```

### Task 4: Apply Handicap After Base-score Allocation

**Files:**
- Modify: `lib/domain/team_allocator.dart`
- Modify: `lib/features/team_builder/team_builder_controller.dart`
- Test: `test/domain/team_allocator_test.dart`
- Test: `test/features/team_builder/team_builder_controller_test.dart`

**Interfaces:**
- Consumes: Participant gender/effective score from Task 2 and allocation modes from Task 1.
- Produces: `TeamAllocator.allocate(..., bool applyFemaleHandicap = false)`, `TeamBuilderController.femaleHandicapEnabled`, and gender-aware `addManualTemporary`.

- [ ] **Step 1: Write failing allocator behavior tests**

Add tests asserting:

- Handicap off leaves all `handicapScore` values at 0.
- Handicap on gives 12 to every female regular/manual participant and 0 to male/automatic participants.
- A team with two female participants has a raw total exactly 24 above base.
- Average-order team membership, represented as sorted sets of participant IDs, is identical with the option off and on even when +12 would cross another participant's base score.
- Average-order automatic guest base score still equals the lowest selected base score.

- [ ] **Step 2: Write failing controller tests**

Assert the checkbox state defaults false, its setter notifies/retains the session value, saved-member gender reaches participants, a W manual guest retains W, and `buildResult` passes the enabled option without modifying draft participant handicap values.

- [ ] **Step 3: Run allocator/controller tests to verify RED**

Run: `flutter test test/domain/team_allocator_test.dart test/features/team_builder/team_builder_controller_test.dart`

Expected: failures for missing option, gender propagation, and adjusted totals.

- [ ] **Step 4: Implement post-allocation handicap application**

Add `applyFemaleHandicap` to `allocate`. Keep slot selection, score grouping, automatic guest scoring, and display sorting based on base `score`. Before building/compensating result teams, copy female non-automatic participants with `handicapScore: 12` when enabled; copy all result participants with 0 when disabled.

In the controller, copy member gender whenever regular participants are created/restored, add `femaleHandicapEnabled` with a notifying setter, extend `addManualTemporary` with optional gender, and pass the checkbox state to the allocator.

- [ ] **Step 5: Run allocator/controller tests to verify GREEN**

Run the Step 3 command.

Expected: all tests pass.

- [ ] **Step 6: Commit allocation behavior**

```bash
git add lib/domain/team_allocator.dart lib/features/team_builder/team_builder_controller.dart test/domain/team_allocator_test.dart test/features/team_builder/team_builder_controller_test.dart
git commit -m "feat: apply female handicap to team totals"
```

### Task 5: Add Guest, Builder, and Result UI

**Files:**
- Modify: `lib/features/team_builder/team_builder_screen.dart`
- Modify: `lib/features/history/team_result_content.dart`
- Test: `test/app/compact_layout_test.dart`
- Test: `test/app/ui_rules_test.dart`
- Test: `test/app/app_flow_test.dart`

**Interfaces:**
- Consumes: Controller gender/handicap APIs from Tasks 3-4 and `Participant.handicapScore` from Task 2.
- Produces: Guest gender selection, three equal builder controls, and handicap-aware result presentation.

- [ ] **Step 1: Write failing team-builder widget tests**

At 360 logical pixels, assert:

```dart
expect(modeRect.width, closeTo(buildRect.width, 1));
expect(handicapRect.width, closeTo(buildRect.width, 1));
expect(controller.femaleHandicapEnabled, isFalse);
```

Tap the `female-handicap-control` and assert the controller becomes true. Assert `tester.takeException()` is null. Open the guest dialog, select W through `temporary-gender-input`, submit, and assert the created participant is female.

- [ ] **Step 2: Write failing result widget tests**

Render a team containing two participants with `handicapScore: 12`. Assert two keyed red `+12` labels, unchanged base-score labels, a total including +24, and black styles on all participant-number keys. Include the export widget assertion because it reuses the same content.

- [ ] **Step 3: Run widget tests to verify RED**

Run: `flutter test test/app/compact_layout_test.dart test/app/ui_rules_test.dart test/app/app_flow_test.dart`

Expected: failures for missing controls, selector, labels, and colors.

- [ ] **Step 4: Implement the compact three-column builder row**

Give mode toggle, Build Teams button, and a keyed checkbox/`여성핸디` tappable row equal `Expanded` flex. Set `showSelectedIcon: false`, compact segment padding/text, and compact checkbox visual density so the row fits without changing the existing 48-pixel height.

Add a `DropdownButtonFormField<MemberGender>` to `_TemporaryMemberDialog`; default it to M and return the selected gender in `_TemporaryMemberInput`.

- [ ] **Step 5: Implement result presentation**

Change participant-number text color to black. When `handicapScore != 0`, render a red keyed `+12` immediately before the base-score text. Continue displaying `participant.score`; `team.rawScore` already contains the effective total from Task 2.

- [ ] **Step 6: Run widget tests to verify GREEN**

Run the Step 3 command.

Expected: all tests pass with no layout exceptions.

- [ ] **Step 7: Commit UI behavior**

```bash
git add lib/features/team_builder/team_builder_screen.dart lib/features/history/team_result_content.dart test/app/compact_layout_test.dart test/app/ui_rules_test.dart test/app/app_flow_test.dart
git commit -m "feat: add female handicap controls and display"
```

### Task 6: Persist Handicap in Supabase History

**Files:**
- Create: `supabase/migrations/20261009000000_add_female_handicap.sql`
- Modify: `lib/data/supabase/history_row_codec.dart`
- Modify: `lib/data/supabase/supabase_history_remote_data_source.dart`
- Test: `test/data/supabase_row_codec_test.dart`
- Create: `test/data/supabase_history_remote_data_source_test.dart`

**Interfaces:**
- Consumes: `Participant.handicapScore` and the production columns already reported by the user.
- Produces: History payload/query support for `participants.handicap` and an idempotent RPC migration.

- [ ] **Step 1: Write failing history codec tests**

Assert a female result participant emits `'handicap': 12`, remote rows reconstruct `handicapScore: 12` and female gender, missing legacy handicap reconstructs 0/M, and decoded team totals include the stored adjustment. In the new remote-data-source test, use a real `SupabaseClient` with `MockClient` to assert the participants GET query selects `handicap`.

- [ ] **Step 2: Run codec tests to verify RED**

Run: `flutter test test/data/supabase_row_codec_test.dart test/data/supabase_history_remote_data_source_test.dart`

Expected: assertion failures for the missing `handicap` mapping.

- [ ] **Step 3: Implement history mapping and query**

Add `handicap` to payload participant maps and decode `(row['handicap'] as num?)?.toInt() ?? 0`. Reconstruct gender as W only when the stored handicap is 12. Add `handicap` to the Supabase participants select list.

- [ ] **Step 4: Add the idempotent SQL migration**

The migration must:

- Add `public.member.gender smallint NOT NULL DEFAULT 0` if absent.
- Add `public.participants.handicap smallint NOT NULL DEFAULT 0` if absent.
- Replace the latest `public.save_team_record(p_record jsonb)` body, adding `handicap` to participant INSERT values and conflict UPDATE values with `coalesce((participant->>'handicap')::smallint, 0)`.
- Leave existing game score semantics, soft deletion, permissions, and all unrelated SQL unchanged.

- [ ] **Step 5: Run codec and data tests to verify GREEN**

Run: `flutter test test/data/supabase_row_codec_test.dart test/data/supabase_history_remote_data_source_test.dart test/data/sync_coordinator_test.dart test/data/sync_documents_test.dart`

Expected: all tests pass.

- [ ] **Step 6: Commit history persistence**

```bash
git add supabase/migrations/20261009000000_add_female_handicap.sql lib/data/supabase/history_row_codec.dart lib/data/supabase/supabase_history_remote_data_source.dart test/data/supabase_row_codec_test.dart test/data/supabase_history_remote_data_source_test.dart
git commit -m "feat: persist female handicap in history"
```

### Task 7: Verify, Migrate, and Deploy Production

**Files:**
- Verify: all modified production/test files
- Apply externally: `supabase/migrations/20261009000000_add_female_handicap.sql`
- Deploy through: `.github/workflows/deploy-vercel.yml`

**Interfaces:**
- Consumes: Completed commits from Tasks 1-6 and production Supabase/Vercel access.
- Produces: Migrated production database and verified Vercel production deployment.

- [ ] **Step 1: Format and inspect the complete diff**

Run: `dart format lib test`

Run: `git diff --check`

Expected: formatter completes and diff check exits 0.

- [ ] **Step 2: Run static analysis and the full Flutter suite**

Run: `flutter analyze`

Run: `flutter test`

Expected: analysis reports no issues and all tests pass.

- [ ] **Step 3: Run browser persistence verification**

Run: `dart test -p chrome test/web/browser_json_object_store_test.dart`

Expected: all browser tests pass.

- [ ] **Step 4: Build the production PWA locally**

Run: `flutter build web --release --no-web-resources-cdn --pwa-strategy=none --dart-define-from-file=config/supabase.local.json`

Expected: `Built build/web` with no compilation error. If the ignored local config is absent, use the same `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` dart-defines as the deployment workflow without printing their values.

- [ ] **Step 5: Obtain production migration confirmation**

Apply `supabase/migrations/20261009000000_add_female_handicap.sql` in the Supabase SQL Editor. If this environment has no privileged Supabase connection, stop and ask the user to apply it. Continue only after confirmation because the checked-in app will send `gender` and `handicap` immediately.

- [ ] **Step 6: Request final code review and fix all Critical/Important findings**

Use `superpowers:requesting-code-review` against the branch diff from `3d842748fc84a50993d9edeb25c4b4d95f667746` through current HEAD plus any remaining working changes. Re-run affected tests after fixes.

- [ ] **Step 7: Commit any final verification fixes**

Run: `git status --short`

If tracked changes remain, stage only task-related files and commit them as `fix: address female handicap review`.

- [ ] **Step 8: Push main and monitor Vercel deployment**

Run: `git push origin main`

Use GitHub CLI to identify and watch the `Deploy PWA to Vercel` workflow for the pushed commit. Expected: workflow concludes `success`, including analyze, Flutter tests, browser storage test, web build, and production deploy.

- [ ] **Step 9: Verify production**

Open `https://blackhole-teammaker.vercel.app` and verify an HTTP success response after the workflow completes. Report the deployed commit SHA and deployment URL.
