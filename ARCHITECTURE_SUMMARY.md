# Friendle Application Architecture - Executive Summary

## System Overview

Friendle is a **community coordination application** that helps friend groups organize and attend activities together. The architecture is built on **Supabase** with a serverless backend model.

**Key Problem It Solves:**
- Users want to organize group activities but face coordination challenges
- The app creates "matches" when multiple people in a circle like the same activity
- Users can chat, plan events, and get notifications at strategic momentum points (4 and 8 interested users)

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | HTML5 + JavaScript (Single Page App) | 15K lines of code in index.html |
| Backend | Supabase Edge Functions (Deno/TypeScript) | 6 serverless functions for background jobs |
| Database | PostgreSQL (Supabase) | 21 tables + 2 storage buckets |
| Real-time | Supabase Realtime (WebSocket) | Instant message delivery via broadcast channels |
| Auth | Supabase Auth (JWT) | Email/password authentication |
| Push Notifications | OneSignal | Cross-platform push notifications |
| Storage | Supabase Storage | User avatars (jpg, png, webp, max 5MB) |

---

## Architecture Layers

### Layer 1: Frontend (Browser)
- Single HTML file (index.html) with embedded JavaScript
- Supabase JavaScript client for all database operations
- Real-time subscriptions for instant messaging
- OneSignal SDK for push notification handling
- No backend render server needed

### Layer 2: Edge Functions (Serverless)
- 6 TypeScript functions running on Deno
- Handle:
  - Timezone-aware reminder notifications (hourly)
  - Generic push notifications (on-demand)
  - Inactivity cleanup (daily 2-phase system)
  - Critical mass notifications (momentum at 4 & 8 users)
  - Report alerts (email to admin)
  - "Stay interested" user interaction tracking

### Layer 3: Database (PostgreSQL)
- 21 tables organized into domains:
  - **Accounts:** profiles, circles, circle_members
  - **Activities:** activities, preferences, activity_availability
  - **Coordination:** matches, match_participants, events, event_participants
  - **Messaging:** match_messages, event_messages, circle_messages, message_reactions
  - **Features:** muted_chats, blocked_users, inactivity_warnings, reports
  - **System:** avatars (storage), chat-photos (storage)

### Layer 4: External Services
- **OneSignal API:** Push notification delivery (app_id: 67c70940-dc92-4d95-9072-503b2f5d84c8)
- **Resend API:** Email notifications to admins

---

## Core Data Flow Patterns

### Pattern 1: Activity Matching
```
User swipes right on activity
  ↓
System checks if match exists for (circle, activity)
  ↓
If no → Create match, don't auto-add user
  ↓
User joins match chat → Added to all upcoming events in that match
  ↓
Others interested in same activity see user in chat
  ↓
At 4 interested → Send critical mass notification
  ↓
At 8 interested → Send bigger "momentum" notification
```

### Pattern 2: Message Broadcasting
```
User sends message
  ↓
Insert into database (match_messages/event_messages/circle_messages)
  ↓
Broadcast via Supabase Realtime channel
  ↓
All subscribers receive instantly (no polling)
  ↓
Send push notifications to offline users
  ↓
Update inactivity timestamp (for day 5-7 cleanup)
```

### Pattern 3: Inactivity Management
```
Day 5 inactive (5+ days since last interaction)
  ↓
Send "Still interested?" push notification
  ↓
If user taps → Update timestamp, resolve warning
  ↓
Day 7 inactive (still no response to warning)
  ↓
Check if upcoming events exist
  ↓
If NO events → Remove from match
  ↓
If YES events → Keep in match (preserve event access)
```

---

## The 6 Edge Functions

### 1. event-reminders
- **Schedule:** Hourly cron job
- **Purpose:** Send 9am timezone-aware event reminders
- **Key Logic:** 
  - Timezone calculation (using Intl.DateTimeFormat)
  - Only notifies users currently in 9am hour
  - Checks if event is "today" in user's timezone
  - Respects mute preferences
- **Output:** Notification stats + debug info
- **Queries:** ~4 database calls

### 2. send-notification
- **Trigger:** Frontend invokes via `supabase.functions.invoke('send-notification')`
- **Purpose:** Generic notification system with preference filtering
- **Key Logic:**
  - Maps notification type → user preference field
  - Filters out muted chats + blocked users
  - Builds context-aware message content
  - Calls OneSignal API
- **Types:** new_match, match_join, event_join, event_created, chat_message
- **Queries:** ~3-4 database calls per invocation

### 3. inactivity-cleanup
- **Schedule:** Daily at 3am UTC
- **Purpose:** Two-phase inactivity system
- **Phase 1 (Day 5):**
  - Query inactive for 5+ days
  - Send warning notification if not already warned
  - Record warning in inactivity_warnings table
- **Phase 2 (Day 7):**
  - Query inactive for 7+ days with pending warnings
  - Check for upcoming events
  - Remove if no events, keep if has events
  - Update warning status to 'removed'
- **Cleanup:** Delete old resolved/removed warnings > 30 days

### 4. stay-interested
- **Trigger:** User taps "Still interested?" button
- **Purpose:** Update interaction timestamp + resolve warnings
- **Security:** Verify user can only update own record
- **Operations:**
  - Update match_participants.last_interaction_at
  - Set inactivity_warnings.status = 'resolved'

### 5. send-critical-mass-notification
- **Trigger:** Frontend detects 4 or 8 interested threshold crossed
- **Purpose:** Momentum notifications at key thresholds
- **Key Logic:**
  - Check if already sent (idempotent)
  - Anti-spam: Skip if threshold 8 sent <30 min after threshold 4
  - Filter out quiet hours (0-7am local time)
  - Send with CTA buttons (Join Match / Not Now)
  - Track notifications in matches.notified_at_4 / notified_at_8
- **Queries:** ~4-5 database calls

### 6. send-report-alert
- **Trigger:** Webhook on reports table INSERT
- **Purpose:** Email admin when user reports content
- **Operations:**
  - Fetch reporter + reported content details
  - Build formatted email with actionable SQL
  - Send via Resend API
  - Return success or log-only if service unavailable

---

## Key Database Tables

### profiles
```
id (UUID, PK)
name (text)
avatar (text - emoji or URL)
email (text)
timezone (text)
onesignal_player_id (text)
event_reminders_enabled (boolean)
notify_new_matches (boolean)
notify_event_joins (boolean)
notify_chat_messages (boolean)
notify_inactivity_warnings (boolean)
notify_at_4 (boolean)
notify_at_8 (boolean)
created_at (timestamp)
```

### matches
```
id (UUID, PK)
circle_id (UUID, FK)
activity_id (UUID, FK)
notified_at_4 (timestamp) - When 4-user notification sent
notified_at_8 (timestamp) - When 8-user notification sent
created_at (timestamp)
```

### match_participants
```
match_id (UUID, FK)
profile_id (UUID, FK)
last_interaction_at (timestamp) - For inactivity tracking
created_at (timestamp)
PRIMARY KEY (match_id, profile_id)
```

### events
```
id (UUID, PK)
match_id (UUID, FK)
activity_id (UUID, FK)
circle_id (UUID, FK)
scheduled_date (timestamp)
scheduled_time (time)
location (text)
notes (text)
created_by (UUID, FK)
status (enum: 'scheduled', 'completed', 'cancelled')
created_at (timestamp)
```

### inactivity_warnings
```
id (UUID, PK)
match_id (UUID, FK)
profile_id (UUID, FK)
status (enum: 'pending', 'resolved', 'removed')
created_at (timestamp)
UNIQUE (match_id, profile_id)
```

---

## Key Frontend Operations

### 1. Finding Matches
```typescript
async findMatches(circleId) {
  // Get user's liked activities
  // For each activity:
  //   - Check if match exists
  //   - Create if doesn't exist
  //   - Get interested users count
  //   - Get participants in chat
  //   - Check if user already in chat
  // Return array of match objects
}
```

### 2. Joining a Match
```typescript
async joinMatchChat(matchId) {
  // Check if already member
  // Insert into match_participants
  // Update last_interaction_at
  // Send notifications to other members
  // Auto-add to upcoming events
  // Check critical mass thresholds
}
```

### 3. Sending a Message
```typescript
async window.sendMessage() {
  // Insert into match_messages/event_messages/circle_messages
  // Broadcast via Supabase Realtime channel
  // Update last_interaction_at (inactivity tracking)
  // Get recipients and filter muted chats
  // Invoke send-notification Edge Function
}
```

### 4. Creating an Event
```typescript
async createEvent(e) {
  // Insert into events table
  // Add creator as participant
  // Update last_interaction_at
  // Send notifications to match participants
  // Auto-add new joiners to this event
}
```

---

## Real-Time Architecture

**Implementation:** Supabase Realtime (WebSocket broadcast channels)

**Channel Pattern:** `{chat_type}_{chatId}`
- Match chat: `match_chat_{matchId}`
- Event chat: `event_{eventId}`
- Circle chat: `circle_chat_{circleId}`

**Broadcast Events:**
- `new_general_message` / `new_circle_message` / `new_message`
- `message_edited`
- `message_deleted`
- `reaction_changed`

**Lifecycle:**
1. Subscribe when opening chat
2. Receive broadcasts while connected
3. Unsubscribe when closing chat
4. All subscriptions cleaned up on sign out

---

## Authentication & Security

### Sign-Up Flow
```
1. Validate input (email, password, name, avatar)
2. Call supabase.auth.signUp(email, password)
3. Upload avatar to storage (if provided)
4. Create profile record with auth user ID
5. Request OneSignal notification permission
6. Save player ID to profile
7. Store minimal session data
8. Load initial app data
```

### Security Features
- **JWT Authentication:** All Edge Functions require valid JWT
- **RLS Policies:** All tables protected, users can only access own records
- **File Upload Validation:**
  - Extension whitelist (jpg, jpeg, png, webp)
  - MIME type validation
  - File size limit (5MB)
  - Image dimension limits (10-4096 pixels)
  - Rate limiting (3 uploads/minute)
- **Secure Storage:**
  - Only user ID in localStorage
  - Session data in sessionStorage
  - Passwords never stored client-side
- **User Blocking:** Unilateral blocking prevents notifications

---

## Error Handling & Edge Cases

### Idempotency
- **Critical Mass Notifications:** Check if already sent before sending
- **Auto-Add to Events:** Ignore duplicate key errors (23505)

### Network Resilience
- If OneSignal API fails → Log but don't block message send
- If Edge Function times out → Frontend decides retry strategy
- Realtime channel loss → Auto-reconnect

### Data Consistency
- Timezone calculations use Intl.DateTimeFormat (browser API)
- Event reminders check event date in user's timezone
- No distributed transaction support (single Postgres DB)

---

## Performance Optimization

### Database
- Composite indexes on frequently filtered columns
- Pagination for message loading (50 at a time)
- Eager loading relationships in queries

### Frontend
- Single-page app (no full-page reloads)
- Lazy load activities and circles
- Debounce real-time updates
- Cache parsed activities list

### Notifications
- Batch send (max 2000 at a time)
- Anti-spam on critical mass (30-min gap between thresholds)
- Quiet hours filtering (0-7am) for push notifications
- Mute system for chat-specific silence

---

## Notification Types & Preferences

| Type | Field | Sent By | When |
|------|-------|---------|------|
| Event Reminder | event_reminders_enabled | Edge Function (hourly) | 9am timezone-specific |
| New Match | notify_new_matches | Frontend | User joins match chat |
| Event Join | notify_event_joins | Frontend | User joins event |
| Event Created | notify_event_joins | Frontend | Match owner creates event |
| Chat Message | notify_chat_messages | Frontend | Someone sends message |
| Inactivity Warning | notify_inactivity_warnings | Edge Function (daily) | Day 5 no interaction |
| Critical Mass 4 | notify_at_4 | Frontend | 4 users interested |
| Critical Mass 8 | notify_at_8 | Frontend | 8 users interested |

---

## Storage Structure

### Bucket: avatars
- **Path:** `{userId}/avatar.{ext}`
- **Public:** Yes (read-only URLs)
- **Extensions:** jpg, jpeg, png, webp
- **Max Size:** 5MB
- **Cache:** 3600s

### Bucket: chat-photos
- **Path:** TBD (for future feature)
- **Public:** Yes
- **Status:** Prepared but not yet used

---

## Cron Jobs

### Event Reminders
- **Schedule:** `0 * * * *` (hourly)
- **Function:** event-reminders
- **Duration:** ~10-30 seconds depending on user count
- **Timezone:** Works with user's local timezone

### Inactivity Cleanup
- **Schedule:** `0 3 * * *` (daily at 3am UTC)
- **Function:** inactivity-cleanup
- **Phases:**
  - Phase 1 (Day 5): Warn inactive users
  - Phase 2 (Day 7): Remove inactive users (unless upcoming events)
- **Cleanup:** Delete old warnings > 30 days

---

## Code Statistics

| Component | Lines | Files | Type |
|-----------|-------|-------|------|
| Frontend | 15,284 | 1 | HTML/JavaScript |
| Edge Functions | ~1,500 | 6 | TypeScript/Deno |
| SQL Migrations | ~1,000+ | Multiple | PostgreSQL |
| **Total** | **~17,800** | **7+** | |

---

## Key Business Logic

### Activity Matching Algorithm
```
For each circle the user is in:
  For each activity the user likes:
    If match doesn't exist:
      Create match (circle_id, activity_id)
    Count interested users (via preferences table)
    Count match participants (who joined chat)
    Determine if user in chat
    If interested=4: Send critical mass notification
    If interested=8: Send momentum notification
```

### Inactivity Tracking
```
Timeline:
  Day 0: User joins match
  Day 1-4: Active participation
  Day 5: No message/interaction → Send warning notification
  Day 6: User can tap "Stay interested"
  Day 7: If still inactive AND no pending warning → Remove from match
  Day 7+: Keep in match if upcoming events exist
  Day 30+: Delete old resolved/removed warnings
```

### Auto-Add to Events
```
When user joins match:
  Find all scheduled events in this match (scheduled_date >= today)
  Add user to all matching events with status='accepted'
  Notify user: "You've been added to X upcoming events"
```

---

## API Response Patterns

### Success Response
```json
{
  "success": true,
  "message": "Operation completed",
  "data": { ... },
  "timestamp": "2024-11-06T10:30:00Z"
}
```

### Error Response (4xx/5xx)
```json
{
  "success": false,
  "error": "Specific error message",
  "code": "ERROR_CODE",
  "timestamp": "2024-11-06T10:30:00Z"
}
```

---

## Future Considerations

### Not Yet Implemented
- Chat photo sharing (bucket prepared)
- Message editing (broadcast event prepared)
- Message deletion (broadcast event prepared)
- Message reactions (table prepared, broadcasts implemented)
- Completed tutorials tracking (table prepared)
- Notification preference UI (fields prepared)

### Scaling Considerations
- Supabase can handle 1000s of concurrent users
- Realtime channels scale to millions of subscribers
- Database indexes should be monitored as data grows
- Consider caching for activity list as it grows
- OneSignal batch sending already optimized

---

## Deployment & Configuration

### Required Environment Variables
```
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
SUPABASE_ANON_KEY
ONESIGNAL_REST_API_KEY
ADMIN_EMAIL
RESEND_API_KEY (optional)
```

### Cron Job Configuration
- Supabase → Function → Triggers
- event-reminders: Hourly
- inactivity-cleanup: Daily 3am UTC

### Webhook Configuration
- Supabase → Database → Webhooks
- reports table → INSERT → send-report-alert function

---

## Testing & Monitoring

### Monitoring Points
- OneSignal notification delivery rates
- Edge Function execution times
- Database query performance
- Realtime channel connection health
- RLS policy violations (logs)

### Manual Testing
- Timezone switching (event-reminders)
- Inactivity thresholds (manual date manipulation)
- Critical mass notifications (create test matches)
- Notification preferences (toggle and verify)

---

## Summary

Friendle is a sophisticated, real-time coordination application with:
- **Elegant real-time messaging** via Supabase Realtime
- **Smart notification system** with 7 different types
- **Intelligent inactivity management** with 5+7 day tracking
- **Momentum-based notifications** at strategic user thresholds
- **Timezone-aware scheduling** for global users
- **Comprehensive security** via RLS and validation
- **Serverless architecture** for automatic scaling

The codebase is well-organized, with clear separation between frontend (single HTML file), backend (6 Edge Functions), and database (21 tables). The system is production-ready with proper error handling, idempotency checks, and security measures throughout.

