-- SIMPLE TEST: Trigger Critical Mass Notifications
-- This script helps you quickly test the notification system

-- =============================================================================
-- STEP 1: Find your test data (run these queries first)
-- =============================================================================

-- Find available circles
SELECT id, name, created_by
FROM circles
ORDER BY created_at DESC
LIMIT 5;

-- Find available activities
SELECT id, name, circle_id
FROM activities
WHERE circle_id IS NULL OR circle_id IN (SELECT id FROM circles LIMIT 1)
ORDER BY name
LIMIT 10;

-- Find available users (with OneSignal player IDs)
SELECT id, name, onesignal_player_id, notify_at_4, notify_at_8
FROM profiles
WHERE onesignal_player_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- =============================================================================
-- STEP 2: Set up test scenario (EDIT THE VALUES BELOW)
-- =============================================================================

-- Example: Create test preferences to reach threshold 4
-- Replace these IDs with real values from the queries above

INSERT INTO preferences (profile_id, circle_id, activity_id, selected)
VALUES
    -- User 1
    ('REPLACE_WITH_USER_ID_1', 'REPLACE_WITH_CIRCLE_ID', 'REPLACE_WITH_ACTIVITY_ID', true),
    -- User 2
    ('REPLACE_WITH_USER_ID_2', 'REPLACE_WITH_CIRCLE_ID', 'REPLACE_WITH_ACTIVITY_ID', true),
    -- User 3
    ('REPLACE_WITH_USER_ID_3', 'REPLACE_WITH_CIRCLE_ID', 'REPLACE_WITH_ACTIVITY_ID', true),
    -- User 4 (this should trigger threshold 4!)
    ('REPLACE_WITH_USER_ID_4', 'REPLACE_WITH_CIRCLE_ID', 'REPLACE_WITH_ACTIVITY_ID', true)
ON CONFLICT (profile_id, circle_id, activity_id)
DO UPDATE SET selected = true;

-- =============================================================================
-- STEP 3: Create or get the match
-- =============================================================================

-- Check if match exists
SELECT id, notified_at_4, notified_at_8
FROM matches
WHERE circle_id = 'REPLACE_WITH_CIRCLE_ID'
AND activity_id = 'REPLACE_WITH_ACTIVITY_ID';

-- If no match exists, create one:
INSERT INTO matches (circle_id, activity_id, created_at)
VALUES ('REPLACE_WITH_CIRCLE_ID', 'REPLACE_WITH_ACTIVITY_ID', NOW())
ON CONFLICT DO NOTHING
RETURNING id, notified_at_4, notified_at_8;

-- =============================================================================
-- STEP 4: Verify interested count
-- =============================================================================

-- Count interested users for this activity/circle
SELECT
    m.id AS match_id,
    a.name AS activity_name,
    c.name AS circle_name,
    COUNT(DISTINCT p.profile_id) AS interested_count,
    m.notified_at_4,
    m.notified_at_8
FROM matches m
JOIN activities a ON m.activity_id = a.id
JOIN circles c ON m.circle_id = c.id
LEFT JOIN preferences p ON p.circle_id = m.circle_id
    AND p.activity_id = m.activity_id
    AND p.selected = true
WHERE m.circle_id = 'REPLACE_WITH_CIRCLE_ID'
AND m.activity_id = 'REPLACE_WITH_ACTIVITY_ID'
GROUP BY m.id, a.name, c.name, m.notified_at_4, m.notified_at_8;

-- =============================================================================
-- STEP 5: Test the Edge Function (copy match_id from above query)
-- =============================================================================

-- You cannot call Edge Functions directly from SQL.
-- Instead, use one of these methods:

-- METHOD 1: Test in browser console (when logged into Friendle)
-- Open browser console and run:
/*
await supabase.functions.invoke('send-critical-mass-notification', {
  body: {
    matchId: 'REPLACE_WITH_MATCH_ID_FROM_QUERY_ABOVE',
    threshold: 4
  }
})
*/

-- METHOD 2: Test with curl (replace YOUR_SUPABASE_ANON_KEY)
/*
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-critical-mass-notification' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "matchId": "REPLACE_WITH_MATCH_ID",
    "threshold": 4
  }'
*/

-- METHOD 3: Test from the Friendle app
-- Just swipe right on the activity until you reach 4 users!

-- =============================================================================
-- STEP 6: Verify notification was sent
-- =============================================================================

-- Check if notification timestamp was recorded
SELECT
    id,
    notified_at_4,
    notified_at_8,
    CASE
        WHEN notified_at_4 IS NOT NULL THEN 'Threshold 4 notification sent at ' || notified_at_4::TEXT
        ELSE 'Threshold 4 notification NOT sent yet'
    END AS threshold_4_status,
    CASE
        WHEN notified_at_8 IS NOT NULL THEN 'Threshold 8 notification sent at ' || notified_at_8::TEXT
        ELSE 'Threshold 8 notification NOT sent yet'
    END AS threshold_8_status
FROM matches
WHERE circle_id = 'REPLACE_WITH_CIRCLE_ID'
AND activity_id = 'REPLACE_WITH_ACTIVITY_ID';

-- =============================================================================
-- CLEANUP: Reset test (run this to test again)
-- =============================================================================

-- Reset notification flags (allows you to test again)
UPDATE matches
SET notified_at_4 = NULL,
    notified_at_8 = NULL
WHERE circle_id = 'REPLACE_WITH_CIRCLE_ID'
AND activity_id = 'REPLACE_WITH_ACTIVITY_ID';

-- Remove test preferences (if you want to start from scratch)
-- DELETE FROM preferences
-- WHERE circle_id = 'REPLACE_WITH_CIRCLE_ID'
-- AND activity_id = 'REPLACE_WITH_ACTIVITY_ID';
