### Phase 19: Full Trip Editing

**Goal**: Users can edit every time-based detail of a trip — start time, end time, and individual break segments — and the trip's duration and traffic stats are recomputed from the edits
**Depends on**: Phase 18 (break segments must exist), Phase 3 (existing trip edit screen)
**Requirements**: TRACK-11
**Success Criteria** (what must be TRUE):

  1. The user can edit a trip's start time and end time from the trip edit screen, and the saved trip reflects the new times
  2. The user can edit, add, or remove individual break/pause segments on a trip
  3. After any edit, the trip's total duration and moving/stuck traffic breakdown are recomputed and displayed consistently with the new times and breaks
  4. Invalid edits (e.g., end before start, breaks outside the trip window, overlapping breaks) are rejected with clear feedback and never persisted
  5. An edited trip re-enters the sync queue so the cloud backup reflects the corrected values

**Plans**: 2 plans
- [ ] 19-01-PLAN.md — schema v4 (is_edited) + pure TripEditRecompute service (active duration, proportional moving/stuck rescale, break validation, clamp/drop) + atomic full-edit editTrip write path (TDD)
- [ ] 19-02-PLAN.md — edit-sheet UI: date+time pickers, break-list editor, live recompute preview, inline validation + disabled Save, clamp/drop snackbar, "~ estimated" hint
**UI hint**: yes
