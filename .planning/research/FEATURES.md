# Feature Research

**Domain:** Consumer commute tracking (GPS-based, daily commute focus)
**Researched:** 2026-04-11
**Confidence:** MEDIUM (based on training data knowledge of competitor apps like Google Maps Timeline, Waze, MileIQ, TripLog, Strava; no live web search available)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Start/stop trip recording | Core mechanic; every tracking app has this | LOW | Single button, clear state indicator (recording vs idle) |
| Background GPS tracking | Users put phone in pocket; app must keep recording | MEDIUM | Android foreground service required; battery drain is the challenge |
| Trip history list | Users need to see past trips at a glance | LOW | Chronological list with date grouping |
| Trip duration and distance | The two most basic metrics any tracker shows | LOW | Computed from GPS data at trip end |
| Route visualization on map | Users expect to see where they went | MEDIUM | Encoded polyline rendered on Google Maps or similar |
| Trip editing (direction label, times) | Mistakes happen; users need to correct data | LOW | Simple form with existing data pre-filled |
| Trip deletion with confirmation | Basic data management | LOW | Confirmation dialog, soft delete |
| Offline functionality | Commutes happen in tunnels, dead zones | MEDIUM | Drift local DB handles this; sync is separate concern |
| Dark mode | Standard mobile UX expectation in 2026 | LOW | System default + manual toggle |
| Persistent notification during tracking | Users need to know recording is active; Android requires it for foreground services | LOW | Required by Android for foreground service anyway |
| Cloud backup/restore | Users switch phones; losing all data is unacceptable | MEDIUM | One-way sync to cloud, restore on demand |
| Authentication (Google Sign-In) | Needed for cloud features; users expect frictionless social login | MEDIUM | Google Sign-In is the path of least resistance on Android |

### Differentiators (Competitive Advantage)

Features that set Commute Tracker apart from generic GPS trackers and mapping apps.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Traffic time breakdown (moving vs stuck) | Core value prop: "see how much time you waste in traffic." No consumer app does this well for commutes. Google Maps shows traffic but not your personal time-stuck stats | MEDIUM | Speed threshold (10 km/h) applied to GPS samples. Must store per-trip for fast aggregation |
| Weekly "time wasted in traffic" total | Emotionally resonant stat. Makes the invisible visible. Sharable insight | LOW | Aggregation query over time_stuck_seconds for the week |
| Direction auto-labeling (to office / to home) | Removes friction from logging. Competitors require manual tagging or location geofencing | LOW | Time-of-day heuristic with configurable cutoff. Simple and good enough |
| Best/worst commute day analysis | Actionable: helps users optimize which days to go to office (hybrid workers) | LOW | Day-of-week aggregation on duration |
| 4-week trend line | Shows commute patterns over time. Answers "is my commute getting worse?" | MEDIUM | Requires charting library (fl_chart) and rolling-window queries |
| Commute-specific stats dashboard | Unlike generic trackers (Strava = fitness, MileIQ = mileage), this is purpose-built for commute insights | MEDIUM | Dedicated stats screens with to-office vs to-home breakdowns |
| Manual trip entry for forgotten trips | Fills gaps in data when user forgets to record. Most GPS-only apps cannot backfill | LOW | Duration + date form, no GPS data, flagged as manual |
| Weekly summary push notification | Proactive insight delivery without opening app. Builds habit | MEDIUM | flutter_local_notifications, scheduled weekly |
| Tracking reminder at departure time | Reduces forgotten recordings, which is the biggest usage drop-off risk | MEDIUM | Scheduled notification at user-configured time |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create complexity, scope creep, or poor UX for this product.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic trip detection (no start/stop) | "I forget to press start" | Massive battery drain, false positives (walking to lunch detected as commute), complex geofencing logic, unreliable on Android due to doze mode. Kills v0.1 timeline | Manual start/stop + departure reminder notification. Add auto-detection in v2+ after validating core value |
| Real-time traffic data integration (Google/HERE API) | "Show me traffic conditions" | API costs per request, requires network during commute, adds complexity without matching core value (personal time tracking, not navigation). Google Maps already does this better | Use GPS speed as traffic proxy. 10 km/h threshold is sufficient for "stuck vs moving" |
| Multi-stop trip chaining | "I stop for coffee on the way" | Complicates trip model (single A-to-B becomes a graph), breaks simple duration/distance stats, UI complexity | Keep trips as simple A-to-B segments. User can record separate trips for each leg |
| Social features / leaderboards | "Compare commutes with coworkers" | Privacy concerns, server-side aggregation needed, social features require critical mass of users, distracts from personal utility | Personal-only for v0.1. Export/share a screenshot of stats if user wants |
| Two-way sync (server as source of truth) | "Edit trips from web dashboard" | Conflict resolution complexity, requires server-side business logic, breaks offline-first architecture, doubles API surface | One-way client-to-server push. Client is source of truth. Restore is pull-only |
| Detailed route playback / animation | "Show me my trip as an animation" | Complex rendering, large polyline data, marginal value for commute tracking (same route daily) | Static route on map with start/end markers. Sufficient for "did I take a different route?" |
| CO2 / environmental impact tracking | "Show my carbon footprint" | Requires vehicle type data, fuel efficiency assumptions, unreliable estimates, scope creep away from time-tracking core | Out of scope. Can add as a simple multiplier in v2+ if validated |
| Calendar integration (Google Calendar) | "Auto-detect commute from calendar events" | OAuth complexity, unreliable heuristics (not all calendar events are office days), privacy concerns | Manual start/stop is simpler and more reliable |
| Expense tracking / mileage reimbursement | "Track mileage for tax deduction" | Different domain (MileIQ owns this), requires IRS-compliant reporting, complicates trip model with cost fields | Stay focused on time/traffic insights. Users who need mileage should use MileIQ |

## Feature Dependencies

```
[Google Sign-In + Cognito Auth]
    └──requires──> [Cloud Backup/Restore]
    └──requires──> [Sync Engine]

[Background GPS Tracking (Tracelet)]
    └──requires──> [Trip Recording (start/stop)]
                       └──requires──> [Trip Processing (duration, distance, traffic)]
                                          └──requires──> [Trip History List]
                                          └──requires──> [Route Map View]
                                          └──requires──> [Stats Dashboard]

[Trip Processing]
    └──requires──> [Traffic Time Breakdown]
                       └──requires──> [Weekly Traffic Total]

[Trip History]
    └──requires──> [Trip Editing]
    └──requires──> [Trip Deletion]
    └──requires──> [Manual Trip Entry]

[Stats Dashboard]
    └──requires──> [Best/Worst Day Analysis]
    └──requires──> [4-Week Trend Line]
    └──requires──> [Direction-Split Averages]

[Drift Database]
    └──requires──> [All Features] (foundation layer)

[Notifications Service]
    └──requires──> [Weekly Summary Notification]
    └──requires──> [Tracking Reminder]
    └──requires──> [Persistent Tracking Notification]
```

### Dependency Notes

- **Auth requires Drift:** User preferences and tokens stored locally. Auth is needed before sync but not before tracking.
- **Trip Processing requires Tracelet GPS data:** Speed samples from Tracelet feed into traffic calculation. No GPS = no traffic breakdown.
- **Stats require Trip History:** Stats are aggregations over stored trips. No trips = empty stats. Stats screens should handle the empty state gracefully.
- **Sync requires Auth:** Cloud backup needs authenticated user identity (Cognito sub).
- **Manual Entry is independent of GPS:** Does not require Tracelet. Only needs date, duration, and direction.
- **Notifications are independent of Sync:** Local notifications work fully offline.

## MVP Definition

### Launch With (v0.1)

Minimum viable product -- what is needed to validate the core value proposition ("see how much time you waste commuting and in traffic").

- [x] Google Sign-In + Cognito auth -- gate for cloud features, identity
- [x] Manual start/stop GPS recording -- core mechanic
- [x] Background GPS via Tracelet -- recording must survive screen-off
- [x] Trip processing (duration, distance, route polyline) -- basic trip data
- [x] Traffic time breakdown (moving vs stuck at 10 km/h threshold) -- core differentiator
- [x] Direction auto-labeling -- reduces friction
- [x] Trip history list with calendar view -- review past commutes
- [x] Route visualization on map -- see where you went
- [x] Trip editing and deletion -- basic data management
- [x] Manual entry for forgotten trips -- fills data gaps
- [x] Dashboard with today's trips and weekly summary -- landing screen
- [x] Stats: weekly/monthly totals, averages, best/worst day, trend line, traffic totals -- core insights
- [x] One-way sync to DynamoDB -- cloud backup
- [x] Cloud restore from settings -- device switch recovery
- [x] Dark mode -- standard UX expectation
- [x] Persistent notification during tracking -- Android requirement
- [x] Drift local database (offline-first) -- foundation

### Add After Validation (v0.2 - v0.x)

Features to add once core is working and users are engaged.

- [ ] Weekly summary push notification -- when user retention data shows drop-off
- [ ] Tracking reminder at departure time -- when "forgot to record" is top complaint
- [ ] Trip export (CSV/PDF) -- when users ask for it
- [ ] Home/office location geofencing for smarter direction labeling -- when time-based heuristic proves insufficient
- [ ] Month-over-month comparison stats -- when users have 2+ months of data
- [ ] Commute cost estimation (fuel/transit fare) -- if users request financial insights
- [ ] Widget for home screen (quick start tracking) -- when daily active usage is validated

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Automatic trip detection (geofence + activity recognition) -- biggest UX improvement but highest complexity; needs proven user base
- [ ] iOS support -- expand platform after Android is stable
- [ ] Multi-device sync (two-way) -- when users want web dashboard or use multiple phones
- [ ] Route comparison ("your usual route vs today") -- when users have enough data for meaningful comparison
- [ ] Integration with calendar apps -- when hybrid work scheduling is a validated use case
- [ ] Social/team commute insights -- only if enterprise/team use case emerges

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Start/stop GPS recording | HIGH | MEDIUM | P1 |
| Traffic time breakdown | HIGH | MEDIUM | P1 |
| Trip history + map view | HIGH | MEDIUM | P1 |
| Stats dashboard | HIGH | MEDIUM | P1 |
| Direction auto-labeling | MEDIUM | LOW | P1 |
| Dashboard home screen | HIGH | LOW | P1 |
| Drift database + offline | HIGH | MEDIUM | P1 |
| Auth (Google + Cognito) | HIGH | MEDIUM | P1 |
| Trip editing/deletion | MEDIUM | LOW | P1 |
| Manual trip entry | MEDIUM | LOW | P1 |
| Dark mode | MEDIUM | LOW | P1 |
| Cloud sync (one-way) | MEDIUM | MEDIUM | P1 |
| Cloud restore | MEDIUM | MEDIUM | P1 |
| Weekly summary notification | MEDIUM | LOW | P2 |
| Tracking reminder | MEDIUM | LOW | P2 |
| Home screen widget | MEDIUM | MEDIUM | P2 |
| Trip export | LOW | LOW | P2 |
| Geofence-based labeling | MEDIUM | HIGH | P3 |
| Automatic trip detection | HIGH | HIGH | P3 |
| iOS support | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (v0.1)
- P2: Should have, add when possible (v0.2+)
- P3: Nice to have, future consideration (v2+)

## Competitor Feature Analysis

| Feature | Google Maps Timeline | Waze | MileIQ | Strava | Our Approach |
|---------|---------------------|------|--------|--------|--------------|
| Trip recording | Automatic (always-on) | During navigation only | Automatic (background) | Manual start/stop | Manual start/stop (intentional, battery-friendly) |
| Traffic insights | Real-time traffic overlay | Real-time + crowd-sourced | None | None | Personal time-stuck stats per trip and aggregated weekly |
| Commute stats | Basic (frequent trips) | None | Mileage totals only | Fitness stats | Purpose-built: duration, traffic time, trends, best/worst day |
| Route visualization | Full history on map | Turn-by-turn only | Start/end points only | Full route + elevation | Route polyline on map with trip details |
| Direction labeling | Location-based (home/work) | N/A | Auto-classify (personal/business) | N/A | Time-of-day heuristic, user-editable |
| Offline support | Partial (needs sync) | No (requires network) | Yes (background recording) | Yes (GPS recording) | Full offline-first; sync is opportunistic |
| Data ownership | Google owns your data | Waze/Google owns data | Stored on their servers | Stored on their servers | Local-first; user owns data in Drift; server is backup only |
| Cost | Free | Free | Free tier + $5.99/mo premium | Free tier + $7.99/mo | Free (self-hosted backend cost only) |

### Competitive Positioning

The key gap in the market: no consumer app focuses specifically on **personal commute time insights with traffic breakdown**. Google Maps Timeline tracks locations but does not surface "you spent 47 minutes stuck in traffic this week." Waze is for navigation, not retrospective analysis. MileIQ is for mileage reimbursement, not time insights. Strava is for fitness. Commute Tracker owns the "how bad is my commute, really?" question.

## Sources

- Training data knowledge of Google Maps Timeline, Waze, MileIQ, Strava, TripLog feature sets (MEDIUM confidence -- based on training data through early 2025, features may have changed)
- PROJECT.md and CLAUDE.md project context (HIGH confidence -- primary source)
- MVP-features-0.1.md feature list (HIGH confidence -- primary source)
- General knowledge of Android foreground service requirements and GPS tracking patterns (HIGH confidence)

**Note:** WebSearch was unavailable during this research. Competitor feature analysis is based on training data and may not reflect the most recent app updates. Recommend validating competitor features with current app store listings before finalizing roadmap.

---
*Feature research for: Consumer commute tracking (GPS-based)*
*Researched: 2026-04-11*
