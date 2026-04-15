# Phase 3: Trip Management - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the discussion.

**Date:** 2026-04-15
**Phase:** 03-trip-management
**Mode:** discuss
**Areas discussed:** Edit surface, Direction cutoff source, Auto-label backfill scope, Manual entry UX

---

## Areas Discussed

### Edit surface
| Question | User Choice |
|----------|-------------|
| Bottom sheet vs full screen? | Modal bottom sheet (recommended) |

**Rationale:** User sees trip context while editing. No new route needed. Sets the modal sheet as the interaction pattern for Phase 3.

---

### Direction cutoff source
| Question | User Choice |
|----------|-------------|
| Hardcoded constant vs user_preferences table? | user_preferences table (recommended) |

**Rationale:** The table was designed for this. Phase 7 settings UI will work automatically when shipped — no wiring needed retroactively.

---

### Auto-label backfill scope
| Question | User Choice |
|----------|-------------|
| Backfill all unknowns at start vs new trips only? | Backfill at app start (recommended) |

**Rationale:** Clean slate. Phase 2 saved all trips as 'unknown'; backfill at startup ensures the DB is consistent before any new trip management UI appears.

---

### Manual entry UX
| Question | User Choice |
|----------|-------------|
| FAB + HH:MM text vs full screen + wheel picker? | FAB on home + HH:MM text field (recommended) |

**Rationale:** Consistent with modal sheet pattern. No new route. Simple text input is sufficient for a duration that users already know ("45 minutes" → "0:45").

---

## Corrections Made

None — all recommended options accepted.

---

## Deferred Items

- Undo delete — out of scope for Phase 3
- Evening cutoff (`evening_cutoff_hour`) column — schema exists but auto-label logic uses only morning_cutoff_hour for now; Phase 7 can expose it in settings
