-- TEST SCRIPT: Critical Mass Notifications
-- This script simulates users swiping right on activities to trigger threshold notifications
-- Run this in Supabase SQL Editor to test the notification system

-- IMPORTANT: Replace these values with real IDs from your database
-- Get these by running: SELECT id, name FROM profiles LIMIT 10;
-- Get circle ID: SELECT id, name FROM circles LIMIT 5;
-- Get activity ID: SELECT id, name FROM activities LIMIT 10;

-- =============================================================================
-- SETUP: Define test parameters (CHANGE THESE TO MATCH YOUR DATABASE)
-- =============================================================================

DO $$
DECLARE
    -- CHANGE THESE VALUES TO REAL IDS FROM YOUR DATABASE
    test_circle_id TEXT := 'YOUR_CIRCLE_ID_HERE';  -- Replace with real circle ID
    test_activity_id TEXT := 'YOUR_ACTIVITY_ID_HERE';  -- Replace with real activity ID

    -- Test user IDs (you need 8 users to test both thresholds)
    -- Replace with real profile IDs from your database
    user_ids TEXT[] := ARRAY[
        'USER_ID_1',
        'USER_ID_2',
        'USER_ID_3',
        'USER_ID_4',
        'USER_ID_5',
        'USER_ID_6',
        'USER_ID_7',
        'USER_ID_8'
    ];

    test_match_id TEXT;
    user_id TEXT;
    current_count INT;
BEGIN
    -- =============================================================================
    -- STEP 1: Clean up any existing test data for this activity/circle combo
    -- =============================================================================

    RAISE NOTICE '=== CLEANUP: Removing existing test data ===';

    -- Delete existing preferences for this activity/circle
    DELETE FROM preferences
    WHERE circle_id = test_circle_id
    AND activity_id = test_activity_id;

    RAISE NOTICE 'Cleaned up existing preferences';

    -- Reset notification flags on existing match (if any)
    UPDATE matches
    SET notified_at_4 = NULL,
        notified_at_8 = NULL
    WHERE circle_id = test_circle_id
    AND activity_id = test_activity_id;

    RAISE NOTICE 'Reset notification flags on existing match';

    -- =============================================================================
    -- STEP 2: Get or create the match
    -- =============================================================================

    RAISE NOTICE '=== STEP 2: Get or create match ===';

    -- Check if match exists
    SELECT id INTO test_match_id
    FROM matches
    WHERE circle_id = test_circle_id
    AND activity_id = test_activity_id;

    -- Create match if it doesn't exist
    IF test_match_id IS NULL THEN
        INSERT INTO matches (circle_id, activity_id, created_at)
        VALUES (test_circle_id, test_activity_id, NOW())
        RETURNING id INTO test_match_id;

        RAISE NOTICE 'Created new match with ID: %', test_match_id;
    ELSE
        RAISE NOTICE 'Using existing match with ID: %', test_match_id;
    END IF;

    -- =============================================================================
    -- STEP 3: Simulate users swiping right (add to preferences table)
    -- =============================================================================

    RAISE NOTICE '';
    RAISE NOTICE '=== STEP 3: Simulating user swipes ===';
    RAISE NOTICE 'This will add users one by one and check thresholds';
    RAISE NOTICE '';

    -- Loop through users and add them one by one
    FOREACH user_id IN ARRAY user_ids
    LOOP
        -- Insert preference (swipe right)
        INSERT INTO preferences (profile_id, circle_id, activity_id, selected)
        VALUES (user_id, test_circle_id, test_activity_id, true)
        ON CONFLICT (profile_id, circle_id, activity_id)
        DO UPDATE SET selected = true;

        -- Count current interested users
        SELECT COUNT(*) INTO current_count
        FROM preferences
        WHERE circle_id = test_circle_id
        AND activity_id = test_activity_id
        AND selected = true;

        RAISE NOTICE 'User % swiped right. Total interested: %', user_id, current_count;

        -- Check if we hit threshold 4
        IF current_count = 4 THEN
            RAISE NOTICE '';
            RAISE NOTICE '🎯 THRESHOLD 4 REACHED! 🎯';
            RAISE NOTICE 'Match ID: %', test_match_id;
            RAISE NOTICE 'Circle ID: %', test_circle_id;
            RAISE NOTICE 'Activity ID: %', test_activity_id;
            RAISE NOTICE '';
            RAISE NOTICE '➡️  To trigger notification, run in your app console:';
            RAISE NOTICE '    await supabase.functions.invoke(''send-critical-mass-notification'', {';
            RAISE NOTICE '      body: { matchId: ''%'', threshold: 4 }', test_match_id;
            RAISE NOTICE '    })';
            RAISE NOTICE '';
        END IF;

        -- Check if we hit threshold 8
        IF current_count = 8 THEN
            RAISE NOTICE '';
            RAISE NOTICE '🎯🎯 THRESHOLD 8 REACHED! 🎯🎯';
            RAISE NOTICE 'Match ID: %', test_match_id;
            RAISE NOTICE 'Circle ID: %', test_circle_id;
            RAISE NOTICE 'Activity ID: %', test_activity_id;
            RAISE NOTICE '';
            RAISE NOTICE '➡️  To trigger notification, run in your app console:';
            RAISE NOTICE '    await supabase.functions.invoke(''send-critical-mass-notification'', {';
            RAISE NOTICE '      body: { matchId: ''%'', threshold: 8 }', test_match_id;
            RAISE NOTICE '    })';
            RAISE NOTICE '';
        END IF;
    END LOOP;

    -- =============================================================================
    -- STEP 4: Display test results
    -- =============================================================================

    RAISE NOTICE '';
    RAISE NOTICE '=== TEST RESULTS ===';
    RAISE NOTICE 'Match ID: %', test_match_id;
    RAISE NOTICE 'Total interested users: %', current_count;
    RAISE NOTICE '';

    -- Show notification status
    SELECT
        CASE WHEN notified_at_4 IS NULL THEN 'NOT SENT' ELSE 'SENT at ' || notified_at_4::TEXT END,
        CASE WHEN notified_at_8 IS NULL THEN 'NOT SENT' ELSE 'SENT at ' || notified_at_8::TEXT END
    INTO
        STRICT notified_at_4, notified_at_8
    FROM matches
    WHERE id = test_match_id;

    RAISE NOTICE 'Threshold 4 notification: %', notified_at_4;
    RAISE NOTICE 'Threshold 8 notification: %', notified_at_8;
    RAISE NOTICE '';

END $$;

-- =============================================================================
-- VERIFICATION QUERIES (run these separately to check results)
-- =============================================================================

-- Query 1: Check match status
SELECT
    m.id AS match_id,
    a.name AS activity_name,
    c.name AS circle_name,
    m.notified_at_4,
    m.notified_at_8,
    COUNT(DISTINCT p.profile_id) AS interested_count
FROM matches m
JOIN activities a ON m.activity_id = a.id
JOIN circles c ON m.circle_id = c.id
LEFT JOIN preferences p ON p.circle_id = m.circle_id
    AND p.activity_id = m.activity_id
    AND p.selected = true
WHERE m.circle_id = 'YOUR_CIRCLE_ID_HERE'  -- Replace with your circle ID
AND m.activity_id = 'YOUR_ACTIVITY_ID_HERE'  -- Replace with your activity ID
GROUP BY m.id, a.name, c.name, m.notified_at_4, m.notified_at_8;

-- Query 2: List all interested users for this match
SELECT
    p.profile_id,
    pr.name,
    pr.onesignal_player_id,
    pr.notify_at_4,
    pr.notify_at_8,
    CASE WHEN mp.profile_id IS NOT NULL THEN 'YES' ELSE 'NO' END AS already_joined
FROM preferences p
JOIN profiles pr ON p.profile_id = pr.id
LEFT JOIN match_participants mp ON mp.profile_id = p.profile_id
    AND mp.match_id = (
        SELECT id FROM matches
        WHERE circle_id = 'YOUR_CIRCLE_ID_HERE'
        AND activity_id = 'YOUR_ACTIVITY_ID_HERE'
    )
WHERE p.circle_id = 'YOUR_CIRCLE_ID_HERE'  -- Replace with your circle ID
AND p.activity_id = 'YOUR_ACTIVITY_ID_HERE'  -- Replace with your activity ID
AND p.selected = true
ORDER BY p.created_at;

-- Query 3: Check eligible users for notification (who would receive it)
SELECT
    p.profile_id,
    pr.name,
    pr.onesignal_player_id IS NOT NULL AS has_player_id,
    pr.notify_at_4,
    pr.notify_at_8,
    CASE WHEN mp.profile_id IS NOT NULL THEN 'Already joined' ELSE 'Eligible' END AS status
FROM preferences p
JOIN profiles pr ON p.profile_id = pr.id
LEFT JOIN match_participants mp ON mp.profile_id = p.profile_id
    AND mp.match_id = (
        SELECT id FROM matches
        WHERE circle_id = 'YOUR_CIRCLE_ID_HERE'
        AND activity_id = 'YOUR_ACTIVITY_ID_HERE'
    )
WHERE p.circle_id = 'YOUR_CIRCLE_ID_HERE'  -- Replace with your circle ID
AND p.activity_id = 'YOUR_ACTIVITY_ID_HERE'  -- Replace with your activity ID
AND p.selected = true
AND pr.onesignal_player_id IS NOT NULL  -- Has push enabled
AND mp.profile_id IS NULL  -- Hasn't joined yet
ORDER BY p.created_at;
