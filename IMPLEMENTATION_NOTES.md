# Remove Match Chat System - Implementation Notes

## Status: Phase 1 Complete ✅

The core functionality for the new event-based planning system has been implemented and pushed to the branch `claude/remove-match-chat-01S4N4G3VX6rFJzk4jKBh8qG`.

---

## ✅ Completed Features

### 1. Database Migration
**File:** `MIGRATION_remove_match_chat_add_event_planning.sql`

- Added `status` column to events (planning/scheduled/completed/cancelled)
- Made `scheduled_date` nullable for planning phase
- Added `proposed_timeframe` column for planning mode
- Created `polls` and `poll_votes` tables
- Added `message_type` and `poll_id` columns to `event_messages`
- Dropped match_messages, match_message_reads, match_message_reactions tables
- Removed `notifications_muted` from match_participants
- Added RLS policies for polls
- Added performance indexes

**⚠️ IMPORTANT:** Run this migration before testing!

### 2. New UI Modals (index.html lines 3067-3197)

✅ **Swipe Action Modal** - Shown after swiping right
- Options: "Plan Event" or "Stay Interested"
- Explains that "Stay Interested" watches for events without creating one

✅ **Planning Event Modal** - Lightweight event creation
- Timeframe dropdown (This weekend, Next weekend, etc.)
- Optional location field
- Optional notes field
- Creates event in `planning` status

✅ **Lock in Details Modal** - Converts planning to scheduled
- Required: Date, Location
- Optional: Time, Notes, Max Attendees
- Updates event status to `scheduled`

✅ **Create Poll Modal** - For event coordination
- Question field
- Dynamic option inputs (2-10 options)
- Sends poll as special message type

### 3. JavaScript Functions

#### Modal Handlers (lines 13142-13277)
- `openSwipeActionModal(matchId, activityName)`
- `closeSwipeActionModal()`
- `handlePlanEvent()` - Opens planning modal
- `handleStayInterested()` - Adds to match_participants only
- `openPlanningEventModal(matchId)`
- `closePlanningEventModal()`
- `openLockDetailsModal()`
- `closeLockDetailsModal()`
- `openCreatePollModal()`
- `closeCreatePollModal()`
- `addPollOption()` - Dynamically add poll options

#### Planning Event Functions (lines 13279-13423)
- `createPlanningEvent(e)` - Creates event with status='planning'
  - Posts system message about planning start
  - Opens event chat immediately
  - Sends notifications to match participants

- `lockEventDetails(e)` - Transitions to scheduled status
  - Updates all event fields
  - Posts system message about event being locked
  - Reloads event chat with new UI

#### Polling System (lines 13425-13704)
- `submitPoll(e)` - Creates poll and poll message
- `renderPollMessage(message, poll)` - Displays poll with vote counts
- `voteOnPoll(pollId, optionIndex)` - Cast/change vote
- `refreshPollDisplay(pollId)` - Updates poll after voting
- `sendSystemMessage(eventId, content)` - Posts automated messages

#### Event Chat Updates (lines 13954-14068)
- Updated `openEventChat()` to check event status
- Shows different buttons for planning vs scheduled:
  - **Planning mode:** Lock in Details button visible
  - **Scheduled mode:** Calendar and Options buttons visible
- Event details banner changes color:
  - Yellow (#fff3cd) for planning
  - Blue (#e6f7ff) for scheduled
- Displays proposed_timeframe in planning mode

#### Message Rendering (lines 14510-14541)
- Updated `appendMessage()` to check message_type
- Handles `poll` messages → calls `renderPollMessage()`
- Handles `system` messages → centered, styled display
- Regular text messages → existing behavior

#### Swipe Flow Integration (lines 15228-15292)
- Updated `showMatchNotification()` → calls `openSwipeActionModal()`
- Updated `showFirstToChoosePopup()` → calls `openSwipeActionModal()`
- Replaces old match join flow with new Plan Event / Stay Interested choice

---

## 🔄 Remaining Tasks

### 1. Remove Match Chat Functions (Safe After Testing)

The following functions are still present but unused after the new flow:
- `openMatchChatThreaded()` (line ~8783)
- `renderThreadedChat()` (line ~8946)
- `loadAndDisplayGeneralMessages()` (line ~9400)
- `setupMatchChatSubscription()` (line ~9501)
- `joinMatchChatFirst()` (line ~8656)
- `skipJoinChat()` (line ~8678)
- `markMatchAsRead()` (needs investigation - might be used elsewhere)

**Variables to remove:**
- `matchMessageSubscription`
- `currentMatchChat` (if exists)

**UI elements to hide/remove:**
- Old match notification modal (if still referenced)
- Old first-to-choose modal (if still referenced)

### 2. Update Matches Page Display Logic

**File:** index.html, `displayMatches()` function (line ~11442)

**Current behavior:**
- Shows participant count and "💬 Chat" button
- Opens match chat when clicked

**Needed changes:**
- Show event status indicator:
  - If user in match but no events: "👀 Watching for events"
  - If user in an event: Show event status (Planning / Scheduled)
- Show "+ Plan Event" button if user has no events for this match
- Display event cards below match card:
  - Planning events: Show proposed timeframe, "Open Chat" button
  - Scheduled events: Show date/time/location, "Open Chat" button
- Remove "💬 Chat" button (no more match chat)

**Suggested structure:**
```javascript
// For each match:
const userEvents = events.filter(e =>
  e.match_id === match.id &&
  userIsParticipant(e)
);

if (userEvents.length === 0) {
  // Show "Watching" indicator
  // Show "+ Plan Event" button
} else {
  userEvents.forEach(event => {
    // Render event card based on status
  });
}
```

### 3. Update Notification System

**Current:** Notifications reference match chat
**Needed:** Update to reference events only

**Files to check:**
- `/supabase/functions/send-notification/index.ts`
- `sendEventCreatedNotification()` in index.html
- `sendEventJoinNotification()` in index.html

**Changes:**
- Remove `sendMatchJoinNotification()` (if it exists)
- Update `sendEventCreatedNotification()` to notify non-participants about new events
- Ensure notification click handlers open event chat, not match chat

### 4. Broadcast Subscription Updates

**Add handler for poll updates in event chat subscription:**

```javascript
// In openEventChat, add to existing subscription:
.on('broadcast', { event: 'poll_updated' }, (payload) => {
  refreshPollDisplay(payload.payload.pollId);
})
```

---

## 🧪 Testing Checklist

### Before Removing Match Chat Code:

1. ✅ Run database migration
2. ✅ Test swipe right → Swipe Action Modal appears
3. ✅ Test "Stay Interested" → User added to match_participants
4. ✅ Test "Plan Event" → Planning Event Modal opens
5. ✅ Test creating planning event:
   - Event created with status='planning'
   - System message appears
   - Event chat opens immediately
   - Notifications sent to other match participants
6. ✅ Test planning mode UI:
   - Yellow banner shows proposed timeframe
   - "Lock in Details" button visible
   - Poll button works
7. ✅ Test creating poll:
   - Poll appears in chat
   - Voting works
   - Vote counts update
8. ✅ Test "Lock in Details":
   - Modal pre-fills existing data
   - Event transitions to 'scheduled' status
   - Blue banner shows actual date/time/location
   - System message posted
   - Calendar and Options buttons appear
9. ✅ Test event joining from Matches page (when implemented)
10. ✅ Test notifications for new events

### After Removing Match Chat Code:

1. ✅ Verify no console errors
2. ✅ Verify swipe flow still works
3. ✅ Verify matches page loads correctly
4. ✅ Verify no broken references to removed functions

---

## 📝 Migration Instructions

### 1. Run Database Migration

```bash
# Connect to your Supabase project
psql -h <your-host> -U postgres -d postgres

# Run the migration
\i MIGRATION_remove_match_chat_add_event_planning.sql
```

Or using Supabase CLI:
```bash
supabase migration create remove_match_chat_add_event_planning
# Copy contents of MIGRATION_remove_match_chat_add_event_planning.sql
supabase db push
```

### 2. Deploy Frontend Changes

Since this is a single-page app (index.html), just deploy the updated file to your hosting.

### 3. Notify Beta Users

If you have existing beta users with match chat data:
- Their old match messages will be deleted by the migration
- They'll need to create new events using the new flow
- Consider sending an email explaining the new planning mode

---

## 🏗️ Architecture Notes

### Event Status Lifecycle

```
User swipes right
    ↓
[Swipe Action Modal]
    ↓
Plan Event → [Planning Event Modal]
    ↓
Event created (status='planning', scheduled_date=NULL)
    ↓
[Event Chat - Planning Mode]
- Yellow banner
- Shows proposed_timeframe
- Can create polls
- "Lock in Details" button
    ↓
Lock in Details → [Lock Details Modal]
    ↓
Event updated (status='scheduled', scheduled_date set)
    ↓
[Event Chat - Scheduled Mode]
- Blue banner
- Shows actual date/time/location
- "Add to Calendar" button
- Event options menu
```

### Message Types

1. **text** (default) - Regular chat messages
2. **image** - Photo shares (existing)
3. **poll** - Poll messages (new)
   - References `polls` table via `poll_id`
   - Rendered with voting interface
4. **system** - Automated messages (new)
   - Planning started
   - Event locked
   - Other system events

### Database Relationships

```
events (now has status, proposed_timeframe)
    ↓
event_participants (unchanged)
    ↓
event_messages (now has message_type, poll_id)
    ↓
polls (new)
    ↓
poll_votes (new)
```

---

## 🐛 Known Issues / TODO

1. **System message sender**: Currently uses currentUser.id as sender for system messages. Consider creating a system user or handling differently.

2. **Poll broadcast**: When someone votes, all users should see the updated vote count. Currently only the voter sees it refresh. Need to add broadcast handler in event subscription.

3. **Old modals**: The old match notification modal and first-to-choose modal HTML might still be in the file. Safe to remove after confirming new flow works.

4. **Matches page**: Currently unchanged, will show old match chat UI until updated (Task #2 above).

5. **Notification preferences**: Might need new preference for "Event planning started" vs "Event scheduled".

6. **Event list filtering**: When displaying events on Matches page, need to filter by status (don't show cancelled events).

---

## 📄 Files Modified

1. **index.html** - All UI and JavaScript changes
2. **MIGRATION_remove_match_chat_add_event_planning.sql** - New database schema

## 📄 Files to Review (Not Modified Yet)

1. **/supabase/functions/send-notification/index.ts** - May need notification type updates
2. **/supabase/functions/event-reminders/index.ts** - Should work as-is but verify

---

## 🎉 Summary

This implementation successfully transitions Friendle from a match chat system to an event-centric planning system. The new flow is more streamlined:

**Before:**
Swipe right → Join match chat → Create event from chat

**After:**
Swipe right → Plan Event or Stay Interested → (If Plan Event) → Create planning event → Chat to coordinate → Lock in details

The planning mode provides a lightweight way to start coordinating without committing to specific times, making it easier for groups to find common availability.
