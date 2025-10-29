-- ========================================
-- RLS VERIFICATION & SAFE DEPLOYMENT SCRIPT
-- ========================================
-- Run this BEFORE deploying the full RLS migration to check current state
-- and verify policies will work correctly
-- ========================================

-- STEP 1: Check current RLS status
-- ========================================
SELECT
  tablename,
  rowsecurity AS "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles', 'circles', 'circle_members', 'matches',
    'match_participants', 'events', 'event_participants',
    'preferences', 'activities', 'inactivity_warnings', 'muted_chats'
  )
ORDER BY tablename;

-- Expected: Most should show "RLS Enabled" = false (not yet enabled)
-- If already true, policies may already exist

-- ========================================
-- STEP 2: Check existing policies
-- ========================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd AS "operation" -- SELECT, INSERT, UPDATE, DELETE
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'profiles', 'circles', 'circle_members', 'matches',
    'match_participants', 'events', 'event_participants',
    'preferences', 'activities', 'inactivity_warnings', 'muted_chats'
  )
ORDER BY tablename, policyname;

-- Expected: May be empty if no policies exist yet
-- If policies exist, migration will replace them (DROP POLICY IF EXISTS)

-- ========================================
-- STEP 3: Count current data (verify no data loss after migration)
-- ========================================
SELECT
  'profiles' AS table_name, COUNT(*) AS row_count FROM profiles
UNION ALL
SELECT 'circles', COUNT(*) FROM circles
UNION ALL
SELECT 'circle_members', COUNT(*) FROM circle_members
UNION ALL
SELECT 'matches', COUNT(*) FROM matches
UNION ALL
SELECT 'match_participants', COUNT(*) FROM match_participants
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'event_participants', COUNT(*) FROM event_participants
UNION ALL
SELECT 'preferences', COUNT(*) FROM preferences
UNION ALL
SELECT 'activities', COUNT(*) FROM activities
UNION ALL
SELECT 'inactivity_warnings', COUNT(*) FROM inactivity_warnings
UNION ALL
SELECT 'muted_chats', COUNT(*) FROM muted_chats;

-- SAVE THESE COUNTS - verify same counts after migration

-- ========================================
-- STEP 4: Test a sample query BEFORE enabling RLS
-- ========================================
-- This query should work now (no RLS restrictions)
SELECT COUNT(*) AS "All Profiles (should work now)"
FROM profiles;

-- ========================================
-- DEPLOYMENT CHECKLIST
-- ========================================
-- Before running MIGRATION_add_rls_policies_all_tables.sql:
--
-- [ ] STEP 1: Save current row counts from Step 3 above
-- [ ] STEP 2: Backup your database (Supabase Dashboard → Database → Backups)
-- [ ] STEP 3: Run this verification script - save results
-- [ ] STEP 4: Test during LOW TRAFFIC period (not peak hours)
-- [ ] STEP 5: Have rollback plan ready (see below)
--
-- After running the RLS migration:
--
-- [ ] STEP 6: Verify row counts match (run Step 3 again)
-- [ ] STEP 7: Test user login and basic operations
-- [ ] STEP 8: Check for errors in Supabase logs
-- [ ] STEP 9: Test with 2-3 different user accounts
-- [ ] STEP 10: Monitor for 30 minutes before declaring success
--
-- ========================================
-- ROLLBACK PLAN (if something breaks)
-- ========================================
-- If you need to rollback (disable RLS while keeping data):
--
-- ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE circles DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE circle_members DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE match_participants DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE events DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE event_participants DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE preferences DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE activities DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE inactivity_warnings DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE muted_chats DISABLE ROW LEVEL SECURITY;
--
-- This will restore full access without RLS restrictions
-- You can re-enable later after fixing policies
--
-- ========================================
-- POST-DEPLOYMENT VERIFICATION
-- ========================================
-- After RLS is enabled, run these tests as a logged-in user:

-- Test 1: Can read own profile
-- Should return 1 row (your profile)
-- SELECT * FROM profiles WHERE id = auth.uid();

-- Test 2: Cannot read all profiles
-- Should return only YOUR profile and circle members' profiles
-- (NOT all profiles in system)
-- SELECT COUNT(*) FROM profiles;

-- Test 3: Can read circles you're in
-- Should return only circles where you're a member
-- SELECT * FROM circles;

-- Test 4: Can create circle
-- Should succeed
-- INSERT INTO circles (name, created_by)
-- VALUES ('Test Circle', auth.uid())
-- RETURNING id;

-- ========================================
-- COMMON ISSUES & FIXES
-- ========================================

-- ISSUE 1: "permission denied for table X"
-- CAUSE: Missing GRANT permissions
-- FIX: Run the GRANT statements at end of migration file

-- ISSUE 2: User can't see their own data
-- CAUSE: Policy using wrong auth.uid() check
-- FIX: Check that auth.uid() = id policies exist

-- ISSUE 3: User can't join circles
-- CAUSE: Missing INSERT policy
-- FIX: Verify "Users can join circles" policy exists

-- ISSUE 4: Edge Functions stop working
-- CAUSE: Edge functions need service_role permissions
-- FIX: Edge functions should use service_role key (not anon key)

-- ========================================
-- MONITORING QUERIES (run after deployment)
-- ========================================

-- Check for RLS policy violations in last hour
-- (Requires pg_stat_statements extension)
-- SELECT
--   query,
--   calls,
--   total_time
-- FROM pg_stat_statements
-- WHERE query LIKE '%policies%'
--   AND calls > 0
-- ORDER BY total_time DESC
-- LIMIT 10;

-- Check table permissions
SELECT
  tablename,
  grantee,
  privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name IN ('profiles', 'circles', 'matches')
  AND grantee = 'authenticated';

-- Should show: SELECT, INSERT, UPDATE, DELETE for authenticated role

-- ========================================
-- EXPECTED BEHAVIOR AFTER RLS DEPLOYMENT
-- ========================================

-- ✅ SHOULD WORK:
-- - User can read their own profile
-- - User can update their own profile
-- - User can read profiles of people in same circles
-- - User can read circles they're members of
-- - User can join circles with invite codes
-- - User can create circles
-- - User can read matches in their circles
-- - User can join matches
-- - User can read/send messages in their circles
-- - User can create events in their circles

-- ❌ SHOULD FAIL (security working):
-- - User cannot read profiles of people NOT in their circles
-- - User cannot read circles they're not members of
-- - User cannot read matches in circles they're not in
-- - User cannot update other users' profiles
-- - User cannot delete circles they didn't create
-- - User cannot send messages to circles they're not in

-- ========================================
-- SUCCESS CRITERIA
-- ========================================
-- Migration is successful if:
--
-- 1. All row counts match pre-migration counts
-- 2. Users can login successfully
-- 3. Users can see their own circles
-- 4. Users can send messages in their circles
-- 5. Users CANNOT see other users' circles (test with 2 accounts)
-- 6. No errors in Supabase logs
-- 7. App functions normally for 30 minutes
--
-- If ALL of the above are true: ✅ DEPLOYMENT SUCCESSFUL
-- If ANY of the above fail: ❌ ROLLBACK and investigate
-- ========================================
