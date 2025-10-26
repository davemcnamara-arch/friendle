-- ============================================================================
-- FRIENDLE AUTHENTICATION RESET SCRIPT
-- ============================================================================
-- ⚠️  CRITICAL WARNING: This deletes ALL authentication users!
-- ⚠️  Run this AFTER running RESET_DATABASE_FOR_BETA.sql
-- ⚠️  This requires SERVICE_ROLE permissions
--
-- This script deletes all users from Supabase Authentication (auth.users table).
-- After running RESET_DATABASE_FOR_BETA.sql which deletes all profiles,
-- you should also delete the corresponding auth users.
--
-- ============================================================================

-- ============================================================================
-- HOW TO RUN THIS SCRIPT
-- ============================================================================
--
-- Option 1: Via Supabase Dashboard SQL Editor (RECOMMENDED)
-- ---------------------------------------------------------
-- 1. Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/sql/new
-- 2. Paste this script
-- 3. Click "Run" button
--
-- Option 2: Via Supabase CLI
-- --------------------------
-- 1. Install Supabase CLI: npm install -g supabase
-- 2. Link to your project: supabase link --project-ref kxsewkjbhxtfqbytftbu
-- 3. Run: supabase db execute --file RESET_AUTH_USERS.sql
--
-- Option 3: Via Manual Dashboard UI
-- ----------------------------------
-- 1. Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/auth/users
-- 2. Select all users
-- 3. Click "Delete users" button
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- DELETE ALL AUTHENTICATION USERS
-- ============================================================================

-- This will delete all users from the auth.users table
-- Note: This cascades to auth.identities and other auth-related tables

DELETE FROM auth.users;

-- Verification: Check that no users remain
SELECT COUNT(*) as remaining_users FROM auth.users;
-- Expected: 0

COMMIT;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check all auth tables are clean
SELECT 'auth.users' as table_name, COUNT(*) as count FROM auth.users
UNION ALL
SELECT 'auth.identities', COUNT(*) FROM auth.identities
UNION ALL
SELECT 'auth.sessions', COUNT(*) FROM auth.sessions
UNION ALL
SELECT 'auth.refresh_tokens', COUNT(*) FROM auth.refresh_tokens;

-- Expected: All counts should be 0

-- ============================================================================
-- NOTES
-- ============================================================================
--
-- 1. This script only runs in the SQL Editor or with service_role key
-- 2. Regular users cannot delete from auth.users (protected by RLS)
-- 3. After deletion, all users will need to sign up again
-- 4. Email confirmations will be sent again if email confirmation is enabled
-- 5. OAuth connections will be cleared
--
-- ============================================================================
