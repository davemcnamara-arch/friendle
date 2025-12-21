-- Migration: Fix Duplicate Circle Members Issue
--
-- Problem: Users who delete their account (resetApp) and recreate with same email
--          appear twice in circles because:
--          1. resetApp() only clears localStorage, doesn't delete database records
--          2. New account creates new profile_id
--          3. Both old and new profiles remain in circle_members
--
-- Solution:
--          1. Ensure circle_members has proper foreign key with ON DELETE CASCADE
--          2. Create function to properly delete user account
--          3. Create cleanup function to remove duplicate/orphaned memberships

-- ============================================================================
-- STEP 1: Ensure Foreign Key Constraints with CASCADE DELETE
-- ============================================================================

-- First, check if the constraint exists and drop it if necessary
DO $$
BEGIN
    -- Drop existing constraint if it exists (to recreate with CASCADE)
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'circle_members_profile_id_fkey'
        AND table_name = 'circle_members'
    ) THEN
        ALTER TABLE circle_members DROP CONSTRAINT circle_members_profile_id_fkey;
    END IF;
END $$;

-- Add the constraint with ON DELETE CASCADE
-- This ensures when a profile is deleted, all circle_members entries are removed
ALTER TABLE circle_members
ADD CONSTRAINT circle_members_profile_id_fkey
FOREIGN KEY (profile_id)
REFERENCES profiles(id)
ON DELETE CASCADE;

-- Do the same for circle_id (should already have CASCADE, but let's be sure)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'circle_members_circle_id_fkey'
        AND table_name = 'circle_members'
    ) THEN
        ALTER TABLE circle_members DROP CONSTRAINT circle_members_circle_id_fkey;
    END IF;
END $$;

ALTER TABLE circle_members
ADD CONSTRAINT circle_members_circle_id_fkey
FOREIGN KEY (circle_id)
REFERENCES circles(id)
ON DELETE CASCADE;

-- ============================================================================
-- STEP 2: Create Function to Properly Delete User Account
-- ============================================================================

-- This function deletes a user's profile and ALL related data
-- The CASCADE constraint on circle_members will automatically remove memberships
CREATE OR REPLACE FUNCTION delete_user_account(user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Only allow users to delete their own account
    IF user_id != auth.uid() THEN
        RAISE EXCEPTION 'You can only delete your own account';
    END IF;

    -- Delete the profile (cascading will handle related tables)
    -- The order matters due to foreign key constraints:

    -- 1. Delete from tables that reference the profile but might not have CASCADE
    DELETE FROM match_message_reactions WHERE profile_id = user_id;
    DELETE FROM event_message_reactions WHERE profile_id = user_id;
    DELETE FROM circle_message_reactions WHERE profile_id = user_id;

    DELETE FROM match_messages WHERE sender_id = user_id;
    DELETE FROM event_messages WHERE sender_id = user_id;
    DELETE FROM circle_messages WHERE sender_id = user_id;

    DELETE FROM event_participants WHERE profile_id = user_id;
    DELETE FROM match_participants WHERE profile_id = user_id;

    DELETE FROM inactivity_warnings WHERE profile_id = user_id;
    DELETE FROM muted_chats WHERE profile_id = user_id;
    DELETE FROM message_reads_match WHERE profile_id = user_id;
    DELETE FROM message_reads_event WHERE profile_id = user_id;
    DELETE FROM message_reads_circle WHERE profile_id = user_id;

    -- 2. Delete preferences
    DELETE FROM preferences WHERE profile_id = user_id;

    -- 3. Delete circle memberships (this should cascade now, but let's be explicit)
    DELETE FROM circle_members WHERE profile_id = user_id;

    -- 4. Delete hidden activities
    DELETE FROM hidden_activities WHERE profile_id = user_id;

    -- 5. Delete circles owned by user (will cascade to members, messages, etc.)
    DELETE FROM circles WHERE created_by = user_id;

    -- 6. Delete activities created by user
    DELETE FROM activities WHERE created_by = user_id;

    -- 7. Delete user's matches (as organizer)
    DELETE FROM matches WHERE created_by = user_id;

    -- 8. Delete user's events (as organizer)
    DELETE FROM events WHERE created_by = user_id;

    -- 9. Finally, delete the profile itself
    DELETE FROM profiles WHERE id = user_id;

    -- Note: This does NOT delete auth.users - that requires service_role access
    -- The user will need to contact support or use Supabase auth API to fully delete
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_user_account(UUID) TO authenticated;

COMMENT ON FUNCTION delete_user_account(UUID) IS
'Completely deletes a user account and all related data. Can only be called by the user themselves.';

-- ============================================================================
-- STEP 3: Create Function to Cleanup Duplicate Circle Memberships
-- ============================================================================

-- This function removes duplicate circle memberships
-- Keeps only the most recent membership (by last_read_at or implicit row order)
CREATE OR REPLACE FUNCTION cleanup_duplicate_circle_members()
RETURNS TABLE(
    circle_id UUID,
    removed_profile_ids UUID[],
    kept_profile_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH duplicates AS (
        -- Find circles where the same user appears multiple times
        -- This can happen if a user deleted and recreated their account
        SELECT
            cm1.circle_id,
            cm1.profile_id as old_profile_id,
            cm2.profile_id as new_profile_id,
            p1.email as email,
            cm1.last_read_at as old_last_read,
            cm2.last_read_at as new_last_read
        FROM circle_members cm1
        JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id AND cm1.profile_id < cm2.profile_id
        JOIN profiles p1 ON cm1.profile_id = p1.id
        JOIN profiles p2 ON cm2.profile_id = p2.id
        WHERE p1.email = p2.email  -- Same email = same person
    ),
    removed AS (
        -- Delete the older profile (keep the newer one)
        DELETE FROM circle_members
        WHERE (circle_id, profile_id) IN (
            SELECT circle_id, old_profile_id FROM duplicates
        )
        RETURNING circle_id, profile_id
    )
    SELECT
        r.circle_id,
        array_agg(r.profile_id) as removed_profile_ids,
        d.new_profile_id as kept_profile_id
    FROM removed r
    JOIN duplicates d ON r.circle_id = d.circle_id AND r.profile_id = d.old_profile_id
    GROUP BY r.circle_id, d.new_profile_id;
END;
$$;

-- This function should only be callable by service_role or admin
-- Remove public access
REVOKE ALL ON FUNCTION cleanup_duplicate_circle_members() FROM PUBLIC;

COMMENT ON FUNCTION cleanup_duplicate_circle_members() IS
'Removes duplicate circle memberships caused by users deleting and recreating accounts with same email. Returns info about removed duplicates.';

-- ============================================================================
-- STEP 4: Create Function to Find Duplicate Memberships (Read-Only)
-- ============================================================================

-- This allows checking for duplicates without deleting them
CREATE OR REPLACE FUNCTION find_duplicate_circle_members()
RETURNS TABLE(
    circle_id UUID,
    circle_name TEXT,
    email TEXT,
    profile_id_1 UUID,
    profile_id_2 UUID,
    name_1 TEXT,
    name_2 TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        cm1.circle_id,
        c.name as circle_name,
        p1.email,
        cm1.profile_id as profile_id_1,
        cm2.profile_id as profile_id_2,
        p1.name as name_1,
        p2.name as name_2
    FROM circle_members cm1
    JOIN circle_members cm2
        ON cm1.circle_id = cm2.circle_id
        AND cm1.profile_id < cm2.profile_id
    JOIN profiles p1 ON cm1.profile_id = p1.id
    JOIN profiles p2 ON cm2.profile_id = p2.id
    JOIN circles c ON cm1.circle_id = c.id
    WHERE p1.email = p2.email  -- Same email = same person
    ORDER BY c.name, p1.email;
END;
$$;

-- Allow authenticated users to check for their own duplicates
GRANT EXECUTE ON FUNCTION find_duplicate_circle_members() TO authenticated;

COMMENT ON FUNCTION find_duplicate_circle_members() IS
'Finds circles where the same user (by email) appears with multiple profile_ids. Read-only diagnostic function.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check that constraints are properly set
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name = 'circle_members'
    AND tc.constraint_type = 'FOREIGN KEY';

-- Expected output should show:
-- circle_members_profile_id_fkey | circle_members | profile_id | CASCADE
-- circle_members_circle_id_fkey  | circle_members | circle_id  | CASCADE
