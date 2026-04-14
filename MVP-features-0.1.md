
**Auth & Onboarding**
- Google Sign-In via AWS Cognito
- Session persistence across app restarts
- Onboarding flow: Google sign-in → location permission → done

**Core Tracking**
- Manual start/stop commute button
- Tracelet for background GPS capture
- Auto-label direction (morning = to office, evening = to home, editable)
- Trip record: start time, end time, duration, distance, route polyline
- Edit trip details (direction label, adjust times)
- Delete trip with confirmation
- Manual entry for forgotten trips (duration + date, no GPS)

**Daily Log**
- List/calendar view of past commutes
- Tap trip to view route on map + details

**Stats & Insights**
- Weekly and monthly total commute time
- Average commute duration (separate for to-office vs to-home)
- Best and worst commute day of the week
- 4-week trend line
- Per-trip: time moving vs time stuck (speed below ~10 km/h)
- Weekly "time wasted in traffic" total

**Backend (AWS)**
- Cognito user pool with Google federation
- API Gateway REST endpoints for trip CRUD and stats
- Lambda handlers in TypeScript
- DynamoDB single table design, partitioned by user

**Data & Sync**
- Drift as local source of truth (offline-first)
- One-way sync: Drift → sync_queue → Lambda → DynamoDB
- One-time cloud restore from settings (reinstall/device switch recovery)

**UX**
- Dashboard home screen: today's trips + weekly summary card
- Dark mode (system default + manual toggle)
- Persistent notification while tracking
- Weekly summary push notification
- Tracking reminder at usual departure time