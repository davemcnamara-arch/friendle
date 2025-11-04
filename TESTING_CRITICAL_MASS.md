# Testing Critical Mass Notifications

This guide provides multiple ways to test the Critical Mass Notification system.

## Prerequisites

1. ✅ Database migration applied (`20251104_critical_mass_notifications.sql`)
2. ✅ Edge Function deployed (`send-critical-mass-notification`)
3. ✅ At least 4-8 test users with OneSignal player IDs
4. ✅ Environment variables set in Supabase Edge Functions

## Method 1: Browser Console (Easiest) 🎯

**Best for:** Quick automated testing

1. Open Friendle in your browser and log in
2. Open browser console (F12)
3. Copy and paste `test-critical-mass-notifications.js` into console
4. Run one of these commands:

```javascript
// Test threshold 4 only
await testThreshold4()

// Test threshold 8 only
await testThreshold8()

// Test both thresholds
await testBothThresholds()
```

**What it does:**
- Creates test preferences for 4 or 8 users
- Invokes the Edge Function
- Verifies notification was sent
- You should receive actual push notifications!

---

## Method 2: Manual Swiping (Most Realistic) 👆

**Best for:** End-to-end testing

1. Get 3-7 friends to help test
2. All join the same circle
3. Everyone swipes right on the same activity
4. When the 4th person swipes → threshold 4 notification sent
5. When the 8th person swipes → threshold 8 notification sent

**What to check:**
- Users who swiped right but haven't joined get notifications
- Users who already joined don't get notifications
- Users who disabled notifications in settings don't get notifications
- Notification click opens the match chat

---

## Method 3: SQL + Manual Edge Function Call 🔧

**Best for:** Debugging and verification

### Step 1: Run SQL to set up test data

```sql
-- Use TEST_trigger_notifications_simple.sql
-- Edit the file with your real IDs first

-- 1. Find your circle ID
SELECT id, name FROM circles LIMIT 5;

-- 2. Find your activity ID
SELECT id, name FROM activities LIMIT 10;

-- 3. Find user IDs (need 4-8 users)
SELECT id, name, onesignal_player_id
FROM profiles
WHERE onesignal_player_id IS NOT NULL
LIMIT 10;

-- 4. Insert test preferences (replace IDs)
INSERT INTO preferences (profile_id, circle_id, activity_id, selected)
VALUES
    ('USER_1_ID', 'CIRCLE_ID', 'ACTIVITY_ID', true),
    ('USER_2_ID', 'CIRCLE_ID', 'ACTIVITY_ID', true),
    ('USER_3_ID', 'CIRCLE_ID', 'ACTIVITY_ID', true),
    ('USER_4_ID', 'CIRCLE_ID', 'ACTIVITY_ID', true);

-- 5. Get the match ID
SELECT id FROM matches
WHERE circle_id = 'CIRCLE_ID'
AND activity_id = 'ACTIVITY_ID';
```

### Step 2: Invoke Edge Function

**In browser console:**
```javascript
const { data, error } = await supabase.functions.invoke('send-critical-mass-notification', {
  body: {
    matchId: 'YOUR_MATCH_ID',
    threshold: 4
  }
});
console.log(data, error);
```

**Or with curl:**
```bash
curl -X POST 'https://YOUR_PROJECT.supabase.co/functions/v1/send-critical-mass-notification' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "matchId": "YOUR_MATCH_ID",
    "threshold": 4
  }'
```

### Step 3: Verify notification sent

```sql
-- Check notification timestamps
SELECT
    id,
    notified_at_4,
    notified_at_8
FROM matches
WHERE id = 'YOUR_MATCH_ID';
```

---

## Method 4: Supabase Functions Dashboard 🖥️

1. Go to Supabase Dashboard → Edge Functions
2. Find `send-critical-mass-notification`
3. Click "Invoke" button
4. Use this JSON body:

```json
{
  "matchId": "YOUR_MATCH_ID",
  "threshold": 4
}
```

---

## What to Verify ✅

### 1. Basic Functionality
- [ ] Edge Function returns success
- [ ] `notified_at_4` or `notified_at_8` timestamp is set in database
- [ ] Push notifications are received by eligible users

### 2. User Filtering
- [ ] Only interested users who haven't joined receive notifications
- [ ] Users with notifications disabled don't receive notifications
- [ ] Users without OneSignal player ID don't receive notifications
- [ ] Users in quiet hours (midnight-7am) don't receive notifications

### 3. Anti-Spam
- [ ] Notification only sent once per threshold
- [ ] If threshold 4 sent <30 min ago, threshold 8 is skipped
- [ ] Re-invoking Edge Function doesn't send duplicate notifications

### 4. Notification Content
- [ ] Heading includes activity name
- [ ] Message shows interested count and joined count
- [ ] Notification includes "Join Match" and "Not Now" buttons
- [ ] Clicking notification opens correct match chat

### 5. Settings
- [ ] Toggle switches appear in Settings → Notifications
- [ ] Both toggles default to ON
- [ ] Disabling toggles prevents notifications
- [ ] Enabling toggles allows notifications again

---

## Troubleshooting 🔧

### No notifications received?

1. **Check OneSignal player ID:**
   ```sql
   SELECT id, name, onesignal_player_id
   FROM profiles
   WHERE id = 'YOUR_USER_ID';
   ```
   Should have a non-null `onesignal_player_id`

2. **Check notification preferences:**
   ```sql
   SELECT id, name, notify_at_4, notify_at_8
   FROM profiles
   WHERE id = 'YOUR_USER_ID';
   ```
   Should both be `true`

3. **Check Edge Function logs:**
   - Go to Supabase Dashboard → Edge Functions → Logs
   - Look for errors or "No eligible recipients" messages

4. **Check match status:**
   ```sql
   SELECT * FROM matches WHERE id = 'YOUR_MATCH_ID';
   ```
   Verify `notified_at_4` or `notified_at_8` is NULL (not already sent)

### Edge Function errors?

1. **Check environment variables:**
   - `ONESIGNAL_REST_API_KEY`
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

2. **Check Edge Function is deployed:**
   ```bash
   npx supabase functions list
   ```

3. **Redeploy if needed:**
   ```bash
   npx supabase functions deploy send-critical-mass-notification
   ```

---

## Clean Up Test Data 🧹

After testing, clean up:

```sql
-- Reset notification flags
UPDATE matches
SET notified_at_4 = NULL,
    notified_at_8 = NULL
WHERE id = 'YOUR_MATCH_ID';

-- Remove test preferences
DELETE FROM preferences
WHERE circle_id = 'YOUR_CIRCLE_ID'
AND activity_id = 'YOUR_ACTIVITY_ID';
```

---

## Quick Test Checklist

Run through this quickly to verify everything works:

1. ✅ Open browser console on Friendle
2. ✅ Run `await testThreshold4()`
3. ✅ Verify you receive a push notification
4. ✅ Click notification and verify it opens match chat
5. ✅ Go to Settings → verify toggles are present
6. ✅ Toggle off "Notify at 4 interested"
7. ✅ Reset and test again → no notification
8. ✅ Toggle back on → receive notification
9. ✅ Test threshold 8 with `await testThreshold8()`
10. ✅ Done! 🎉

---

## Expected Results

### Successful Test Output:

```
🧪 TEST: Critical Mass Notification (Threshold 4)
🔍 Finding test data...
Circle: Hobart Friends (abc123)
Activity: Coffee (xyz789)
Found 8 users with push notifications enabled

🎯 Simulating swipes to reach threshold 4...
✅ User 1/4 (Alice) swiped right
✅ User 2/4 (Bob) swiped right
✅ User 3/4 (Carol) swiped right
✅ User 4/4 (Dave) swiped right

🎯 THRESHOLD 4 REACHED!

📤 Invoking Edge Function for threshold 4...
✅ Edge Function response: {
  success: true,
  sent: 4,
  threshold: 4,
  interestedCount: 4,
  joinedCount: 0
}

🔍 Verifying notification was sent...
Match: Coffee in Hobart Friends
Notified at 4: 2025-11-04T12:34:56.789Z
Notified at 8: NOT SENT

✅ SUCCESS! Threshold 4 notification was sent
✅ Test complete! Check your notifications.
```

You should also receive an actual push notification saying:
**"Coffee crew forming!"**
*4 people interested • 0 in chat*

---

Need help? Check the Edge Function logs in Supabase Dashboard for detailed debug info.
