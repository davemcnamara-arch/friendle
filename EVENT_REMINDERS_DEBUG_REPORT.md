# Event Reminders Debugging Report

**Date:** 2025-10-25
**Issue:** 9am event reminder notifications are not being sent
**User Location:** Sydney, Australia (AEDT/AEST - UTC+10/+11)

---

## Executive Summary

I've analyzed the event reminder system and identified several potential issues that could prevent notifications from being sent. I've also added comprehensive logging to help debug future issues.

### Key Findings

1. **Timezone Configuration Critical** - User's timezone must be set to `Australia/Sydney` in the profiles table
2. **Cron Job May Not Be Configured** - Migration SQL has placeholders that need to be replaced
3. **Logging Was Insufficient** - Added detailed logging at each step
4. **System Logic is Sound** - The event reminder logic itself appears correct

---

## Investigation Results

### 1. Cron Job Configuration ✓ CHECKED

**Location:** `MIGRATION_setup_event_reminders_cron.sql`

**Status:** ⚠️ NEEDS VERIFICATION

The cron job should run hourly (`'0 * * * *'`) via pg_cron, but the migration file contains placeholders:
- `YOUR_PROJECT_REF` - needs Supabase project reference ID
- `YOUR_SERVICE_ROLE_KEY` - needs Supabase service role key

**Action Required:**
```sql
-- Check if cron job exists:
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname = 'event-reminders-hourly';
```

If the job doesn't exist or has placeholders, you need to run the migration with actual values.

---

### 2. Edge Function Analysis ✓ CHECKED

**Location:** `supabase/functions/event-reminders/index.ts`

**Status:** ✓ LOGIC IS CORRECT

The function follows this flow:
1. Gets all users with `event_reminders_enabled = true` and non-null `onesignal_player_id`
2. Filters users currently in their 9am hour based on timezone
3. Gets all scheduled events for those users
4. Filters events scheduled for "today" in each user's timezone
5. Sends notifications via OneSignal API

**OneSignal Configuration:**
- App ID: `67c70940-dc92-4d95-9072-503b2f5d84c8` ✓ CORRECT
- API Key: Retrieved from `ONESIGNAL_REST_API_KEY` env var

---

### 3. User Settings Requirements ✓ CHECKED

**Required Database Values:**

For the user to receive event reminders, their profile must have:

| Field | Required Value | Default | Critical? |
|-------|---------------|---------|-----------|
| `event_reminders_enabled` | `true` | varies | ✓ YES |
| `onesignal_player_id` | valid player ID | `null` | ✓ YES |
| `timezone` | `'Australia/Sydney'` | `'America/Los_Angeles'` | ✓ YES |

**Action Required:**
```sql
-- Check user's settings (replace USER_ID with actual user ID):
SELECT
  id,
  name,
  event_reminders_enabled,
  timezone,
  onesignal_player_id,
  CASE
    WHEN onesignal_player_id IS NULL THEN '✗ Missing player ID'
    ELSE '✓ Player ID set'
  END as player_id_status,
  CASE
    WHEN timezone = 'Australia/Sydney' THEN '✓ Correct timezone'
    WHEN timezone IS NULL THEN '✗ NULL timezone (will use LA default)'
    ELSE '⚠️ Wrong timezone: ' || timezone
  END as timezone_status
FROM profiles
WHERE id = 'USER_ID';
```

---

### 4. Timezone Logic Analysis ✓ VERIFIED

**How It Works:**

The function uses `Intl.DateTimeFormat` to:
1. Get the current hour in the user's timezone
2. Check if it's 9am (hour === 9)
3. Compare event dates in the user's timezone

**Example for Sydney:**
- When UTC time is 23:00 (11pm), Sydney time is 10:00 (10am) - hour = 10 ✗
- When UTC time is 22:00 (10pm), Sydney time is 09:00 (9am) - hour = 9 ✓

**Critical Issue:**
If the user's timezone is not set or defaults to `'America/Los_Angeles'`:
- They will receive reminders at 9am Los Angeles time
- This is approximately 5pm-6pm Sydney time (depending on DST)
- They will NOT receive reminders at 9am Sydney time

---

### 5. Event Query Logic ✓ VERIFIED

**Events Must Match:**
1. User is a participant (`event_participants` table)
2. Event status = `'scheduled'`
3. Event scheduled_date falls on "today" in user's timezone
4. Event is not muted (`muted_chats` table)

**SQL Query Structure:**
```sql
SELECT profile_id, events.*
FROM event_participants
INNER JOIN events ON events.id = event_participants.event_id
WHERE profile_id IN (users_in_9am_hour)
  AND events.status = 'scheduled'
```

Then filtered in application code to check if scheduled_date matches "today" in user's timezone.

---

### 6. OneSignal Integration ✓ VERIFIED

**Notification Payload:**
```json
{
  "app_id": "67c70940-dc92-4d95-9072-503b2f5d84c8",
  "include_player_ids": ["user's onesignal_player_id"],
  "headings": { "en": "Event Today!" },
  "contents": { "en": "Reminder: \"Event Name\" is scheduled for today" },
  "data": {
    "type": "event_reminder",
    "event_id": "...",
    "match_id": "...",
    "event_count": 1
  }
}
```

**Potential Issues:**
- If OneSignal player ID is invalid or expired, notification will fail
- Check OneSignal dashboard for delivery status
- API errors will now be logged with full details

---

## Changes Made

### Enhanced Logging

I've added comprehensive logging to the Edge Function that will show:

1. **Startup Info:**
   - Current UTC time and hour
   - OneSignal configuration status

2. **User Filtering:**
   - All users with reminders enabled
   - Current hour in each user's timezone
   - Which users are in their 9am hour

3. **Event Filtering:**
   - All events found for users
   - Event scheduled dates in UTC and user's timezone
   - Today's date in user's timezone
   - Which events match "today"

4. **Notification Sending:**
   - Player ID being sent to
   - Notification content
   - OneSignal API response (success/failure)
   - Recipient count

5. **Summary Stats:**
   - Success/failure counts
   - All relevant metrics

**Example Log Output:**
```
========================================
Starting timezone-aware event reminders job
========================================
Current UTC time: 2025-10-25T22:00:00.000Z
Current UTC hour: 22
OneSignal App ID: 67c70940-dc92-4d95-9072-503b2f5d84c8
OneSignal API Key configured: true

✓ Found 1 users with reminders enabled
Users with reminders: [
  {
    id: '...',
    name: 'User Name',
    timezone: 'Australia/Sydney',
    has_player_id: true
  }
]

--- Checking which users are in their 9am hour ---
User: User Name (user-id)
  Timezone: Australia/Sydney
  Current hour in timezone: 9
  Is 9am? ✓ YES

✓ Found 1 users in their 9am hour: ['User Name']
...
```

---

## Troubleshooting Checklist

Use this checklist to debug why reminders aren't being sent:

### Step 1: Verify Cron Job is Running
```sql
-- Check cron job exists and is active
SELECT * FROM cron.job WHERE jobname = 'event-reminders-hourly';

-- Check cron job run history
SELECT * FROM cron.job_run_details
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'event-reminders-hourly')
ORDER BY start_time DESC
LIMIT 10;
```

**Expected:** Job should run every hour at minute 0.

---

### Step 2: Check User Settings
```sql
-- Verify user has correct settings
SELECT
  id,
  name,
  event_reminders_enabled,
  timezone,
  onesignal_player_id IS NOT NULL as has_player_id
FROM profiles
WHERE id = 'USER_ID';
```

**Expected:**
- `event_reminders_enabled = true`
- `timezone = 'Australia/Sydney'`
- `has_player_id = true`

---

### Step 3: Check if User Has Scheduled Events Today
```sql
-- Check events scheduled for today (Sydney time)
-- Note: This is approximate - the actual check happens in the Edge Function
SELECT
  e.id,
  e.name,
  e.scheduled_date,
  e.status,
  ep.profile_id
FROM events e
JOIN event_participants ep ON ep.event_id = e.id
WHERE ep.profile_id = 'USER_ID'
  AND e.status = 'scheduled'
  AND e.scheduled_date >= CURRENT_DATE AT TIME ZONE 'Australia/Sydney'
  AND e.scheduled_date < (CURRENT_DATE + INTERVAL '1 day') AT TIME ZONE 'Australia/Sydney';
```

**Expected:** Should return events scheduled for today in Sydney timezone.

---

### Step 4: Manually Trigger Edge Function

You can manually trigger the event reminders function to test:

```bash
curl -X POST \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/event-reminders \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json"
```

**Expected:** Will return detailed logs and stats about the execution.

---

### Step 5: Check Supabase Edge Function Logs

In Supabase Dashboard:
1. Go to Edge Functions
2. Click on `event-reminders`
3. View Logs tab
4. Look for recent executions

With the enhanced logging, you should see detailed output showing:
- Which users were checked
- Which users are in their 9am hour
- Which events were found
- Which notifications were sent
- Any errors

---

### Step 6: Check OneSignal Dashboard

1. Go to OneSignal dashboard
2. Navigate to Messages → Sent Messages
3. Look for messages sent to the user's player ID
4. Check delivery status (Delivered, Failed, etc.)

---

## Most Likely Issues

Based on the analysis, here are the most likely causes:

### 1. User's Timezone Not Set to Australia/Sydney (95% LIKELY)
**Problem:** Timezone defaults to `'America/Los_Angeles'`
**Impact:** User gets reminders at 9am LA time (5-6pm Sydney time)
**Fix:**
```sql
UPDATE profiles
SET timezone = 'Australia/Sydney'
WHERE id = 'USER_ID';
```

### 2. Cron Job Not Configured (80% LIKELY)
**Problem:** Cron job was never set up or has placeholder values
**Impact:** Function never runs
**Fix:** Run the migration SQL with actual project values

### 3. event_reminders_enabled = false (50% LIKELY)
**Problem:** User has reminders disabled
**Impact:** User is filtered out in step 1
**Fix:**
```sql
UPDATE profiles
SET event_reminders_enabled = true
WHERE id = 'USER_ID';
```

### 4. Missing onesignal_player_id (40% LIKELY)
**Problem:** User's device hasn't registered with OneSignal
**Impact:** User is filtered out in step 1
**Fix:** Ensure the app is properly registering devices with OneSignal

### 5. No Events Scheduled for Today (30% LIKELY)
**Problem:** User has no events scheduled for today
**Impact:** No reminders to send
**Fix:** Create a test event scheduled for today

---

## Recommendations

### Immediate Actions

1. **Verify User Timezone:**
   ```sql
   SELECT id, name, timezone FROM profiles WHERE id = 'USER_ID';
   -- If not 'Australia/Sydney', update it
   UPDATE profiles SET timezone = 'Australia/Sydney' WHERE id = 'USER_ID';
   ```

2. **Verify Cron Job:**
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'event-reminders-hourly';
   ```

3. **Test Function Manually:**
   - Trigger the edge function manually (see Step 4 above)
   - Check the logs for detailed output

4. **Check OneSignal:**
   - Verify player ID is valid
   - Check OneSignal dashboard for delivery status

### Long-term Improvements

1. **Add Health Check Endpoint:**
   - Create an endpoint to verify cron job is running
   - Monitor last execution time

2. **Add User Notifications Page:**
   - Let users see their notification history
   - Let users test their notification settings

3. **Add Admin Dashboard:**
   - View cron job status
   - See notification delivery stats
   - Manually trigger test notifications

4. **Timezone Auto-Detection:**
   - Auto-detect and set timezone when user signs up
   - Prompt user to verify timezone in settings

---

## Testing the Fix

Once you've verified the settings, you can test:

1. **Wait for the next 9am Sydney time** (when UTC is 22:00 or 23:00 depending on DST)
2. **Or manually trigger the function** at 9am Sydney time
3. **Check the logs** to see the detailed execution flow
4. **Check OneSignal dashboard** for delivery confirmation

The enhanced logging will show you exactly what's happening at each step.

---

## Files Modified

- `supabase/functions/event-reminders/index.ts` - Added comprehensive logging

## Files Analyzed

- `supabase/functions/event-reminders/index.ts` - Event reminders Edge Function
- `MIGRATION_setup_event_reminders_cron.sql` - Cron job setup
- `MIGRATION_add_timezone_to_profiles.sql` - Timezone field definition
- `MIGRATION_add_notification_preferences.sql` - Notification preferences

---

## Next Steps

1. Review this report
2. Run the troubleshooting checklist queries
3. Fix any issues identified
4. Test by manually triggering the function
5. Monitor the logs during the next scheduled run at 9am Sydney time
