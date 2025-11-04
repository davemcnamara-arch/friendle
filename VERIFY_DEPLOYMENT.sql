-- VERIFICATION SCRIPT: Check if Critical Mass system is deployed
-- Run this in Supabase SQL Editor to check deployment status

-- =============================================================================
-- CHECK 1: Database columns exist?
-- =============================================================================
SELECT
    'matches table columns' AS check_name,
    CASE
        WHEN COUNT(*) >= 2 THEN '✅ DEPLOYED'
        ELSE '❌ NOT DEPLOYED'
    END AS status,
    array_agg(column_name) AS columns_found
FROM information_schema.columns
WHERE table_name = 'matches'
AND column_name IN ('notified_at_4', 'notified_at_8');

SELECT
    'profiles table columns' AS check_name,
    CASE
        WHEN COUNT(*) >= 2 THEN '✅ DEPLOYED'
        ELSE '❌ NOT DEPLOYED'
    END AS status,
    array_agg(column_name) AS columns_found
FROM information_schema.columns
WHERE table_name = 'profiles'
AND column_name IN ('notify_at_4', 'notify_at_8');

-- =============================================================================
-- CHECK 2: Test data - do you have any matches?
-- =============================================================================
SELECT
    COUNT(*) AS total_matches,
    COUNT(notified_at_4) AS matches_notified_at_4,
    COUNT(notified_at_8) AS matches_notified_at_8
FROM matches;

-- =============================================================================
-- CHECK 3: User preferences - are the new columns usable?
-- =============================================================================
SELECT
    COUNT(*) AS total_users,
    COUNT(CASE WHEN notify_at_4 = true THEN 1 END) AS users_with_notify_4_enabled,
    COUNT(CASE WHEN notify_at_8 = true THEN 1 END) AS users_with_notify_8_enabled,
    COUNT(onesignal_player_id) AS users_with_push_enabled
FROM profiles;

-- =============================================================================
-- RESULTS INTERPRETATION:
-- =============================================================================
-- If "✅ DEPLOYED" appears for both checks above:
--   → Database migration is complete, you're good!
--
-- If "❌ NOT DEPLOYED" appears:
--   → You need to run the migration:
--   → supabase/migrations/20251104_critical_mass_notifications.sql
--
-- For Edge Function check:
--   → Go to Supabase Dashboard → Edge Functions
--   → Look for "send-critical-mass-notification"
--   → If it's there and shows "Active" → deployed ✅
--   → If not there → needs deployment ❌
