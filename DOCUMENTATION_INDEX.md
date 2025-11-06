# Friendle Documentation Index

## Quick Navigation

Two comprehensive documents have been generated documenting the complete Friendle backend and frontend architecture:

### 1. BACKEND_API_DOCUMENTATION.md (1,389 lines, 35KB)
**Comprehensive technical reference for backend developers**

**Contains:**
- SECTION 1: Edge Functions (all 6 APIs documented in detail)
  - event-reminders (timezone-aware notifications)
  - send-notification (generic push system)
  - inactivity-cleanup (2-phase cleanup system)
  - stay-interested (user interaction tracking)
  - send-critical-mass-notification (momentum notifications)
  - send-report-alert (admin email alerts)

- SECTION 2: Frontend Database Operations
  - Database tables schema (21 tables total)
  - Key operation flows (creating matches, joining, messaging, events)
  - Profile picture upload with security validation
  - Message reactions system

- SECTION 3: Real-Time Subscriptions
  - Supabase Realtime architecture
  - WebSocket broadcast channels
  - Subscription lifecycle

- SECTION 4: Authentication Flow
  - Sign-up, sign-in, sign-out flows
  - JWT management
  - RLS security policies

- SECTION 5: Storage Operations
  - Supabase Storage bucket configuration
  - File upload/download operations

- SECTION 6: Notification Preferences
  - 7 notification types
  - User preference fields

- SECTION 7-12: Error handling, performance optimization, cron jobs, security, API examples

### 2. ARCHITECTURE_SUMMARY.md (586 lines, 17KB)
**Executive overview for architects and team leads**

**Contains:**
- System overview and problem statement
- Technology stack overview
- 4-layer architecture breakdown
- Core data flow patterns (3 main flows)
- The 6 Edge Functions (brief overview)
- Key database tables with schemas
- Key frontend operations (4 main)
- Real-time architecture
- Authentication & security features
- Error handling & edge cases
- Performance optimization
- Notification types & preferences
- Cron job schedules
- Code statistics
- Business logic algorithms
- Testing & monitoring

---

## What Was Analyzed

### Backend (Edge Functions) - 6 Functions
1. **event-reminders** (110 lines) - Hourly timezone-aware notifications
2. **send-notification** (320 lines) - Generic push notification system
3. **inactivity-cleanup** (280 lines) - Daily 2-phase inactivity management
4. **stay-interested** (170 lines) - User interaction timestamp updates
5. **send-critical-mass-notification** (390 lines) - Momentum notifications at thresholds
6. **send-report-alert** (210 lines) - Admin email alerts

### Frontend Code (index.html - 15,284 lines)
- 100+ async functions
- 469 database operations (SELECT, INSERT, UPDATE, DELETE)
- Real-time subscription setup and management
- Complete authentication flows
- Message sending with notifications
- Event creation and management
- File upload with validation
- Complete UI state management

### Database (PostgreSQL)
- 21 tables analyzed
- Relationships mapped
- Key indexes identified
- RLS policies documented

---

## Key Findings

### API Endpoints (Edge Functions)
| Function | Method | Trigger | Auth |
|----------|--------|---------|------|
| event-reminders | - | Hourly cron | Service key |
| send-notification | POST | Frontend invoke | Varies |
| inactivity-cleanup | - | Daily cron | Service key |
| stay-interested | POST | User action | JWT required |
| send-critical-mass-notification | POST | Frontend invoke | Optional |
| send-report-alert | POST | Webhook | Service key |

### Database Tables (21 Total)
**Core:** profiles, circles, circle_members, activities, preferences
**Coordination:** matches, match_participants, events, event_participants
**Messaging:** match_messages, event_messages, circle_messages, message_reactions
**Features:** muted_chats, blocked_users, inactivity_warnings, reports
**System:** activity_availability, completed_tutorials, notification_preferences, avatars (storage), chat-photos (storage)

### Real-Time Implementation
- **Technology:** Supabase Realtime (WebSocket)
- **Pattern:** Broadcast channels
- **Channel Names:** `match_chat_{id}`, `event_{id}`, `circle_chat_{id}`
- **Broadcast Events:** new_message, message_edited, message_deleted, reaction_changed

### Notification System
- **Types:** 7 different notification types (event reminders, match joins, events, messages, inactivity warnings, critical mass 4, critical mass 8)
- **Delivery:** OneSignal API
- **Preferences:** 7 user preference fields in profiles table
- **Features:** Muting, blocking, quiet hours (0-7am), timezone-aware scheduling

### Security Features
- JWT authentication on Edge Functions
- RLS policies on all tables
- File upload validation (extension, MIME type, size, dimensions)
- Rate limiting (3 file uploads/minute)
- Secure storage (minimal localStorage, session data in sessionStorage)
- User blocking system (unilateral)

### Key Algorithms
1. **Activity Matching:** Checks/creates match for (circle, activity), counts interested users
2. **Inactivity Tracking:** 5-day warning, 7-day removal (unless upcoming events)
3. **Critical Mass:** Notifications at 4 and 8 interested users (anti-spam 30-min gap)
4. **Auto-Add Events:** When joining match, add to all scheduled events in that match

---

## Architecture Insights

### Data Flow: Creating a Match (Joining)
```
User joins match chat
  → Insert into match_participants
  → Update last_interaction_at
  → Auto-add to upcoming events in match
  → Check if critical mass threshold (4 or 8) crossed
  → Send notifications to other participants
  → Setup real-time subscriptions
```

### Data Flow: Sending a Message
```
User sends message in chat
  → Insert into match_messages/event_messages/circle_messages table
  → Broadcast via Supabase Realtime channel
  → Get eligible recipients (filter muted chats, blocked users)
  → Invoke send-notification Edge Function
  → Update inactivity timestamp (for day 5-7 cleanup)
```

### Data Flow: Inactivity Cleanup
```
Day 5: No interaction detected
  → Send "Still interested?" push notification
  → Record in inactivity_warnings table
  → User can tap to resolve warning

Day 7: Still no interaction
  → Check for upcoming events
  → If no events → Remove from match
  → If has events → Keep in match
  → Update warning status to 'removed'
```

---

## Statistics

| Metric | Value |
|--------|-------|
| Total Documentation Lines | 1,975 |
| Frontend Code Lines | 15,284 |
| Backend Code Lines | ~1,500 |
| Total Code Analyzed | ~17,000+ |
| Edge Functions | 6 |
| Database Tables | 21 |
| API Endpoints Documented | 6 |
| Real-time Channels | 3 types |
| Notification Types | 7 |
| Key Operations Documented | 8+ |

---

## Recommended Reading Order

### For Backend Developers
1. Start with **ARCHITECTURE_SUMMARY.md** (15 min read) for overview
2. Read **BACKEND_API_DOCUMENTATION.md** Section 1 (Edge Functions) for API specs
3. Read Section 2 (Frontend Database Operations) to understand database queries
4. Read Section 3-5 (Real-time, Auth, Storage) for integration points

### For Frontend Developers
1. Start with **ARCHITECTURE_SUMMARY.md** for system overview
2. Read **BACKEND_API_DOCUMENTATION.md** Section 2 (Database Operations)
3. Read Section 3 (Real-time subscriptions)
4. Read Section 4 (Authentication)
5. Reference Section 12 (Example API Calls)

### For Product Managers
1. Read **ARCHITECTURE_SUMMARY.md** completely
2. Focus on "Core Data Flow Patterns" section
3. Review "The 6 Edge Functions" section
4. Check "Notification Types & Preferences"

### For DevOps/Infra
1. Read **ARCHITECTURE_SUMMARY.md** "Deployment & Configuration"
2. Read **BACKEND_API_DOCUMENTATION.md** "Error Handling & Edge Cases"
3. Read "Performance Considerations"
4. Check "Cron Jobs" section

---

## Database Query Reference

All database operations are documented in Section 2 of BACKEND_API_DOCUMENTATION.md:

- **2.2:** Creating/Finding Matches (~6 queries)
- **2.3:** Joining Match Chat (~3 queries)
- **2.4:** Sending Messages (~4-5 queries per message type + notifications)
- **2.5:** Creating Events (~5 queries + notifications)
- **2.6:** Leaving Match (~1 query)
- **2.7:** Profile Picture Upload (~4 storage operations + 1 DB update)
- **2.8:** Message Reactions (~3 queries)

Total: **469 database operations** identified and analyzed in frontend code.

---

## API Endpoint Specifications

Complete specifications available in BACKEND_API_DOCUMENTATION.md:

### HTTP Endpoints
- POST `/functions/v1/send-notification` - Generic notification system
- POST `/functions/v1/send-critical-mass-notification` - Momentum notifications
- POST `/functions/v1/stay-interested` - User interaction tracking

### Cron Triggered
- `event-reminders` - Hourly (0 * * * *)
- `inactivity-cleanup` - Daily (0 3 * * *)

### Webhook Triggered
- `send-report-alert` - On reports table INSERT

See BACKEND_API_DOCUMENTATION.md sections 1.1-1.6 for complete specifications including inputs, outputs, database queries, and error handling.

---

## Authentication & Security Details

### JWT Flow
- Frontend: Supabase Auth handles JWT creation/refresh
- Backend: Edge Functions receive JWT in Authorization header
- Verification: Extract user ID from JWT, validate matches profileId

### RLS Policies
- All tables protected with row-level security
- Users can only read/modify their own records
- Service role key used for background jobs that modify data

### File Upload Security
- Extension whitelist: jpg, jpeg, png, webp
- MIME type validation
- Size limit: 5MB
- Dimension limits: 10-4096 pixels
- Rate limiting: 3 uploads per 60 seconds
- All validations happen before upload

---

## Cron Job Details

### Event Reminders (Hourly)
- **Schedule:** 0 * * * * (every hour)
- **Timezone:** User's local timezone
- **Logic:** Send 9am reminders for events scheduled "today"
- **Duration:** 10-30 seconds depending on user count
- **Output:** Detailed stats and debug info

### Inactivity Cleanup (Daily)
- **Schedule:** 0 3 * * * (daily at 3am UTC)
- **Phase 1:** Day 5 - Send warning notifications
- **Phase 2:** Day 7 - Auto-remove unless upcoming events
- **Cleanup:** Delete warnings > 30 days old
- **Database Impact:** Query optimization important

---

## Testing Checklist

From documentation, here are key items to test:

- [ ] Timezone calculation for event reminders (multiple timezones)
- [ ] Inactivity warnings (Day 5 notification)
- [ ] Inactivity removal (Day 7, unless upcoming events)
- [ ] Critical mass notifications (4 and 8 user thresholds)
- [ ] Muted chats (should not receive notifications)
- [ ] Blocked users (should not send/receive notifications)
- [ ] File upload validation (size, dimensions, extensions)
- [ ] Auto-add to events (when joining match)
- [ ] Real-time message delivery (latency < 1 second)
- [ ] RLS policies (users can't access other users' data)

---

## File Locations

All source files analyzed:
- `/home/user/friendle/index.html` - 15,284 lines (frontend + single page app)
- `/home/user/friendle/supabase/functions/event-reminders/index.ts`
- `/home/user/friendle/supabase/functions/send-notification/index.ts`
- `/home/user/friendle/supabase/functions/inactivity-cleanup/index.ts`
- `/home/user/friendle/supabase/functions/stay-interested/index.ts`
- `/home/user/friendle/supabase/functions/send-critical-mass-notification/index.ts`
- `/home/user/friendle/supabase/functions/send-report-alert/index.ts`

Generated documentation:
- `/home/user/friendle/BACKEND_API_DOCUMENTATION.md` (comprehensive, 1,389 lines)
- `/home/user/friendle/ARCHITECTURE_SUMMARY.md` (overview, 586 lines)
- `/home/user/friendle/DOCUMENTATION_INDEX.md` (this file)

---

## Questions This Documentation Answers

**What are all the API endpoints?**
→ Section 1 of BACKEND_API_DOCUMENTATION.md (6 Edge Functions detailed)

**How does the database schema work?**
→ Section 2.1 of BACKEND_API_DOCUMENTATION.md (21 tables)

**What queries are made for each operation?**
→ Sections 2.2-2.8 of BACKEND_API_DOCUMENTATION.md (8 key operations)

**How does real-time messaging work?**
→ Section 3 of BACKEND_API_DOCUMENTATION.md

**What's the authentication flow?**
→ Section 4 of BACKEND_API_DOCUMENTATION.md

**How are files stored and uploaded?**
→ Section 5 of BACKEND_API_DOCUMENTATION.md

**What notification types exist?**
→ Section 6 of BACKEND_API_DOCUMENTATION.md

**What are the security measures?**
→ Section 10 of BACKEND_API_DOCUMENTATION.md

**What are example API calls?**
→ Section 12 of BACKEND_API_DOCUMENTATION.md

**What's the complete architecture?**
→ ARCHITECTURE_SUMMARY.md (full overview)

---

## Next Steps for Backend Development

Based on this documentation, a backend developer should:

1. **Understand the Architecture** - Read ARCHITECTURE_SUMMARY.md (15 min)
2. **Review Edge Functions** - Read Section 1 of BACKEND_API_DOCUMENTATION.md (30 min)
3. **Study Database Queries** - Read Section 2 of BACKEND_API_DOCUMENTATION.md (45 min)
4. **Review Real-time System** - Read Section 3 (15 min)
5. **Understand Security** - Read Section 10 (15 min)
6. **Test Your Endpoint** - Use Section 12 examples (varies)

**Total onboarding time:** ~2 hours to understand the full system

---

## Document Maintenance

These documents were generated on **2024-11-06** by analyzing:
- 6 Edge Function files (TypeScript/Deno)
- 1 Frontend HTML file (15,284 lines)
- 1 Database migration file

To keep these documents updated:
- Regenerate after adding new Edge Functions
- Update Section 2 if new database operations added
- Update Section 6 if notification types changed
- Update Section 1 if API endpoints changed
- Review quarterly for accuracy

