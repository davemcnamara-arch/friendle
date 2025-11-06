# Friendle - Complete Native App Development Specification

**Version:** 1.0
**Date:** November 6, 2024
**Target Platforms:** iOS, Android
**Estimated Development Time:** 30-40 days (experienced team)

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Application Overview](#application-overview)
3. [Technology Stack & Architecture](#technology-stack--architecture)
4. [Database Schema](#database-schema)
5. [API Endpoints](#api-endpoints)
6. [User Interface Specifications](#user-interface-specifications)
7. [User Flows & Journeys](#user-flows--journeys)
8. [Design System](#design-system)
9. [Features & Functionality](#features--functionality)
10. [Authentication & Security](#authentication--security)
11. [Real-Time Features](#real-time-features)
12. [Push Notifications](#push-notifications)
13. [Implementation Priorities](#implementation-priorities)
14. [Testing Requirements](#testing-requirements)

---

## Executive Summary

**Friendle** is a social coordination application that helps friend groups organize and attend activities together. It solves the "endless group chat" problem by creating structured matches when multiple people in a circle want to do the same activity.

### Key Value Propositions
- **Activity Matching**: Automatically groups friends who want to do the same things
- **Smart Notifications**: Alerts at critical mass thresholds (4 and 8 interested users)
- **Event Coordination**: Built-in scheduling and RSVP system
- **Inactivity Management**: Auto-removes inactive users while preserving event access
- **Real-Time Chat**: Instant messaging for matches, events, and circles

### Core User Flow
```
User creates/joins circle → Swipes on activities → System creates matches →
Users join match chat → Create events → Chat & coordinate → Attend together
```

---

## Application Overview

### What is Friendle?

Friendle is a **Progressive Web App (PWA)** currently built as a single-page application that helps friend groups coordinate activities. The native app will replicate all functionality while providing enhanced mobile experiences.

### Problem It Solves

- **Before Friendle**: Endless group chat threads where activity proposals get lost
- **With Friendle**: Structured activity matching that surfaces who wants to do what, when

### How It Works

1. **Circles**: Users create or join friend groups (called "circles")
2. **Activities**: Users swipe or select activities they're interested in
3. **Matches**: System creates matches when 2+ people in a circle like the same activity
4. **Events**: Users schedule specific dates/times for activities
5. **Chat**: Real-time messaging in matches, events, and circles
6. **Notifications**: Strategic alerts when momentum builds (4 users, 8 users)

---

## Technology Stack & Architecture

### Current Backend (Reuse for Native App)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Backend** | Supabase Edge Functions (Deno/TypeScript) | 6 serverless functions |
| **Database** | PostgreSQL (via Supabase) | 21 tables with RLS |
| **Real-Time** | Supabase Realtime (WebSocket) | Instant messaging |
| **Auth** | Supabase Auth (JWT) | Email/password authentication |
| **Push** | OneSignal | Cross-platform notifications |
| **Storage** | Supabase Storage | Profile pictures, chat photos |

### Native App Stack Recommendations

**iOS:**
- Swift + SwiftUI
- Supabase Swift SDK
- OneSignal iOS SDK
- Combine framework for reactive programming

**Android:**
- Kotlin + Jetpack Compose
- Supabase Kotlin SDK
- OneSignal Android SDK
- Coroutines + Flow for reactive programming

**Shared Backend:**
- Supabase URL: `https://kxsewkjbhxtfqbytftbu.supabase.co`
- All Edge Functions, database, and real-time subscriptions reused as-is

---

## Database Schema

### Core Tables (21 Total)

#### 1. profiles
```sql
id (UUID, PK) - Matches Supabase Auth user ID
name (TEXT) - Display name
avatar (TEXT) - URL or emoji
email (TEXT) - User email
timezone (TEXT) - IANA timezone (e.g., "America/New_York")
onesignal_player_id (TEXT) - Push notification ID
event_reminders_enabled (BOOLEAN) - 9am event reminders
notify_new_matches (BOOLEAN)
notify_event_joins (BOOLEAN)
notify_chat_messages (BOOLEAN)
notify_inactivity_warnings (BOOLEAN)
notify_at_4 (BOOLEAN) - Critical mass at 4 users
notify_at_8 (BOOLEAN) - Critical mass at 8 users
created_at (TIMESTAMP)
```

#### 2. circles
```sql
id (UUID, PK)
name (TEXT) - Circle name (max 50 chars)
code (TEXT) - 6-digit invite code
created_by (UUID, FK → profiles.id)
created_at (TIMESTAMP)
```

#### 3. circle_members
```sql
circle_id (UUID, FK → circles.id)
profile_id (UUID, FK → profiles.id)
last_read_at (TIMESTAMP) - For unread badges
created_at (TIMESTAMP)
PRIMARY KEY (circle_id, profile_id)
```

#### 4. activities
```sql
id (UUID, PK)
name (TEXT) - Activity name
emoji (TEXT) - Display emoji
is_default (BOOLEAN) - System vs. custom
created_by (UUID, FK → profiles.id, nullable)
created_at (TIMESTAMP)
```

#### 5. preferences
```sql
id (UUID, PK)
profile_id (UUID, FK → profiles.id)
circle_id (UUID, FK → circles.id)
activity_id (UUID, FK → activities.id)
selected (BOOLEAN) - User liked this activity in this circle
created_at (TIMESTAMP)
UNIQUE (profile_id, circle_id, activity_id)
```

#### 6. matches
```sql
id (UUID, PK)
circle_id (UUID, FK → circles.id)
activity_id (UUID, FK → activities.id)
notified_at_4 (TIMESTAMP) - When 4-user notification sent
notified_at_8 (TIMESTAMP) - When 8-user notification sent
created_at (TIMESTAMP)
UNIQUE (circle_id, activity_id)
```

#### 7. match_participants
```sql
match_id (UUID, FK → matches.id)
profile_id (UUID, FK → profiles.id)
last_interaction_at (TIMESTAMP) - For inactivity tracking
created_at (TIMESTAMP)
PRIMARY KEY (match_id, profile_id)
```

#### 8. events
```sql
id (UUID, PK)
match_id (UUID, FK → matches.id)
activity_id (UUID, FK → activities.id)
circle_id (UUID, FK → circles.id)
scheduled_date (DATE) - Required
scheduled_time (TIME) - Optional
location (TEXT) - Max 200 chars
notes (TEXT) - Max 1000 chars
created_by (UUID, FK → profiles.id)
status (ENUM: 'scheduled', 'completed', 'cancelled')
created_at (TIMESTAMP)
```

#### 9. event_participants
```sql
event_id (UUID, FK → events.id)
profile_id (UUID, FK → profiles.id)
status (ENUM: 'accepted', 'declined', 'maybe')
last_read_at (TIMESTAMP) - For unread chat badges
created_at (TIMESTAMP)
PRIMARY KEY (event_id, profile_id)
```

#### 10-12. Messages (3 tables)
```sql
match_messages:
  id (UUID, PK)
  match_id (UUID, FK)
  sender_id (UUID, FK → profiles.id)
  content (TEXT)
  is_deleted (BOOLEAN) - Soft delete
  deleted_at (TIMESTAMP)
  created_at (TIMESTAMP)

event_messages: (same structure, event_id instead)
circle_messages: (same structure, circle_id instead)
```

#### 13. message_reactions
```sql
id (UUID, PK)
message_id (UUID) - References match/event/circle message
sender_id (UUID, FK → profiles.id)
emoji (TEXT)
message_type (ENUM: 'match', 'event', 'circle')
created_at (TIMESTAMP)
UNIQUE (message_id, sender_id, emoji)
```

#### 14. blocked_users
```sql
id (UUID, PK)
blocker_id (UUID, FK → profiles.id) - User doing the blocking
blocked_id (UUID, FK → profiles.id) - User being blocked
reason (TEXT, optional)
created_at (TIMESTAMP)
UNIQUE (blocker_id, blocked_id)
```

#### 15. muted_chats
```sql
id (UUID, PK)
profile_id (UUID, FK → profiles.id)
match_id (UUID, FK, nullable)
event_id (UUID, FK, nullable)
circle_id (UUID, FK, nullable)
created_at (TIMESTAMP)
```

#### 16. inactivity_warnings
```sql
id (UUID, PK)
match_id (UUID, FK → matches.id)
profile_id (UUID, FK → profiles.id)
status (ENUM: 'pending', 'resolved', 'removed')
created_at (TIMESTAMP)
UNIQUE (match_id, profile_id)
```

#### 17. reports
```sql
id (UUID, PK)
reporter_id (UUID, FK → profiles.id)
reported_type (ENUM: 'user', 'match', 'event', 'circle')
reported_id (UUID)
reason_category (TEXT)
reason_details (TEXT, optional)
status (ENUM: 'pending', 'resolved', 'dismissed')
created_at (TIMESTAMP)
```

### Relationships Diagram

```
profiles (users)
  ├─ circle_members → circles (friend groups)
  ├─ preferences → activities (liked activities per circle)
  └─ match_participants → matches (joined activity chats)
       └─ event_participants → events (scheduled gatherings)

matches (activity + circle combinations)
  ├─ match_messages (chat)
  └─ events → event_messages (chat)

circles → circle_messages (group chat)
```

---

## API Endpoints

### Edge Functions (6 Total)

All Edge Functions are hosted at: `https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/`

#### 1. send-notification (POST)

**Purpose:** Generic push notification system

**Endpoint:** `/functions/v1/send-notification`

**Authentication:** None (filtering happens inside function)

**Request Body:**
```json
{
  "senderId": "uuid",
  "recipientIds": ["uuid", "uuid"],
  "message": "string",
  "activityName": "string (optional)",
  "chatType": "match | event | circle (optional)",
  "chatId": "uuid (optional)",
  "notificationType": "new_match | event_join | event_created | chat_message | match_join"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Notification sent successfully",
  "sent": 5,
  "totalRecipients": 10,
  "oneSignalId": "notification-id"
}
```

**Error Codes:**
- 400: Missing required fields
- 400: Invalid notification type
- 500: Database or OneSignal API error

---

#### 2. send-critical-mass-notification (POST)

**Purpose:** Send momentum notifications at 4 and 8 user thresholds

**Endpoint:** `/functions/v1/send-critical-mass-notification`

**Request Body:**
```json
{
  "matchId": "uuid",
  "threshold": 4 | 8
}
```

**Response:**
```json
{
  "success": true,
  "message": "Critical mass notification sent",
  "sent": 12,
  "threshold": 4,
  "interestedCount": 15,
  "joinedCount": 4,
  "oneSignalId": "notification-id"
}
```

**Business Logic:**
- Checks if notification already sent (idempotent)
- Anti-spam: Skips if threshold 8 sent <30 min after threshold 4
- Filters out quiet hours (0-7am local time)
- Only notifies interested users not yet in chat

---

#### 3. stay-interested (POST)

**Purpose:** User confirms interest after 5-day inactivity warning

**Endpoint:** `/functions/v1/stay-interested`

**Authentication:** JWT required in Authorization header

**Request Body:**
```json
{
  "matchId": "uuid",
  "profileId": "uuid"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Interaction timestamp updated"
}
```

**Security:** Verifies user ID from JWT matches profileId

---

#### 4. event-reminders (Cron)

**Purpose:** Sends 9am timezone-aware event reminders

**Schedule:** Hourly (0 * * * *)

**Trigger:** Automated cron job

**Logic:**
1. Query all users with `event_reminders_enabled = true`
2. Calculate current hour in each user's timezone
3. Filter users currently in 9am hour
4. Get events scheduled for "today" in user's timezone
5. Filter out muted events
6. Send OneSignal notifications

**Output:** Returns stats (users checked, reminders sent, etc.)

---

#### 5. inactivity-cleanup (Cron)

**Purpose:** Two-phase inactivity management

**Schedule:** Daily at 3am UTC (0 3 * * *)

**Phase 1 (Day 5 Warning):**
1. Query participants inactive for 5+ days
2. Filter for users with push enabled + preference on
3. Send "Still interested?" notifications
4. Record warnings in inactivity_warnings table

**Phase 2 (Day 7 Removal):**
1. Query participants inactive for 7+ days with pending warnings
2. Check for upcoming events
3. If NO events → Remove from match
4. If HAS events → Keep in match
5. Update warning status to 'removed'

**Cleanup:** Deletes old warnings >30 days

---

#### 6. send-report-alert (Webhook)

**Purpose:** Email admin when user reports content

**Trigger:** Database webhook on reports table INSERT

**Integration:** Resend email API

**Email Contains:**
- Report ID and timestamp
- Reporter info
- Reported content details
- SQL queries for admin review

---

### Database Operations (Frontend SDK)

The native app will use Supabase SDK to perform all CRUD operations:

#### Authentication
```typescript
// Sign up
const { data, error } = await supabase.auth.signUp({
  email: email,
  password: password
})

// Sign in
const { data, error } = await supabase.auth.signInWithPassword({
  email: email,
  password: password
})

// Sign out
await supabase.auth.signOut()
```

#### Database Queries
```typescript
// Get user's circles
const { data: circles } = await supabase
  .from('circles')
  .select('*, circle_members(profile_id)')
  .in('id', userCircleIds)

// Create match
const { data: match } = await supabase
  .from('matches')
  .insert({ circle_id, activity_id })
  .select()
  .single()

// Join match chat
const { error } = await supabase
  .from('match_participants')
  .insert({ match_id, profile_id, last_interaction_at: new Date() })

// Send message
const { data: message } = await supabase
  .from('match_messages')
  .insert({
    match_id,
    sender_id,
    content
  })
  .select('*, sender:profiles(id, name, avatar)')
  .single()
```

#### Real-Time Subscriptions
```typescript
// Subscribe to match chat
const channel = supabase
  .channel(`match_chat_${matchId}`)
  .on('broadcast', { event: 'new_general_message' }, (payload) => {
    // Handle new message
  })
  .subscribe()

// Unsubscribe
await supabase.removeChannel(channel)
```

---

## User Interface Specifications

### Screen Structure (8 Main Screens)

1. **Onboarding** - First-time user introduction
2. **Welcome/Auth** - Login, signup, password reset
3. **Circles** - Friend group management
4. **Activities** - Activity selection (swipe + grid)
5. **Matches** - Activity-based matches
6. **Events** - Upcoming scheduled events
7. **Chat** - Real-time messaging
8. **Settings** - Profile, preferences, blocking

### Bottom Navigation (5 Tabs)

```
┌─────────────────────────────────────────┐
│  Circles  Activities  Matches  Events  Settings
│     👥        🎯         💬       📅       ⚙️
└─────────────────────────────────────────┘
```

**States:**
- Active: Purple gradient (#5b4fc7)
- Inactive: Gray (#999)
- Badge: Teal circle (#14b8a6) with white number

---

## User Flows & Journeys

### 1. Sign-Up Flow (First-Time User)

```
Step 1: Onboarding Screen
  → Optional invite context ("Join [Friend's] circle!")
  → "Get Started" button

Step 2: Welcome Screen → Register Tab
  → Enter email
  → Enter password (min 6 chars)
  → Enter name
  → Choose avatar (emoji or upload photo)
  → Tap "Sign Up"

Step 3: Create First Circle
  → Tap "Create Circle" button
  → Enter circle name
  → Select minimum 4 activities
  → System generates 6-digit invite code
  → Share code with friends

Step 4: Select Activities (Swipe View)
  → Cards presented one-by-one
  → Swipe right (like) or left (pass)
  → Minimum 4 activities required
  → Tap "Save Preferences"

Step 5: View Matches
  → System creates matches for liked activities
  → Shows interested count and chat count
  → Tap match card to expand
  → Tap "Join Match" to enter chat

Step 6: Create Event (Optional)
  → Tap "Create Event" in match
  → Select date (required)
  → Add time, location, notes (optional)
  → Tap "Create Event"
  → Auto-added to event participants

Step 7: Chat & Coordinate
  → Real-time messaging
  → Share photos, locations
  → React to messages
  → Receive push notifications
```

**Estimated Time:** 3-5 minutes for power users, 5-10 minutes for average users

---

### 2. Joining an Existing Circle

```
Step 1: Receive Invite Code
  → Friend shares 6-digit code

Step 2: Tap "Join Circle" Button
  → Enter 6-digit code
  → System validates code
  → Shows circle name for confirmation
  → Tap "Join"

Step 3: Select Activities
  → Choose minimum 4 activities for this circle
  → Tap "Save"

Step 4: View Matches
  → See all existing matches in circle
  → Join relevant match chats
```

**Estimated Time:** 1-2 minutes

---

### 3. Creating an Event

```
Step 1: Navigate to Match
  → Circles tab → Select circle → Tap match card

Step 2: Tap "Create Event"
  → Modal appears

Step 3: Fill Event Details
  → Date (required, date picker)
  → Time (optional, time picker)
  → Location (optional, text input)
  → Notes (optional, textarea)

Step 4: Tap "Create Event"
  → System creates event
  → Adds creator as participant (accepted)
  → Auto-adds all match participants
  → Sends notifications to participants
  → Opens event chat

Step 5: Coordinate in Event Chat
  → Discuss details
  → Confirm attendance
  → Share location when ready
```

---

### 4. Daily Active User Flow

```
Morning:
  → Receive 9am event reminder notification
  → Open app → Navigate to Events tab
  → Review today's events

Throughout Day:
  → Receive push notifications for new messages
  → Reply in chat
  → Check matches for new activity

Evening:
  → Swipe on new activities
  → Check if new matches created
  → Create events for next week
```

---

## Design System

### Color Palette

#### Light Mode
```
Primary Gradient: #5b4fc7 → #6d3a9f (purple)
Success/Accent: #14b8a6 (teal)
Error: #dc3545 (red)
Background: #ffffff
Surface: #f5f5f5
Border: #e0e0e0
Text Primary: #1a1a1a
Text Secondary: #666666
```

#### Dark Mode
```
Primary Gradient: #5b4fc7 → #6d3a9f (purple, same)
Success/Accent: #14b8a6 (teal, same)
Error: #dc3545 (red, same)
Background: #0f0f11
Surface: #1a1a1a
Border: #333333
Text Primary: #e5e5e5
Text Secondary: #999999
```

**Implementation:** Use CSS variables or theme system in native app

---

### Typography

**Font Family:**
- iOS: SF Pro (system default)
- Android: Roboto (system default)
- Web fallback: Inter, -apple-system, BlinkMacSystemFont, "Segoe UI"

**Font Sizes:**
```
Extra Large: 28px / 1.75rem (page titles)
Large: 20px / 1.25rem (section headers)
Medium: 16px / 1rem (body text, inputs)
Small: 14px / 0.875rem (labels, secondary text)
Extra Small: 12px / 0.75rem (timestamps, hints)
```

**Font Weights:**
```
Regular: 400 (body text)
Medium: 500 (labels)
Semibold: 600 (buttons)
Bold: 700 (headings)
```

**Minimum Input Size:** 16px to prevent iOS auto-zoom

---

### Spacing Grid

```
4px   - Tight spacing (icon + text)
8px   - Small gap (form elements)
12px  - Medium gap (cards, buttons)
16px  - Default padding (containers)
20px  - Large padding (sections)
24px  - Extra large gap
32px  - Section separation
```

---

### Border Radius

```
Small: 8px (buttons, inputs)
Medium: 12px (small cards)
Large: 16px (activity cards)
Extra Large: 20px (match cards, modals)
Pill: 9999px (badges, chips)
Circle: 50% (avatars)
```

---

### Shadows

```
Small: 0 1px 3px rgba(0,0,0,0.1)
Medium: 0 2px 8px rgba(0,0,0,0.1)
Large: 0 4px 16px rgba(0,0,0,0.15)
Extra Large: 0 8px 32px rgba(0,0,0,0.2)
```

---

### Component Library

#### Primary Button
```
Background: Linear gradient #5b4fc7 → #6d3a9f
Text: White, 16px, semibold (600)
Padding: 14px 24px
Border Radius: 12px
Min Touch Target: 44×44px
Hover: Lift -2px with shadow
Active: Scale 0.98
```

#### Secondary Button
```
Background: Transparent
Border: 2px solid #5b4fc7
Text: #5b4fc7, 16px, semibold
Padding: 12px 24px (accounting for border)
Border Radius: 12px
Min Touch Target: 44×44px
Hover: Background rgba(91,79,199,0.1)
```

#### Text Input
```
Background: White (light) / #1a1a1a (dark)
Border: 1px solid #e0e0e0 / #333
Padding: 12px 14px
Font Size: 16px (prevents iOS zoom)
Border Radius: 8px
Focus: Border #5b4fc7, shadow 0 0 0 3px rgba(91,79,199,0.1)
```

#### Activity Card (Swipe View)
```
Size: Full width - 40px margin
Aspect Ratio: ~3:4 portrait
Background: White
Border: 2px solid #e0e0e0
Border Radius: 16px
Padding: 20px
Shadow: 0 4px 16px rgba(0,0,0,0.1)

Content:
  - Emoji: 48px font size, centered
  - Name: 16px bold, centered below emoji
  - Spacing: 12px between emoji and name

States:
  - Default: White background
  - Hover/Press: Lift -3px
  - Selected: Purple gradient background, white text
```

#### Activity Card (Grid View)
```
Size: 2-column grid with 10px gap
Aspect Ratio: 1:1 square
Background: White
Border: 2px solid #e0e0e0
Border Radius: 12px
Padding: 16px
Shadow: None (flat design)

Content:
  - Emoji: 32px, centered
  - Name: 14px bold, centered, truncated

States:
  - Default: White background
  - Selected: Purple gradient, white text
  - Hover: Slight background tint
```

#### Circle Card
```
Structure: Expandable card (<details> equivalent)
Background: White / #1a1a1a
Border: 1px solid #e0e0e0 / #333
Border Radius: 12px
Padding: 16px
Margin Bottom: 12px

Header:
  - Circle Name: 16px bold
  - Member Count: 14px gray
  - Expand Icon: Chevron (rotates when open)
  - Unread Badge: Teal circle with count

Expanded Content:
  - Activity list
  - Action buttons (Invite, Manage)
  - Animation: slideDown 200ms ease
```

#### Match Card
```
Structure: Expandable card
Background: White / #1a1a1a
Border: 1px solid #e0e0e0 / #333
Border Radius: 16px
Padding: 16px
Margin Bottom: 12px

Header:
  - Activity Emoji: 24px
  - Activity Name: 16px bold
  - Interested Count: "X interested, Y in chat"
  - Expand Icon: Chevron

Expanded Content:
  - Participant avatars (horizontal scroll)
  - "Join Match" button (if not joined)
  - "Create Event" button
  - "Leave Match" button (if joined)

States:
  - Default: White background
  - Unread: Green left border accent
  - Has Warning: Red left border
```

#### Message Bubble
```
Own Messages:
  - Alignment: Right
  - Background: Purple gradient
  - Text: White
  - Border Radius: 16px 16px 4px 16px
  - Max Width: 75%
  - Padding: 10px 14px
  - No avatar shown

Other Messages:
  - Alignment: Left
  - Background: White / #2a2a2a
  - Text: Black / White
  - Border Radius: 16px 16px 16px 4px
  - Max Width: 75%
  - Padding: 10px 14px
  - Avatar: 32px circle on left

System Messages:
  - Alignment: Center
  - Background: Transparent
  - Text: Gray, 12px
  - Italic style
  - Example: "Dave created this event"

Timestamps:
  - Position: Below bubble
  - Font: 11px gray
  - Format: "10:30 AM" or "Yesterday"
```

#### Avatar
```
Size Options:
  - Small: 24px (in lists)
  - Medium: 40px (chat bubbles)
  - Large: 80px (profile)

Shape: Circle (border-radius: 50%)
Border: 2px white outline (on colored backgrounds)
Fallback: Emoji or initials on purple gradient
```

#### Badge (Notification Count)
```
Position: Top-right of parent element
Size: 18px min height, auto width
Background: #14b8a6 (teal)
Text: White, 11px bold
Border: 2px white
Border Radius: 9999px (pill)
Padding: 0 6px
Minimum: Shows "1" for single notification
Maximum: Shows "9+" for 10+ notifications
```

---

## Features & Functionality

### 1. Authentication

**Sign Up:**
- Email validation (format check)
- Password minimum 6 characters
- Name required (max 100 chars)
- Avatar selection (emoji picker or photo upload)
- Photo upload max 5MB, validated for MIME type
- Profile creation on successful auth

**Sign In:**
- Email/password
- "Forgot Password" link
- Session persisted in secure storage

**Password Reset:**
- Email link flow
- Supabase handles email delivery

**Security:**
- JWT-based authentication
- Tokens auto-refreshed by SDK
- Secure storage for session tokens

---

### 2. Circle Management

**Create Circle:**
- Enter circle name (max 50 chars)
- Select minimum 4 activities
- System generates 6-digit code
- Auto-add creator as member
- Display invite code prominently

**Join Circle:**
- Enter 6-digit code
- Validate code exists
- Show circle name for confirmation
- Add user as member
- Prompt for activity selection

**Circle List:**
- Shows all user's circles
- Expandable cards
- Member count displayed
- Unread message badge (teal)
- Actions: Invite, Manage Activities

**Invite Friends:**
- Share 6-digit code
- Copy to clipboard
- Share via native share sheet
- Shows code prominently

---

### 3. Activity Selection

**Two Modes:**

**A) Swipe View (Default):**
- Tinder-style card stack
- Swipe right = like, left = pass
- Undo last swipe (up to 5 actions)
- Shows activity emoji + name
- Progress indicator (e.g., "12/50 activities")
- Minimum 4 selections required
- "Save Preferences" button at end

**B) Grid View (Toggle):**
- 2-column grid layout
- Tap to toggle selection
- Purple gradient = selected
- Search bar at top
- "Frequently Used" section at top
- Sticky "Save" button at bottom
- Select all / Deselect all options

**Activity Library:**
- Default activities provided
- Custom activities (user-submitted)
- Emoji + name for each
- Searchable by name
- Alphabetical sort option

---

### 4. Match System

**Match Creation:**
- Automatic when 2+ people in circle like same activity
- One match per (circle, activity) pair
- No duplicate matches

**Match Display:**
- Expandable cards sorted by interested count
- Header shows: Activity, interested count, chat count
- Expanded shows: Participants (avatars), action buttons
- Unread indicator (green left border)
- Warning indicator (red left border for inactivity)

**Join Match:**
- Tap "Join Match" button
- Adds user to match_participants
- Auto-adds to all upcoming events in match
- Sends notification to other participants
- Updates last_interaction_at timestamp

**Leave Match:**
- Tap "Leave Match" button in expanded view
- Confirmation dialog: "Are you sure?"
- Removes from match_participants
- Does NOT remove from events already joined

---

### 5. Event System

**Create Event:**
- Modal form with fields:
  - Date (required, date picker)
  - Time (optional, time picker)
  - Location (optional, text input, max 200 chars)
  - Notes (optional, textarea, max 1000 chars)
- Validation: Date must be future
- Auto-adds creator as participant
- Auto-adds all current match participants
- Sends notifications to all participants

**Event List:**
- Shows upcoming events across all circles
- Sorted by scheduled_date ascending
- Grouped by date ("Today", "Tomorrow", "This Week", etc.)
- Each card shows:
  - Activity emoji + name
  - Date + time (if set)
  - Location (if set)
  - Participant count
  - Unread chat badge

**Event Details:**
- Full event info
- Participant list with avatars
- RSVP status (accepted/declined/maybe)
- Edit button (creator only)
- Cancel button (creator only)
- "Open Chat" button

**RSVP:**
- Three states: Accepted, Declined, Maybe
- Default: Accepted when auto-added
- Change status anytime
- Shows aggregate counts

---

### 6. Real-Time Chat

**Chat Types:**
- Match chat (discuss activity)
- Event chat (coordinate specific event)
- Circle chat (general group chat)

**Message Types:**
- Text messages
- Photo attachments (inline display, max 200px height)
- Location sharing (shows map link)
- System messages (italic gray, centered)

**Features:**
- Send message (tap send button)
- Long-press message for actions:
  - Copy text
  - React with emoji
  - Delete (own messages only)
- Emoji reactions (display below message)
- Unread count badges
- "New messages" divider
- Auto-scroll to bottom
- Scroll-to-top button (appears after scrolling up)
- Message pagination (load 50 at a time)
- Pull-to-refresh for older messages

**Soft Delete:**
- Own messages can be deleted
- Shows "[Deleted message]" placeholder
- Preserves in database with is_deleted=true

**Muting:**
- Mute button in chat header
- Stops push notifications for this chat
- Can unmute anytime
- Indicator shown in chat list

---

### 7. Notifications

**7 Notification Types:**

| Type | When | Heading | Body |
|------|------|---------|------|
| Event Reminder | 9am on event day | "Event Today!" | "[Activity] at [Time]" |
| New Match | User joins match | "[Activity]!" | "[Name] joined your match!" |
| Match Join | Same as above | "[Activity]!" | "[Name] joined your match!" |
| Event Join | User joins event | "[Activity]!" | "[Name] is joining your event!" |
| Event Created | New event made | "[Activity]!" | "Event scheduled for [Date] at [Time]" |
| Chat Message | New message | "[Activity/Circle]" | "[Sender]: [Message preview]" |
| Inactivity Warning | Day 5 no interaction | "Still interested?" | "Tap to stay in [Activity] match" |
| Critical Mass 4 | 4 interested users | "[Activity] crew forming!" | "4 interested, 2 in chat" |
| Critical Mass 8 | 8 interested users | "[Activity] is really happening!" | "8 interested, 5 in chat" |

**User Preferences:**
- Toggle each notification type on/off
- Located in Settings > Notifications
- Default: All enabled except critical mass (opt-in)

**Quiet Hours:**
- Critical mass notifications skip 0-7am local time
- Event reminders always at 9am (overrides quiet hours)

**Deep Links:**
- Tap notification → Open relevant screen
- Match notification → Match chat
- Event notification → Event details
- Message notification → Chat screen

---

### 8. Profile & Settings

**Profile Section:**
- Name (editable)
- Email (display only)
- Avatar (editable - emoji or photo)
- Change password link

**Notification Preferences:**
- 7 toggles for notification types
- Clear labels with descriptions

**Blocked Users:**
- List of blocked users
- Unblock button
- Blocking is unilateral (other user doesn't know)

**Dark Mode:**
- Toggle switch
- Persists preference
- Instant theme switch

**Account Actions:**
- Sign out
- Delete account (future)

---

### 9. Blocking & Reporting

**Block User:**
- From profile, chat, or match
- Confirmation dialog
- Optional reason field
- Effects:
  - No notifications from blocked user
  - No messages from blocked user shown
  - Blocked user can still send (but you don't see)
  - Unilateral (they don't know)

**Report Content:**
- Report types: User, Match, Event, Circle
- Category dropdown:
  - Harassment
  - Spam
  - Inappropriate content
  - Other
- Optional details field (max 500 chars)
- Sends email to admin immediately
- Confirmation: "Thank you for your report"

---

### 10. Inactivity System

**Timeline:**
- Day 0: User joins match
- Day 5: No interaction → Send warning notification
- Day 7: Still no interaction → Check for events
  - If NO upcoming events → Remove from match
  - If HAS upcoming events → Keep in match

**User Actions:**
- Receive notification: "Still interested in [Activity]?"
- Tap notification → Opens app
- Tap "Yes, I'm interested" → Resolves warning
- Send any message in match → Auto-resolves warning

**Definition of "Interaction":**
- Sending a message
- Joining an event
- Tapping "Still interested"
- Creating an event

**Admin View:**
- Inactivity warnings table tracks status
- Cron job runs daily at 3am UTC

---

## Authentication & Security

### Row Level Security (RLS)

All database tables have RLS policies enforcing:

**Profiles:**
- Users can read own profile
- Users can read profiles of circle members
- Users can update only own profile
- Users can insert own profile (signup)

**Circles:**
- Users can read circles they're members of
- Users can read circles by code (for joining)
- Users can create circles
- Only creator can update/delete circle

**Messages:**
- Users can read messages in chats they're part of
- Users can insert messages in joined chats
- Users can update/delete only own messages

**Matches/Events:**
- Users can read matches in their circles
- Users can join matches
- Users can create events in matches they're in

**Blocking:**
- Users can only block/unblock as blocker_id
- Blocked users cannot see they're blocked

### File Upload Security

**Profile Pictures:**
- Max size: 5MB
- Allowed types: JPG, JPEG, PNG, WEBP
- MIME type validation
- Dimension limits: 10-4096 pixels
- Rate limiting: 3 uploads per 60 seconds
- Stored in Supabase Storage bucket: `avatars/{userId}/avatar.{ext}`

**Chat Photos:**
- Same validation as profile pictures
- Stored in `chat-photos` bucket
- Public URLs but not discoverable

### JWT Security

- Tokens issued by Supabase Auth
- Auto-refreshed every hour
- Stored in secure storage (iOS Keychain, Android EncryptedSharedPreferences)
- Included in Authorization header for Edge Functions

---

## Real-Time Features

### Supabase Realtime Architecture

**Channel Pattern:** `{type}_{id}`
- Match chat: `match_chat_{matchId}`
- Event chat: `event_{eventId}`
- Circle chat: `circle_chat_{circleId}`

**Broadcast Events:**
- `new_general_message` / `new_message` / `new_circle_message`
- `message_edited`
- `message_deleted`
- `reaction_changed`

**Subscription Lifecycle:**

1. **Subscribe:**
```typescript
const channel = supabase
  .channel(`match_chat_${matchId}`)
  .on('broadcast', { event: 'new_general_message' }, (payload) => {
    // Append message to chat UI
  })
  .subscribe()
```

2. **Broadcast:**
```typescript
await channel.send({
  type: 'broadcast',
  event: 'new_general_message',
  payload: { id, sender_id, content, created_at }
})
```

3. **Unsubscribe:**
```typescript
await supabase.removeChannel(channel)
```

**Best Practices:**
- Subscribe when entering chat
- Unsubscribe when leaving chat
- Clean up all subscriptions on sign out
- Filter own messages in broadcast handler (avoid duplicates)

---

## Push Notifications

### OneSignal Integration

**App ID:** `67c70940-dc92-4d95-9072-503b2f5d84c8`

**Setup:**
1. Initialize OneSignal SDK in app
2. Request permission on first launch
3. Get player ID from OneSignal
4. Save player ID to `profiles.onesignal_player_id`

**Notification Payload:**
```json
{
  "app_id": "67c70940-dc92-4d95-9072-503b2f5d84c8",
  "include_player_ids": ["player-id-1", "player-id-2"],
  "headings": { "en": "Activity Name!" },
  "contents": { "en": "Notification message" },
  "data": {
    "type": "chat_message | event_reminder | critical_mass",
    "matchId": "uuid (optional)",
    "eventId": "uuid (optional)",
    "circleId": "uuid (optional)",
    "chatType": "match | event | circle (optional)"
  },
  "buttons": [
    { "id": "join", "text": "Join Match" },
    { "id": "dismiss", "text": "Not Now" }
  ]
}
```

**Deep Linking:**
- Parse `data` object from notification
- Navigate to appropriate screen based on type
- Example: `matchId` → Open match chat

**Handling:**
- Foreground: Show in-app banner
- Background: Standard OS notification
- Tap: Open app to relevant screen

---

## Implementation Priorities

### Phase 1: MVP (Week 1-3)

**Must Have:**
- [ ] Authentication (signup, login, logout)
- [ ] Profile creation (name, avatar, email)
- [ ] Create circle (name, activities, code generation)
- [ ] Join circle (6-digit code)
- [ ] Activity selection (swipe view minimum)
- [ ] Match display (expandable cards)
- [ ] Join match chat
- [ ] Basic text messaging
- [ ] Real-time subscriptions
- [ ] Bottom navigation (5 tabs)
- [ ] Event creation (date, time, location, notes)
- [ ] Event list
- [ ] Push notification setup

**Total:** ~15-20 days

---

### Phase 2: Core Features (Week 4-5)

**Should Have:**
- [ ] Activity grid view (alternative to swipe)
- [ ] Profile picture upload
- [ ] Chat photo sharing
- [ ] Location sharing in chat
- [ ] Message reactions
- [ ] Soft delete messages
- [ ] Mute chats
- [ ] Notification preferences UI
- [ ] Dark mode toggle
- [ ] Unread badges
- [ ] Circle management (edit, leave)

**Total:** ~8-10 days

---

### Phase 3: Polish & Safety (Week 6)

**Nice to Have:**
- [ ] Block user functionality
- [ ] Report system
- [ ] Activity search
- [ ] Tutorial modals
- [ ] Loading states
- [ ] Error handling
- [ ] Offline support (read-only)
- [ ] Pull-to-refresh
- [ ] Animations & transitions
- [ ] Accessibility labels

**Total:** ~7-10 days

---

### Phase 4: Optimization (Week 7+)

**Future:**
- [ ] Performance optimization
- [ ] Analytics tracking
- [ ] A/B testing setup
- [ ] Advanced settings
- [ ] Notification customization
- [ ] Multi-language support

---

## Testing Requirements

### Unit Testing

**Critical Paths:**
- Authentication flow
- Circle creation & joining
- Activity selection logic
- Match computation algorithm
- Event creation
- Message sending
- Real-time subscription handling
- Push notification handling

---

### Integration Testing

**End-to-End Flows:**
1. Sign up → Create circle → Select activities → View matches
2. Join circle → Select activities → Join match → Send message
3. Create event → Add participants → Send message → Receive notification
4. Block user → Verify no notifications received
5. Mute chat → Verify no notifications received
6. Inactivity warning → Tap "Stay interested" → Verify resolved

---

### Manual Testing Checklist

**Authentication:**
- [ ] Sign up with valid email/password
- [ ] Sign up with invalid email (show error)
- [ ] Sign up with short password (show error)
- [ ] Login with correct credentials
- [ ] Login with wrong password (show error)
- [ ] Forgot password flow
- [ ] Logout (clears session)

**Circles:**
- [ ] Create circle with 4+ activities
- [ ] Create circle with <4 activities (show error)
- [ ] Join circle with valid code
- [ ] Join circle with invalid code (show error)
- [ ] View circle list
- [ ] Expand/collapse circle cards

**Activities:**
- [ ] Swipe right on activity (like)
- [ ] Swipe left on activity (pass)
- [ ] Undo last swipe
- [ ] Switch to grid view
- [ ] Toggle activity in grid view
- [ ] Search activities
- [ ] Save preferences with 4+ activities
- [ ] Save with <4 (show error)

**Matches:**
- [ ] View matches after selecting activities
- [ ] Join match chat
- [ ] Leave match chat
- [ ] Create event from match
- [ ] Unread badge appears on new message
- [ ] Expand/collapse match cards

**Events:**
- [ ] Create event with required date
- [ ] Create event without date (show error)
- [ ] View upcoming events
- [ ] Open event chat
- [ ] Change RSVP status
- [ ] Edit event (creator only)
- [ ] Cancel event (creator only)

**Chat:**
- [ ] Send text message
- [ ] Receive message in real-time
- [ ] Send photo (upload and display)
- [ ] Share location
- [ ] React to message (emoji)
- [ ] Delete own message (soft delete)
- [ ] Scroll to load older messages (pagination)
- [ ] Mute/unmute chat
- [ ] Unread count updates

**Notifications:**
- [ ] Receive event reminder at 9am
- [ ] Receive match join notification
- [ ] Receive event join notification
- [ ] Receive chat message notification
- [ ] Receive inactivity warning (day 5)
- [ ] Receive critical mass notification (4 users)
- [ ] Receive critical mass notification (8 users)
- [ ] Tap notification → Deep link works
- [ ] Toggle notification preferences

**Settings:**
- [ ] Update profile name
- [ ] Change profile picture
- [ ] Toggle dark mode
- [ ] Toggle notification preferences
- [ ] View blocked users
- [ ] Unblock user
- [ ] Sign out

**Blocking & Reporting:**
- [ ] Block user from profile
- [ ] Verify no notifications from blocked user
- [ ] Unblock user
- [ ] Report user with reason
- [ ] Report match with details
- [ ] Confirmation message shown

**Edge Cases:**
- [ ] Poor network connection (show loading)
- [ ] No internet (show offline message)
- [ ] Large message (handles overflow)
- [ ] 100+ participants in match (performance)
- [ ] Deleted user (graceful handling)
- [ ] Expired session (re-auth prompt)

---

## Development Timeline

### Team Composition (Recommended)

- 1 iOS Developer (Swift/SwiftUI)
- 1 Android Developer (Kotlin/Compose)
- 1 Backend/Integration Developer (Supabase)
- 1 QA/Testing Engineer
- 1 UI/UX Designer (part-time)
- 1 Project Manager (part-time)

### Timeline Breakdown

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| **Design & Planning** | 3-5 days | Wireframes, design system, API docs |
| **Phase 1: MVP** | 15-20 days | Auth, circles, activities, matches, chat, events |
| **Phase 2: Core Features** | 8-10 days | Grid view, media, reactions, dark mode |
| **Phase 3: Polish** | 7-10 days | Blocking, reporting, tutorials, animations |
| **Testing & QA** | 5-7 days | All user flows, edge cases, performance |
| **Beta Launch** | 2-3 days | TestFlight/Internal testing deployment |
| **Iteration** | Ongoing | Bug fixes, user feedback |

**Total:** 40-55 days (8-11 weeks)

---

## Appendix

### Reference Documentation

All detailed technical documentation is available in:
- `BACKEND_API_DOCUMENTATION.md` - Complete API specs (1,389 lines)
- `ARCHITECTURE_SUMMARY.md` - System overview (586 lines)
- `DOCUMENTATION_INDEX.md` - Navigation guide (401 lines)

### Environment Variables

```
SUPABASE_URL=https://kxsewkjbhxtfqbytftbu.supabase.co
SUPABASE_ANON_KEY=[provided separately]
ONESIGNAL_APP_ID=67c70940-dc92-4d95-9072-503b2f5d84c8
```

### Key Algorithms

**Activity Matching:**
```
For each circle user is in:
  For each liked activity:
    Check if match exists for (circle, activity)
    If not: Create match
    Count interested users (preferences.selected = true)
    Count chat participants (match_participants)
    If interested = 4: Send critical mass notification
    If interested = 8: Send momentum notification
```

**Inactivity Tracking:**
```
Every 24 hours:
  Query participants with last_interaction_at > 5 days
  Send warning notification
  Record in inactivity_warnings

  Query participants with last_interaction_at > 7 days AND pending warning
  For each:
    Check for upcoming events
    If NO events: Remove from match
    If HAS events: Keep in match
    Update warning to 'removed'
```

---

## Conclusion

This specification provides everything needed to build a native mobile app for Friendle. The backend infrastructure (Supabase) is fully operational and battle-tested. The native app development focuses on creating excellent mobile UI/UX while leveraging existing APIs.

**Next Steps:**
1. Review this specification with development team
2. Set up iOS/Android projects with Supabase SDKs
3. Implement Phase 1 MVP features
4. Conduct internal testing
5. Launch beta to select users
6. Iterate based on feedback

**Questions?** Refer to the detailed technical documentation or contact the backend team.

---

**Document Version:** 1.0
**Last Updated:** November 6, 2024
**Maintained By:** Development Team
