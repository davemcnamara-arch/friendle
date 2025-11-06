# Friendle Backend Architecture & API Documentation

## Executive Summary

Friendle is a community coordination app that helps groups organize activities. The backend uses Supabase with Edge Functions for serverless operations, PostgreSQL for the database, and Supabase Realtime for real-time features.

**Technology Stack:**
- Backend: Supabase Edge Functions (Deno/TypeScript)
- Database: PostgreSQL (Supabase)
- Real-time: Supabase Realtime (WebSocket channels)
- Push Notifications: OneSignal
- Storage: Supabase Storage
- Authentication: Supabase Auth (JWT)

---

## SECTION 1: EDGE FUNCTIONS (Serverless Backend APIs)

### Overview
Edge Functions are TypeScript functions that run on Deno, deployed to Supabase's serverless infrastructure. They handle background jobs, push notifications, and complex business logic.

---

### 1.1 EVENT REMINDERS (`/supabase/functions/event-reminders/index.ts`)

**Purpose:** Sends timezone-aware push notifications at 9am to remind users about events scheduled for that day

**Schedule:** Hourly via Cron Job

**Inputs:** None (cron-triggered)

**Processing Flow:**
1. Get all users with reminders enabled + OneSi gnal player IDs
2. For each user, calculate current hour in their timezone
3. Filter users currently in 9am hour (timezone-specific)
4. Query events scheduled for "today" in each user's timezone
5. Filter out muted events
6. Group reminders by user
7. Send OneSignal notifications

**Database Queries:**
- `profiles` → SELECT id, name, timezone, onesignal_player_id WHERE event_reminders_enabled=true
- `event_participants` → SELECT profile_id, events(id, scheduled_date, match_id, status, activities(name)) WHERE status='scheduled'
- `muted_chats` → SELECT id WHERE event_id=? AND profile_id=?

**Outputs:**
```typescript
{
  success: boolean,
  message: string,
  timestamp: ISO string,
  stats: {
    usersChecked: number,
    usersAt9am: number,
    eventsChecked: number,
    remindersToSend: number,
    notificationsSent: number,
    notificationsFailed: number,
    uniqueUsers: number
  },
  debug: {
    utcTime: ISO string,
    utcHour: number,
    usersAt9am: Array<{ name, timezone, hasPlayerId }>
  }
}
```

**OneSignal Integration:**
```
POST https://onesignal.com/api/v1/notifications
Authorization: Basic {ONESIGNAL_REST_API_KEY}
{
  app_id: '67c70940-dc92-4d95-9072-503b2f5d84c8',
  include_player_ids: [player_id],
  headings: { en: 'Event Today!' | 'X Events Today!' },
  contents: { en: message },
  data: { type: 'event_reminder', event_id, match_id, event_count }
}
```

---

### 1.2 SEND NOTIFICATION (`/supabase/functions/send-notification/index.ts`)

**Purpose:** Generic push notification system for multiple notification types

**Trigger:** Called from frontend via `supabase.functions.invoke('send-notification')`

**HTTP Method:** POST

**CORS:** Enabled for all origins

**Input Request Body:**
```typescript
{
  senderId: string,           // UUID of user sending the message/action
  recipientIds: string[],     // UUIDs of recipient users
  message: string,            // Message content
  activityName?: string,      // Activity/circle name for context
  chatType?: 'match' | 'event' | 'circle',
  chatId?: string,           // match_id, event_id, or circle_id
  notificationType: 'new_match' | 'event_join' | 'event_created' | 'chat_message' | 'match_join'
}
```

**Processing Logic:**
1. Validate required fields
2. Map notification type to user preference field
3. Get sender profile (for name)
4. Query eligible recipients:
   - In recipientIds list
   - Have onesignal_player_id (push enabled)
   - Have preference enabled (notify_new_matches, notify_chat_messages, etc.)
5. Filter out muted chats
6. Filter out users who blocked sender (blocked_users table)
7. Remove null player IDs
8. Build notification content based on type
9. Send via OneSignal API
10. Return success/failure

**Database Queries:**
```sql
-- Get sender name
SELECT name FROM profiles WHERE id = senderId

-- Get eligible recipients
SELECT id, name, onesignal_player_id FROM profiles
WHERE id IN (recipientIds)
  AND onesignal_player_id IS NOT NULL
  AND {preference_field} = true

-- Check muted chats
SELECT profile_id FROM muted_chats
WHERE profile_id IN (recipientIds)
  AND {match_id | event_id | circle_id} = chatId

-- Check blocked users
SELECT blocker_id FROM blocked_users
WHERE blocked_id = senderId
```

**Preference Field Mapping:**
- `new_match` → `notify_new_matches`
- `event_join` → `notify_event_joins`
- `event_created` → `notify_event_joins`
- `chat_message` → `notify_chat_messages`
- `match_join` → `notify_new_matches`

**Notification Content by Type:**
```
new_match:
  Heading: "{activityName}!"
  Body: "{senderName} just joined your match!"

match_join:
  Heading: "{activityName}!"
  Body: "{senderName} joined your match!"

event_join:
  Heading: "{activityName}!"
  Body: "{senderName} is joining your event!"

event_created:
  Heading: "{activityName}!"
  Body: "{message}" (formatted date from frontend)

chat_message:
  Heading: "{activityName}"
  Body: "{senderName}: {message}"
```

**Response:**
```typescript
{
  success: boolean,
  message: string,
  sent: number,              // Actual recipients notified
  totalRecipients: number,   // Original request count
  oneSignalId?: string       // OneSignal notification ID
}
```

**Error Responses:**
- 400: Missing required fields
- 400: Invalid notification type
- 500: Database query failed
- 500: OneSignal API failed

---

### 1.3 INACTIVITY CLEANUP (`/supabase/functions/inactivity-cleanup/index.ts`)

**Purpose:** Two-phase inactivity management:
- Phase 1 (Day 5): Send "Still interested?" warning notifications
- Phase 2 (Day 7): Auto-remove inactive participants (unless they have upcoming events)

**Schedule:** Daily via Cron Job

**Inputs:** None (cron-triggered)

**Phase 1 Logic (Day 5 Warnings):**
1. Query participants inactive for 5+ days (last_interaction_at <= 5 days ago)
2. Filter for:
   - Have onesignal_player_id (push enabled)
   - notify_inactivity_warnings = true
3. Check for existing pending warnings (don't re-warn)
4. Batch send OneSignal notifications (max 2000 at a time)
5. Insert warning records into inactivity_warnings table with status='pending'

**Phase 2 Logic (Day 7 Removal):**
1. Query participants inactive for 7+ days
2. Check for pending warnings
3. For each pending participant:
   - Check for upcoming events (scheduled_date >= now, status='scheduled')
   - If NO upcoming events → remove from match
   - If HAS upcoming events → keep in match (skip removal)
4. Update warning status to 'removed'
5. Cleanup old warnings (older than 30 days, status='resolved'|'removed')

**Database Queries:**
```sql
-- Phase 1: Day 5 inactive participants
SELECT match_id, profile_id, last_interaction_at,
       profiles(id, name, onesignal_player_id, notify_inactivity_warnings)
FROM match_participants
WHERE last_interaction_at <= now() - INTERVAL 5 day
  AND profiles.onesignal_player_id IS NOT NULL
  AND profiles.notify_inactivity_warnings = true

-- Check existing warnings
SELECT match_id, profile_id FROM inactivity_warnings
WHERE status = 'pending'

-- Phase 2: Day 7 participants
SELECT match_id, profile_id, matches(id, activity_id, circle_id)
FROM match_participants
WHERE last_interaction_at <= now() - INTERVAL 7 day

-- Check for upcoming events
SELECT id FROM events
WHERE match_id = ? AND profile_id IN (event_participants)
  AND scheduled_date >= now()
  AND status = 'scheduled'

-- Remove participant
DELETE FROM match_participants
WHERE match_id = ? AND profile_id = ?

-- Update warning status
UPDATE inactivity_warnings
SET status = 'removed'
WHERE match_id = ? AND profile_id = ? AND status = 'pending'
```

**Response:**
```typescript
{
  success: boolean,
  message: string,
  timestamp: ISO string
}
```

---

### 1.4 STAY INTERESTED (`/supabase/functions/stay-interested/index.ts`)

**Purpose:** Endpoint called when user taps "Still interested?" button in notification or UI

**Trigger:** Frontend action

**HTTP Method:** POST

**CORS:** Enabled

**Authentication:** Requires valid JWT in Authorization header

**Input Request Body:**
```typescript
{
  matchId: string,
  profileId: string
}
```

**Security Checks:**
1. Verify Authorization header present
2. Extract JWT and authenticate
3. Verify user ID matches profileId (user can only update own status)

**Operations:**
1. Update match_participants.last_interaction_at = NOW()
2. Update any pending inactivity_warnings for this match/profile to status='resolved'

**Database Updates:**
```sql
UPDATE match_participants
SET last_interaction_at = NOW()
WHERE match_id = ? AND profile_id = ?

UPDATE inactivity_warnings
SET status = 'resolved'
WHERE match_id = ? AND profile_id = ? AND status = 'pending'
```

**Response:**
```typescript
{
  success: boolean,
  message: string
}
```

**Error Responses:**
- 400: Missing matchId or profileId
- 401: Missing Authorization header
- 401: Invalid/expired JWT
- 403: User ID doesn't match profileId (unauthorized)
- 500: Database update failed

---

### 1.5 SEND CRITICAL MASS NOTIFICATION (`/supabase/functions/send-critical-mass-notification/index.ts`)

**Purpose:** Send notifications at activity interest thresholds (4 and 8 interested users) to create network effects

**Trigger:** Called from frontend when threshold is crossed

**HTTP Method:** POST

**CORS:** Enabled

**Input Request Body:**
```typescript
{
  matchId: string,
  threshold: 4 | 8
}
```

**Processing Logic:**
1. Validate threshold is 4 or 8
2. Get match details + check if notification already sent for this threshold
3. If already sent → return early (idempotent)
4. If threshold=8 AND threshold=4 sent <30 minutes ago → skip (anti-spam)
5. Query interested users (preferences.selected=true for activity+circle)
6. Query match participants (who already joined)
7. Filter to interested but not yet joined
8. Query eligible users:
   - In filtered list
   - Have onesignal_player_id
   - Have notify_at_4 or notify_at_8 = true
9. Filter out quiet hours (0-7am local time)
10. Send OneSignal notifications with buttons
11. Update matches.notified_at_4 or notified_at_8 timestamp

**Database Queries:**
```sql
-- Get match with activity/circle names
SELECT id, activity_id, circle_id, notified_at_4, notified_at_8,
       activities(name), circles(name)
FROM matches WHERE id = ?

-- Get interested users
SELECT profile_id FROM preferences
WHERE circle_id = ? AND activity_id = ? AND selected = true

-- Get match participants
SELECT profile_id FROM match_participants WHERE match_id = ?

-- Get eligible users
SELECT id, name, onesignal_player_id, timezone
FROM profiles
WHERE id IN (interested but not joined)
  AND onesignal_player_id IS NOT NULL
  AND notify_at_4 = true (or notify_at_8 = true)

-- Mark notification sent
UPDATE matches
SET notified_at_4 = NOW() (or notified_at_8)
WHERE id = ?
```

**OneSignal Payload:**
```typescript
{
  app_id: '67c70940-dc92-4d95-9072-503b2f5d84c8',
  include_player_ids: [player_ids],
  headings: { en: threshold === 4 ? '{activity} crew forming!' : '{activity} is really happening!' },
  contents: { en: 'X interested, Y in chat' },
  data: {
    type: 'critical_mass',
    matchId, activityId, circleId, threshold,
    chatType: 'match', chatId: matchId
  },
  buttons: [
    { id: 'join', text: 'Join Match' },
    { id: 'dismiss', text: 'Not Now' }
  ]
}
```

**Response:**
```typescript
{
  success: boolean,
  message: string,
  sent: number,
  threshold: number,
  interestedCount: number,
  joinedCount: number,
  oneSignalId: string
}
```

---

### 1.6 SEND REPORT ALERT (`/supabase/functions/send-report-alert/index.ts`)

**Purpose:** Send email to admin when new report is created (triggered via database webhook)

**Trigger:** Webhook on reports table INSERT

**HTTP Method:** POST

**Input from Webhook:**
```typescript
{
  record: {
    id: string,
    reporter_id: string,
    reported_type: 'user' | 'match' | 'event' | 'circle',
    reported_id: string,
    reason_category: string,
    reason_details?: string,
    status: string,
    created_at: ISO string
  }
}
```

**Processing:**
1. Get reporter profile (name, email)
2. Get context about reported item (user name or type/ID)
3. Build formatted email with:
   - Report ID and timestamp
   - Reporter info
   - Reported content details
   - Reason category and details
   - Direct SQL query for admin review
   - SQL snippet to update report status
4. Send via Resend email API
5. Return success or log-only (if email service not configured)

**Database Queries:**
```sql
-- Get reporter
SELECT name, email FROM profiles WHERE id = ?

-- Get reported user details
SELECT name FROM profiles WHERE id = ? AND reported_type = 'user'
```

**Email Service:** Resend API
```
POST https://api.resend.com/emails
Authorization: Bearer {RESEND_API_KEY}
{
  from: 'Friendle Reports <onboarding@resend.dev>',
  to: [ADMIN_EMAIL],
  subject: '🚨 New Report: {reason_category}',
  text: formatted_body
}
```

**Response:**
```typescript
{
  success: boolean,
  message: string,
  emailId?: string
}
```

---

## SECTION 2: FRONTEND DATABASE OPERATIONS

### Overview
The frontend uses Supabase JavaScript client to perform CRUD operations on all tables. All queries respect Row Level Security (RLS) policies.

---

### 2.1 DATABASE TABLES & SCHEMA

**Tables (21 total):**

```
CORE ENTITIES:
- profiles (user accounts with settings)
- circles (friend groups)
- circle_members (membership records)
- activities (predefined or custom activities)
- preferences (user's activity preferences per circle)

MATCHES & EVENTS:
- matches (activity + circle combinations)
- match_participants (who joined the match)
- match_messages (chat in match)
- events (scheduled gatherings)
- event_participants (who joined the event)
- event_messages (chat in event)

CIRCLES:
- circle_messages (group chat)
- circle_activities (activity availability by day)

FEATURES:
- muted_chats (muted matches/events/circles)
- blocked_users (unilateral blocking)
- inactivity_warnings (track inactive participants)
- activity_availability (which activities available by day)
- reports (user-submitted reports)
- avatars (storage bucket)
- chat-photos (storage bucket)

DERIVED:
- message_reactions (emoji reactions on messages)
- completed_tutorials (user onboarding progress)
- notification_preferences (push notification settings)
```

### 2.2 KEY OPERATION: Creating a Match (FINDING MATCHES)

**Frontend Function:** `async findMatches(circleId)`

**Flow:**
1. Load user's activity preferences for circle
2. For each liked activity:
   a. Check if match already exists (circle_id + activity_id)
   b. If not → Create new match
   c. Get all interested users (preferences.selected=true)
   d. Get match chat participants
   e. Determine if current user in chat
3. Return array of matches with metadata

**Database Operations:**
```typescript
// 1. Load preferences
SELECT 'profile_id' FROM preferences
WHERE circle_id = circleId AND selected = true
GROUP BY activity_id

// 2. Check existing match
SELECT id, circle_id, activity_id, created_at FROM matches
WHERE circle_id = circleId AND activity_id = activityId

// 3. Create match if not exists
INSERT INTO matches (circle_id, activity_id)
VALUES (circleId, activityId)
RETURNING *

// 4. Get interested users
SELECT profile_id FROM preferences
WHERE circle_id = circleId AND activity_id = activityId

// 5. Get match participants
SELECT profile_id, profiles(id, name, avatar)
FROM match_participants
WHERE match_id = matchId

// 6. Get activity details
SELECT * FROM activities WHERE id = activityId
```

**Response Object:**
```typescript
[
  {
    id: string,                    // match ID
    circleId: string,
    activity: {
      id: string,
      name: string,
      emoji: string
    },
    interestedUsers: Array<{       // who joined chat
      id: string,
      name: string,
      avatar: string
    }>,
    interestedCount: number,       // total interested (swiped right)
    inChatCount: number,           // how many joined chat
    userInChat: boolean,           // is current user in chat
    isRead: boolean
  }
]
```

---

### 2.3 KEY OPERATION: Joining Match Chat

**Frontend Function:** `async joinMatchChat(matchId)`

**Security:**
- Requires active authentication (currentUser set)
- RLS ensures user can only modify their own records

**Operations:**
1. Check if already in match_participants
2. If already joined → return true early
3. Insert into match_participants table
4. Update last_interaction_at timestamp (for inactivity tracking)

**Database Operations:**
```typescript
// Check existing
SELECT profile_id FROM match_participants
WHERE match_id = matchId AND profile_id = currentUser.id
LIMIT 1

// Insert participant
INSERT INTO match_participants (match_id, profile_id, last_interaction_at)
VALUES (matchId, currentUser.id, NOW())

// Update interaction timestamp
UPDATE match_participants
SET last_interaction_at = NOW()
WHERE match_id = matchId AND profile_id = currentUser.id
```

**Side Effects After Join:**
- Send "match_join" notification to other participants
- Auto-add user to upcoming events in this match
- Check critical mass thresholds (4 & 8 interested users)
- Load match chat

---

### 2.4 KEY OPERATION: Sending a Message

**Frontend Function:** `async window.sendMessage()`

**Context:** Determines chat type from current page (event, match, or circle)

**Steps:**

**STEP 1: Insert Message**
Varies by chat type:

*Match Chat:*
```typescript
INSERT INTO match_messages (match_id, sender_id, content)
VALUES (matchId, currentUser.id, messageContent)
RETURNING *, sender:profiles(id, name, avatar)
```

*Event Chat:*
```typescript
INSERT INTO event_messages (event_id, sender_id, content)
VALUES (eventId, currentUser.id, messageContent)
RETURNING *, sender:profiles(id, name, avatar)
```

*Circle Chat:*
```typescript
INSERT INTO circle_messages (circle_id, sender_id, content)
VALUES (circleId, currentUser.id, messageContent)
RETURNING *, sender:profiles(id, name, avatar)
```

**STEP 2: Broadcast via Supabase Realtime**
Send broadcast message to all subscribers:

```typescript
channel = supabase.channel(`{chat_type}_${chatId}`)
await channel.send({
  type: 'broadcast',
  event: 'new_general_message' | 'new_circle_message' | 'new_message',
  payload: {
    id, sender_id, sender_name, sender_avatar, content, created_at
  }
})
```

**STEP 3: Update Inactivity Tracking** (match only)
```typescript
UPDATE match_participants
SET last_interaction_at = NOW()
WHERE match_id = matchId AND profile_id = currentUser.id
```

**STEP 4: Send Push Notifications**
1. Get recipient IDs (all participants except sender)
2. Filter out muted chats
3. Invoke Edge Function:
   ```typescript
   supabase.functions.invoke('send-notification', {
     body: {
       senderId: currentUser.id,
       recipientIds: [recipients],
       message: messageContent,
       activityName: activityName,
       chatType: context.type,
       chatId: context.id,
       notificationType: 'chat_message'
     }
   })
   ```

---

### 2.5 KEY OPERATION: Creating an Event

**Frontend Function:** `async function createEvent(e)`

**Flow:**

**STEP 1: Create Event Record**
```typescript
INSERT INTO events (
  match_id,
  activity_id,
  circle_id,
  scheduled_date,
  scheduled_time,
  location,
  notes,
  created_by,
  status
)
VALUES (
  matchId,
  match.activity_id,
  match.circle_id,
  formDate,
  formTime || null,
  formLocation || null,
  formNotes || null,
  currentUser.id,
  'scheduled'
)
RETURNING *
```

**STEP 2: Add Creator as Participant**
```typescript
INSERT INTO event_participants (event_id, profile_id, status)
VALUES (eventId, currentUser.id, 'accepted')
```

**STEP 3: Update Inactivity Tracking**
```typescript
UPDATE match_participants
SET last_interaction_at = NOW()
WHERE match_id = matchId AND profile_id = currentUser.id
```

**STEP 4: Send Event Created Notifications**
Query match participants and invoke send-notification Edge Function

**STEP 5: Auto-Add to Upcoming Events**
When a user joins a match, automatically add them to all upcoming events:
```typescript
SELECT id FROM events
WHERE match_id = matchId
  AND status = 'scheduled'
  AND scheduled_date >= TODAY

INSERT INTO event_participants (event_id, profile_id, status)
VALUES (eventId, newUserId, 'accepted')
```

---

### 2.6 KEY OPERATION: Leaving a Match

**Frontend Function:** `async leaveMatchChat(matchId)`

**Operation:**
```typescript
DELETE FROM match_participants
WHERE match_id = matchId AND profile_id = currentUser.id
```

---

### 2.7 Profile Picture Upload

**Frontend Function:** `async window.uploadProfilePicture(event)`

**Security Validations:**
1. Rate limiting: Max 3 uploads/minute
2. File extension whitelist: jpg, jpeg, png, webp only
3. MIME type validation (must match extension)
4. File size: Max 5MB
5. Image dimensions: 10-4096 pixels

**Storage Operations:**
1. Delete old avatar from storage bucket (if exists)
2. Upload new file to `avatars/{userId}/avatar.{ext}`
3. Get public URL
4. Update profile with new URL

```typescript
// Delete old avatar
const { data: existingFiles } = supabase.storage
  .from('avatars')
  .list(currentUser.id)
// Then remove each file

// Upload new avatar
supabase.storage
  .from('avatars')
  .upload(fileName, file, { cacheControl: '3600', upsert: true })

// Get public URL
const { data: urlData } = supabase.storage
  .from('avatars')
  .getPublicUrl(fileName)

// Update profile
UPDATE profiles SET avatar = publicUrl WHERE id = currentUser.id
```

---

### 2.8 Message Reactions

**Add Reaction:**
```typescript
INSERT INTO message_reactions (message_id, sender_id, emoji, message_type)
VALUES (messageId, currentUser.id, emoji, 'match' | 'event' | 'circle')
ON CONFLICT (message_id, sender_id, emoji) DO NOTHING
```

**Get Reactions:**
```typescript
SELECT emoji, COUNT(*) as count
FROM message_reactions
WHERE message_id = messageId AND message_type = type
GROUP BY emoji
```

**Broadcast Reaction Change:**
```typescript
channel.send({
  type: 'broadcast',
  event: 'reaction_changed',
  payload: { messageId, emoji, count }
})
```

---

## SECTION 3: REAL-TIME SUBSCRIPTIONS

### 3.1 Subscription Architecture

Friendle uses **Supabase Realtime** (WebSocket) with broadcast channels for real-time message delivery.

**Channel Naming Convention:**
- Match chat: `match_chat_{matchId}`
- Event chat: `event_{eventId}`
- Circle chat: `circle_chat_{circleId}`

### 3.2 Match Chat Subscription

**Setup Function:** `async setupMatchChatSubscription(matchId)`

```typescript
const channel = supabase
  .channel(`match_chat_${matchId}`)
  .on('broadcast', { event: 'new_general_message' }, (payload) => {
    // Append to UI, skip if own message
    appendMessage(payload.payload)
    updateNotificationBadge()
  })
  .on('broadcast', { event: 'message_edited' }, (payload) => {
    // Reload all messages
    loadAndDisplayGeneralMessages(matchId)
  })
  .on('broadcast', { event: 'message_deleted' }, (payload) => {
    // Reload all messages
    loadAndDisplayGeneralMessages(matchId)
  })
  .on('broadcast', { event: 'reaction_changed' }, (payload) => {
    // Update reaction display
    updateReactionDisplay(payload.messageId, 'match')
  })
  .subscribe()

allActiveSubscriptions.push(channel)
```

**Broadcast Events:**
- `new_general_message`: New message posted
- `message_edited`: Message content updated
- `message_deleted`: Message removed
- `reaction_changed`: Emoji reaction added/changed

**Payload Format (new_general_message):**
```typescript
{
  id: string,
  sender_id: string,
  sender_name: string,
  sender_avatar: string,
  content: string,
  created_at: ISO string,
  match_id: string
}
```

### 3.3 Event Chat Subscription

Similar to match chat, uses `event_{eventId}` channel.

**Broadcast Events:**
- `new_message`: New event message
- `message_edited`: Message updated
- `message_deleted`: Message removed
- `reaction_changed`: Reaction updated

### 3.4 Circle Chat Subscription

Uses `circle_chat_{circleId}` channel.

**Broadcast Events:**
- `new_circle_message`: New circle message
- `message_edited`: Message updated
- `message_deleted`: Message removed
- `reaction_changed`: Reaction updated

**Payload Includes:** `circle_id` field

### 3.5 Subscription Cleanup

```typescript
// Before opening new chat
if (matchMessageSubscription) {
  await supabase.removeChannel(matchMessageSubscription)
  allActiveSubscriptions.splice(index, 1)
  matchMessageSubscription = null
}
```

**On Sign Out:**
```typescript
allActiveSubscriptions.forEach(sub => {
  if (sub) supabase.removeChannel(sub)
})
```

---

## SECTION 4: AUTHENTICATION FLOW

### 4.1 Sign Up Flow

**Frontend Function:** `async window.signUp()`

**Steps:**

**1. Validation**
- Email format
- Password length (min 6 chars)
- Name provided
- Avatar selected or photo uploaded

**2. Create Auth Account**
```typescript
const { data: authData, error } = await supabase.auth.signUp({
  email: email,
  password: password
})
// Returns: { user: { id, email }, session }
```

**3. Upload Profile Picture** (if provided)
```typescript
// Upload to storage
supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.${ext}`, file, {
    cacheControl: '3600',
    upsert: true
  })

const publicUrl = supabase.storage
  .from('avatars')
  .getPublicUrl(fileName).publicUrl
```

**4. Create Profile Record**
```typescript
INSERT INTO profiles (id, name, avatar, timezone)
VALUES (
  authData.user.id,
  name,
  avatarUrl || emoji,
  DEFAULT
)
```

**5. Initialize OneSignal**
```typescript
OneSignal.Notifications.requestPermission()
const playerId = await OneSignal.User.PushSubscription.id
UPDATE profiles
SET onesignal_player_id = playerId
WHERE id = currentUser.id
```

**6. Store Session Data**
```typescript
SecureStorage.setUserId(currentUser.id)  // localStorage
SecureStorage.setSessionData(currentUser) // sessionStorage
```

**7. Load Initial Data**
- loadDefaultActivities()
- renderCircles()
- loadMatches()

### 4.2 Sign In Flow

**Frontend Function:** `async window.signIn()`

**Steps:**

**1. Authenticate**
```typescript
const { data: authData, error } = await supabase.auth.signInWithPassword({
  email: email,
  password: password
})
```

**2. Load Profile**
```typescript
SELECT * FROM profiles WHERE id = authData.user.id
```

**3. Update OneSignal Player ID**
```typescript
const playerId = await OneSignal.User.PushSubscription.id
if (playerId && playerId !== currentUser.onesignal_player_id) {
  UPDATE profiles SET onesignal_player_id = playerId
}
```

**4. Store Session & Load Data**
Same as signup steps 6-7

### 4.3 Sign Out Flow

**Frontend Function:** `async window.signOut()`

```typescript
// Cleanup subscriptions
allActiveSubscriptions.forEach(sub => {
  supabase.removeChannel(sub)
})

// Sign out
await supabase.auth.signOut()

// Clear storage
SecureStorage.clearAll()

// Navigate to welcome page
showPage('welcome')
```

### 4.4 Authentication Security

**JWT Management:**
- Stored in Supabase Auth session
- Automatically refreshed by Supabase JS client
- Passed in Authorization header for Edge Functions

**RLS (Row Level Security):**
- All tables protected with RLS policies
- Users can only read/modify their own records
- Authenticated user ID from JWT used for all checks

---

## SECTION 5: STORAGE OPERATIONS

### 5.1 Storage Buckets

**avatars:**
- Path: `{userId}/avatar.{ext}`
- Public: Yes (read-only)
- Max size: 5MB
- Allowed types: jpg, jpeg, png, webp

**chat-photos:**
- For future image sharing in chats
- Path: TBD
- Public: Yes (read-only)

### 5.2 Upload Operations

```typescript
// List files in bucket
const { data: files } = supabase.storage
  .from('avatars')
  .list(userId)

// Upload with upsert
const { error } = supabase.storage
  .from('avatars')
  .upload(path, file, {
    cacheControl: '3600',
    upsert: true
  })

// Get public URL
const { data: { publicUrl } } = supabase.storage
  .from('avatars')
  .getPublicUrl(path)

// Delete
const { error } = supabase.storage
  .from('avatars')
  .remove([path])
```

---

## SECTION 6: NOTIFICATION PREFERENCES

All stored in `profiles` table:

```
event_reminders_enabled: boolean          // 9am event reminders
notify_new_matches: boolean               // New match notifications
notify_event_joins: boolean               // Event participation
notify_chat_messages: boolean             // Chat messages
notify_inactivity_warnings: boolean       // Day 5 inactivity warning
notify_at_4: boolean                      // Critical mass 4 threshold
notify_at_8: boolean                      // Critical mass 8 threshold
onesignal_player_id: string               // OneSignal subscription ID
```

---

## SECTION 7: ERROR HANDLING & EDGE CASES

### 7.1 Common Error Patterns

**Database Constraints:**
- Duplicate key on insert → Handled with `.maybeSingle()` or ON CONFLICT
- Foreign key violations → Catch and log
- RLS violations → Silently fail (security)

**Network Errors:**
- Timeout on Edge Functions → Retry logic (frontend decides)
- OneSignal API down → Log but don't block message
- Connection lost → Queue operations in localStorage

**Validation Errors:**
- Missing required fields → Return 400 with specific error
- Invalid UUIDs → Database query fails silently
- Invalid JSON → Return 400

### 7.2 Idempotency

**Critical Mass Notifications:**
- Check if already sent before sending
- Update timestamp atomic with send

**Auto-Add to Events:**
- Ignore duplicate key errors (23505)
- Safe to retry

---

## SECTION 8: PERFORMANCE CONSIDERATIONS

### 8.1 Database Optimization

**Indexes:**
- profiles(id) - Primary key
- match_participants(match_id, profile_id) - Composite
- match_messages(match_id, created_at DESC) - Range queries
- event_participants(event_id, profile_id) - Composite
- muted_chats(profile_id, match_id) - Mute filtering
- preferences(circle_id, activity_id, selected) - Match finding
- inactivity_warnings(match_id, profile_id, status) - Cleanup job

### 8.2 Query Pagination

**Messages:**
- Load in pages of 50
- `order('created_at', { ascending: false }).limit(50)`
- Reverse array to display oldest-to-newest
- Track loaded count in `messagePagination` object

### 8.3 Rate Limiting

**File Uploads:**
- Max 3 uploads per 60 seconds (enforced in frontend)
- Validated server-side via file size/dimensions

**API Calls:**
- No server-side rate limiting (relies on OneSignal limits)
- Critical mass notifications have 30-min anti-spam between thresholds

---

## SECTION 9: CRON JOBS

### Event Reminders
- **Schedule:** Hourly (0 * * * *)
- **Function:** event-reminders
- **Purpose:** Send 9am timezone-aware event reminders

### Inactivity Cleanup
- **Schedule:** Daily (0 3 * * *)
- **Function:** inactivity-cleanup
- **Purpose:** Day 5 warnings, Day 7 removal

---

## SECTION 10: SECURITY MEASURES

### 10.1 Input Validation

All user inputs validated:
- File uploads: Extension, MIME type, size, dimensions
- Messages: Trimmed, max length (TBD)
- Email: Format validation
- Passwords: Min 6 characters

### 10.2 Authentication & Authorization

- JWT required for Edge Functions
- RLS policies on all tables
- User ID from JWT must match target profile ID
- Service role key only used in Edge Functions

### 10.3 Data Storage

- Minimal localStorage: Only user ID
- Session data in sessionStorage
- Sensitive data (passwords) never stored client-side
- Avatar URLs are public but user IDs not exposed

### 10.4 Push Notifications

- OneSignal player IDs stored per user
- Can be disabled (onesignal_player_id = null)
- Muting system allows per-chat silence
- Blocking system prevents notifications from blocked users

---

## SECTION 11: API ENDPOINT SUMMARY TABLE

| Function | Method | Path | Auth | Rate Limit |
|----------|--------|------|------|-----------|
| Send Notification | POST | /functions/v1/send-notification | JWT | None |
| Critical Mass Notify | POST | /functions/v1/send-critical-mass-notification | None | Anti-spam |
| Stay Interested | POST | /functions/v1/stay-interested | JWT | None |
| Event Reminders | CRON | Hourly | Service Key | N/A |
| Inactivity Cleanup | CRON | Daily | Service Key | N/A |
| Send Report Alert | WEBHOOK | On INSERT reports | Service Key | N/A |

---

## SECTION 12: EXAMPLE API CALLS

### Join a Match
```javascript
// 1. Call joinMatchChat
await supabase
  .from('match_participants')
  .insert([{ match_id: 'abc-123', profile_id: currentUser.id }])

// 2. Send notification
await supabase.functions.invoke('send-notification', {
  body: {
    senderId: currentUser.id,
    recipientIds: [other_participant_id],
    message: `${currentUser.name} joined your match!`,
    chatType: 'match',
    chatId: 'abc-123',
    notificationType: 'match_join'
  }
})

// 3. Setup realtime subscription
supabase
  .channel(`match_chat_abc-123`)
  .on('broadcast', { event: 'new_general_message' }, (payload) => {
    console.log('New message:', payload)
  })
  .subscribe()
```

### Send a Message
```javascript
// 1. Insert message
const { data: message } = await supabase
  .from('match_messages')
  .insert({
    match_id: matchId,
    sender_id: currentUser.id,
    content: 'Hello everyone!'
  })
  .select('*')
  .single()

// 2. Broadcast to subscribers
supabase.channel(`match_chat_${matchId}`)
  .send({
    type: 'broadcast',
    event: 'new_general_message',
    payload: { ...message, sender_name: currentUser.name }
  })

// 3. Send push notifications
const { data: participants } = await supabase
  .from('match_participants')
  .select('profile_id')
  .eq('match_id', matchId)
  .neq('profile_id', currentUser.id)

await supabase.functions.invoke('send-notification', {
  body: {
    senderId: currentUser.id,
    recipientIds: participants.map(p => p.profile_id),
    message: 'Hello everyone!',
    notificationType: 'chat_message'
  }
})
```

### Create an Event
```javascript
// 1. Insert event
const { data: event } = await supabase
  .from('events')
  .insert({
    match_id: matchId,
    activity_id: activityId,
    circle_id: circleId,
    scheduled_date: '2024-11-20T00:00:00Z',
    scheduled_time: '18:30',
    location: 'Central Park',
    created_by: currentUser.id,
    status: 'scheduled'
  })
  .select()
  .single()

// 2. Add creator as participant
await supabase
  .from('event_participants')
  .insert({
    event_id: event.id,
    profile_id: currentUser.id,
    status: 'accepted'
  })

// 3. Send notifications to match participants
const { data: participants } = await supabase
  .from('match_participants')
  .select('profile_id')
  .eq('match_id', matchId)

await supabase.functions.invoke('send-notification', {
  body: {
    senderId: currentUser.id,
    recipientIds: participants.map(p => p.profile_id),
    message: 'Event scheduled for 11/20 at 6:30pm',
    notificationType: 'event_created'
  }
})
```

---

