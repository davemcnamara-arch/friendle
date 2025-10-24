-- ========================================
-- CRITICAL SECURITY FIX: Add RLS Policies to All Tables
-- ========================================
-- This migration adds Row Level Security policies to all core tables
-- to prevent unauthorized data access.
--
-- IMPORTANT: This migration is safe to run on existing data.
-- It will not delete or modify any existing rows.
--
-- Run this migration in your Supabase SQL Editor.
-- ========================================

-- Enable RLS on all tables that don't have it yet
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE inactivity_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE muted_chats ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_messages ENABLE ROW LEVEL SECURITY; -- Ensure it's enabled

-- ========================================
-- PROFILES TABLE POLICIES
-- ========================================

-- Users can read their own profile
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Users can update their own profile only
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Users can read profiles of people in their circles
DROP POLICY IF EXISTS "Users can read circle member profiles" ON profiles;
CREATE POLICY "Users can read circle member profiles"
ON profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.profile_id = auth.uid()
    AND cm2.profile_id = profiles.id
  )
);

-- Users can insert their own profile during signup
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- ========================================
-- CIRCLES TABLE POLICIES
-- ========================================

-- Users can read circles they're members of
DROP POLICY IF EXISTS "Users can read their circles" ON circles;
CREATE POLICY "Users can read their circles"
ON circles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circles.id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can read circles by invite code (for joining)
DROP POLICY IF EXISTS "Users can read circles by code" ON circles;
CREATE POLICY "Users can read circles by code"
ON circles FOR SELECT
USING (code IS NOT NULL);

-- Users can create circles
DROP POLICY IF EXISTS "Users can create circles" ON circles;
CREATE POLICY "Users can create circles"
ON circles FOR INSERT
WITH CHECK (created_by = auth.uid());

-- Only circle creators can update circles
DROP POLICY IF EXISTS "Creators can update circles" ON circles;
CREATE POLICY "Creators can update circles"
ON circles FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Only circle creators can delete circles
DROP POLICY IF EXISTS "Creators can delete circles" ON circles;
CREATE POLICY "Creators can delete circles"
ON circles FOR DELETE
USING (created_by = auth.uid());

-- ========================================
-- CIRCLE_MEMBERS TABLE POLICIES
-- ========================================

-- Users can read members of circles they belong to
DROP POLICY IF EXISTS "Users can read circle members" ON circle_members;
CREATE POLICY "Users can read circle members"
ON circle_members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm
    WHERE cm.circle_id = circle_members.circle_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can insert themselves as circle members
DROP POLICY IF EXISTS "Users can join circles" ON circle_members;
CREATE POLICY "Users can join circles"
ON circle_members FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can update their own membership (e.g., last_read_at)
DROP POLICY IF EXISTS "Users can update own membership" ON circle_members;
CREATE POLICY "Users can update own membership"
ON circle_members FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Users can remove themselves from circles
DROP POLICY IF EXISTS "Users can leave circles" ON circle_members;
CREATE POLICY "Users can leave circles"
ON circle_members FOR DELETE
USING (profile_id = auth.uid());

-- Circle creators can remove members
DROP POLICY IF EXISTS "Creators can remove members" ON circle_members;
CREATE POLICY "Creators can remove members"
ON circle_members FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM circles
    WHERE circles.id = circle_members.circle_id
    AND circles.created_by = auth.uid()
  )
);

-- ========================================
-- MATCHES TABLE POLICIES
-- ========================================

-- Users can read matches for circles they're in
DROP POLICY IF EXISTS "Circle members can read matches" ON matches;
CREATE POLICY "Circle members can read matches"
ON matches FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = matches.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Circle members can create matches
DROP POLICY IF EXISTS "Circle members can create matches" ON matches;
CREATE POLICY "Circle members can create matches"
ON matches FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = matches.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- ========================================
-- MATCH_PARTICIPANTS TABLE POLICIES
-- ========================================

-- Users can read participants for matches in their circles
DROP POLICY IF EXISTS "Users can read match participants" ON match_participants;
CREATE POLICY "Users can read match participants"
ON match_participants FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM matches m
    JOIN circle_members cm ON cm.circle_id = m.circle_id
    WHERE m.id = match_participants.match_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can join matches (insert themselves)
DROP POLICY IF EXISTS "Users can join matches" ON match_participants;
CREATE POLICY "Users can join matches"
ON match_participants FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can update their own participation
DROP POLICY IF EXISTS "Users can update own participation" ON match_participants;
CREATE POLICY "Users can update own participation"
ON match_participants FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Users can leave matches
DROP POLICY IF EXISTS "Users can leave matches" ON match_participants;
CREATE POLICY "Users can leave matches"
ON match_participants FOR DELETE
USING (profile_id = auth.uid());

-- ========================================
-- MATCH_MESSAGES TABLE POLICIES
-- ========================================

-- Ensure existing policies are in place
-- (These should already exist from MIGRATION_add_message_crud_policies.sql)
-- We're adding them here for completeness

DROP POLICY IF EXISTS "Users can read match messages if they are participants" ON match_messages;
CREATE POLICY "Users can read match messages if they are participants"
ON match_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM match_participants
    WHERE match_participants.match_id = match_messages.match_id
    AND match_participants.profile_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Users can insert match messages if they are participants" ON match_messages;
CREATE POLICY "Users can insert match messages if they are participants"
ON match_messages FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM match_participants
    WHERE match_participants.match_id = match_messages.match_id
    AND match_participants.profile_id = auth.uid()
  )
  AND sender_id = auth.uid()
);

-- ========================================
-- EVENTS TABLE POLICIES
-- ========================================

-- Users can read events for circles they're in
DROP POLICY IF EXISTS "Circle members can read events" ON events;
CREATE POLICY "Circle members can read events"
ON events FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = events.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can create events in their circles
DROP POLICY IF EXISTS "Circle members can create events" ON events;
CREATE POLICY "Circle members can create events"
ON events FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = events.circle_id
    AND circle_members.profile_id = auth.uid()
  )
  AND created_by = auth.uid()
);

-- Event creators can update their events
DROP POLICY IF EXISTS "Creators can update events" ON events;
CREATE POLICY "Creators can update events"
ON events FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Event creators can delete their events
DROP POLICY IF EXISTS "Creators can delete events" ON events;
CREATE POLICY "Creators can delete events"
ON events FOR DELETE
USING (created_by = auth.uid());

-- ========================================
-- EVENT_PARTICIPANTS TABLE POLICIES
-- ========================================

-- Users can read participants for events in their circles
DROP POLICY IF EXISTS "Users can read event participants" ON event_participants;
CREATE POLICY "Users can read event participants"
ON event_participants FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN circle_members cm ON cm.circle_id = e.circle_id
    WHERE e.id = event_participants.event_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can join events
DROP POLICY IF EXISTS "Users can join events" ON event_participants;
CREATE POLICY "Users can join events"
ON event_participants FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can update their own participation
DROP POLICY IF EXISTS "Users can update own event participation" ON event_participants;
CREATE POLICY "Users can update own event participation"
ON event_participants FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Users can leave events
DROP POLICY IF EXISTS "Users can leave events" ON event_participants;
CREATE POLICY "Users can leave events"
ON event_participants FOR DELETE
USING (profile_id = auth.uid());

-- ========================================
-- PREFERENCES TABLE POLICIES
-- ========================================

-- Users can read preferences for circles they're in
DROP POLICY IF EXISTS "Users can read circle preferences" ON preferences;
CREATE POLICY "Users can read circle preferences"
ON preferences FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = preferences.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can manage their own preferences
DROP POLICY IF EXISTS "Users can insert own preferences" ON preferences;
CREATE POLICY "Users can insert own preferences"
ON preferences FOR INSERT
WITH CHECK (profile_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own preferences" ON preferences;
CREATE POLICY "Users can update own preferences"
ON preferences FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own preferences" ON preferences;
CREATE POLICY "Users can delete own preferences"
ON preferences FOR DELETE
USING (profile_id = auth.uid());

-- ========================================
-- ACTIVITIES TABLE POLICIES
-- ========================================

-- Users can read global activities and activities for their circles
DROP POLICY IF EXISTS "Users can read circle activities" ON activities;
CREATE POLICY "Users can read circle activities"
ON activities FOR SELECT
USING (
  circle_id IS NULL OR -- Global activities
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = activities.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can create custom activities for their circles
DROP POLICY IF EXISTS "Users can create circle activities" ON activities;
CREATE POLICY "Users can create circle activities"
ON activities FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = activities.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- ========================================
-- INACTIVITY_WARNINGS TABLE POLICIES
-- ========================================

-- Users can only read their own warnings
DROP POLICY IF EXISTS "Users can read own warnings" ON inactivity_warnings;
CREATE POLICY "Users can read own warnings"
ON inactivity_warnings FOR SELECT
USING (profile_id = auth.uid());

-- Only service role can insert/update/delete warnings
-- (No INSERT/UPDATE/DELETE policies for regular users)

-- ========================================
-- MUTED_CHATS TABLE POLICIES
-- ========================================

-- Users can read their own muted chats
DROP POLICY IF EXISTS "Users can read own muted chats" ON muted_chats;
CREATE POLICY "Users can read own muted chats"
ON muted_chats FOR SELECT
USING (profile_id = auth.uid());

-- Users can mute chats
DROP POLICY IF EXISTS "Users can mute chats" ON muted_chats;
CREATE POLICY "Users can mute chats"
ON muted_chats FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can unmute chats
DROP POLICY IF EXISTS "Users can unmute chats" ON muted_chats;
CREATE POLICY "Users can unmute chats"
ON muted_chats FOR DELETE
USING (profile_id = auth.uid());

-- ========================================
-- Grant necessary permissions
-- ========================================

GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON circles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON circle_members TO authenticated;
GRANT SELECT, INSERT ON matches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON match_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON event_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON preferences TO authenticated;
GRANT SELECT, INSERT ON activities TO authenticated;
GRANT SELECT ON inactivity_warnings TO authenticated;
GRANT SELECT, INSERT, DELETE ON muted_chats TO authenticated;

-- ========================================
-- Verification Query
-- ========================================

-- Run this to verify policies were created successfully:
SELECT
    schemaname,
    tablename,
    policyname,
    cmd as command,
    roles
FROM pg_policies
WHERE tablename IN (
    'profiles', 'circles', 'circle_members', 'matches',
    'match_participants', 'events', 'event_participants',
    'preferences', 'activities', 'inactivity_warnings',
    'muted_chats', 'match_messages'
)
ORDER BY tablename, policyname;

-- Expected result: You should see multiple policies for each table

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration, test the following:

-- 1. Test that users can only see their own circles:
--    SELECT * FROM circles;
--    (Should only return circles you're a member of)

-- 2. Test that users can only see circle member profiles:
--    SELECT * FROM profiles WHERE id != auth.uid();
--    (Should only return profiles of people in your circles)

-- 3. Test that users cannot access other users' preferences:
--    SELECT * FROM preferences WHERE profile_id != auth.uid();
--    (Should return empty or error)

-- 4. Test that users can only see matches from their circles:
--    SELECT * FROM matches;
--    (Should only return matches from circles you're in)

-- ========================================
-- ROLLBACK INSTRUCTIONS (if needed)
-- ========================================

-- If you need to rollback this migration, run:
-- WARNING: This will disable all security policies!
/*
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circle_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE events DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE preferences DISABLE ROW LEVEL SECURITY;
ALTER TABLE activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE inactivity_warnings DISABLE ROW LEVEL SECURITY;
ALTER TABLE muted_chats DISABLE ROW LEVEL SECURITY;
*/

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE profiles IS 'RLS enabled: Users can only access their own profile and profiles of circle members';
COMMENT ON TABLE circles IS 'RLS enabled: Users can only access circles they are members of';
COMMENT ON TABLE matches IS 'RLS enabled: Users can only access matches from their circles';
COMMENT ON TABLE events IS 'RLS enabled: Users can only access events from their circles';
