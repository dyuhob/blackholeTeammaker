# Female Handicap Design

## Goal

Add M/W gender management and an optional female handicap to the existing
team-building flow. When enabled, each female participant receives an
independent +12 adjustment in team totals while allocation order continues to
use the participant's base score.

## User-visible behavior

### Member management

- New-member entry includes an M/W selector next to the reduced-width name
  field. The selector defaults to M.
- Every existing member row includes the same selector so gender can be
  changed without deleting and recreating the member.
- A gender edit is an unsaved roster change and is committed by the existing
  Save action.
- Pending new-member gender is restored with the pending name and score after
  an app restart. Older workspace data without gender restores as M.

### Guest entry

- The manual guest dialog includes an M/W selector that defaults to M.
- Female manual guests receive the same handicap as female saved members.
- Automatically generated guests are always treated as M and never receive a
  gender handicap.

### Team builder controls

- The second control row has three equal-width areas:
  1. Random/Average-order selection.
  2. Build Teams button.
  3. An unchecked checkbox followed by the `여성핸디` label.
- The control row remains usable at the project's tested mobile width by
  removing the segmented control's selected icon and using compact spacing.
- Female handicap defaults to unchecked whenever the app starts. Its value is
  held by the team-builder controller for the current app session but is not
  persisted in the workspace.

### Result display

- When handicap is applied, every female participant row shows a red `+12`
  immediately to the left of the participant's unchanged base score.
- Participant numbering is black in the on-screen result and exported image.
- A team's displayed raw total includes 12 points for every handicapped female
  participant. Two female participants add 24, three add 36, and so on.
- The existing team score compensation uses these adjusted raw totals. All
  other result formatting and behavior remains unchanged.

## Domain model

### Gender

Introduce `MemberGender` with the stable storage mapping:

- `male`: 0, displayed as M.
- `female`: 1, displayed as W.

`Member` stores gender and defaults missing legacy JSON to male. Equality,
copying, and JSON serialization include gender.

`Participant` also stores gender so selected members and manual guests retain
it through workspace drafts. Missing legacy JSON defaults to male.

### Applied handicap

`Participant` stores `handicapScore`, defaulting to 0 for legacy and draft
data. A participant's effective score is `score + handicapScore`.

The applied value is copied into the generated result rather than calculated
again when the result is viewed. This keeps saved history stable if a member's
gender changes later or a future build uses a different checkbox setting.

`Team.rawScore` sums participant effective scores. `Team.effectiveScore`
continues to add the existing team compensation to `rawScore`.

## Allocation flow

`TeamBuilderController` exposes `femaleHandicapEnabled`, initially false, and
passes it to `TeamAllocator.allocate`.

The allocator performs all allocation decisions using base `score`:

- Random mode preserves the current random allocation logic.
- Average-order mode groups, sorts, and distributes using base scores only.
- Average-order automatic guests still receive the lowest selected base score.

After team membership is decided, the allocator copies each female regular or
manual guest into the result with `handicapScore: 12` when the option is
enabled. Male and automatic participants retain 0. It then calculates the
existing team compensation from the adjusted team raw totals.

This sequencing prevents the handicap from changing team membership while
ensuring every total and compensation value includes it.

## Persistence and synchronization

### Local JSON

- `Member.toJson` writes gender as 0 or 1.
- `Participant.toJson` writes gender and `handicapScore`.
- Missing fields deserialize as 0, keeping existing member, workspace, and
  history JSON compatible without a schema-version change.
- `WorkspaceState` adds pending-member gender with a legacy default of M.

### Supabase members

Member row encoding maps `Member.gender` to `member.gender`. Member queries
select `gender`. Only values 0 and 1 are accepted; existing rows use 0.

### Supabase history

History payloads map the result participant's applied handicap to
`participants.handicap`. History queries select that column and reconstruct
`handicapScore`; missing legacy values use 0.

Remote history does not need to reconstruct an unapplied female gender because
the historical fact needed for display and totals is the stored applied
handicap. A row with handicap 12 is treated as female when a `Participant`
instance is reconstructed; a row with handicap 0 may safely use the male
default because history cannot be rebuilt into a new allocation.

Add an idempotent migration that:

- Adds `member.gender int2 NOT NULL DEFAULT 0` if missing.
- Adds `participants.handicap int2 NOT NULL DEFAULT 0` if missing.
- Replaces `save_team_record(jsonb)` so participant inserts and conflict
  updates write `handicap`.

The user reports both columns are already present. The migration is still
required before production deployment because it also updates the save RPC.

## UI implementation

Use Flutter's installed Material controls only:

- `DropdownButtonFormField<MemberGender>` for new members and guests.
- Compact `DropdownButton<MemberGender>` controls in existing member rows.
- The existing `SegmentedButton` remains but uses compact styling and no
  selected icon.
- A compact checkbox/label row fills the third team-builder column and makes
  the full label area tappable.

No new package or reusable form framework is introduced.

## Error handling and compatibility

- Existing score validation remains unchanged.
- Gender parsing accepts only 0 and 1. Missing local fields use 0.
- Invalid remote gender data follows the existing synchronization error path
  rather than silently becoming female.
- Existing members, participants, and history records receive no handicap.
- A failed Supabase synchronization continues to leave the local result and
  pending mutation intact under the existing offline-first behavior.

## Testing

Use test-first changes for each behavior:

- Member and participant JSON round trips, including legacy missing fields.
- Member controller add and gender update behavior.
- Workspace restoration of pending gender and participant gender.
- Member and history Supabase codecs for `gender` and `handicap`.
- Remote member/history queries and payloads include the new columns.
- Average-order membership remains identical for base scores with handicap on
  while adjusted totals add 12 per female.
- Random allocation applies the same per-female total adjustment.
- Female manual guests receive +12; automatic guests never do.
- The builder checkbox defaults off and the three controls occupy equal width.
- Member and guest gender selectors update their controllers.
- Result rows show red `+12`, totals include cumulative handicap, and
  participant numbers render black.
- Existing suite, analyzer, browser storage test, and release web build pass.

## Deployment

1. Apply the new Supabase migration to production before the app deployment.
2. Run formatting, `flutter analyze`, the complete Flutter test suite, the
   Chrome browser-storage test, and the production web build.
3. Commit the previously completed allocation-mode work and this feature.
4. Push `main` to trigger `.github/workflows/deploy-vercel.yml`.
5. Monitor the GitHub Actions deployment through completion and verify the
   production PWA URL responds successfully.

If production database migration access is unavailable to this environment,
stop before pushing the app and ask the user to apply the checked-in SQL file.
