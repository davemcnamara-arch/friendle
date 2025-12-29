-- ============================================================================
-- Remove Obsolete Notification Triggers and Columns
-- ============================================================================
-- This migration removes notification features that are no longer relevant
-- after the event-planning redesign removed match chat:
-- 1. notify_new_matches (new_match and match_join notifications - obsolete)
-- 2. notify_inactivity_warnings (inactivity warning system - obsolete)
-- 3. last_interaction_at tracking (no longer needed without match chat)
-- 4. inactivity_warnings table (no longer used)
-- ============================================================================

BEGIN;

-- ============================================================================
-- Part 1: Remove obsolete notification preference columns from profiles
-- ============================================================================

-- Remove notify_new_matches (used for new_match/match_join notifications)
ALTER TABLE profiles
DROP COLUMN IF EXISTS notify_new_matches CASCADE;

-- Remove notify_inactivity_warnings (used for "Still interested?" notifications)
ALTER TABLE profiles
DROP COLUMN IF EXISTS notify_inactivity_warnings CASCADE;

-- ============================================================================
-- Part 2: Remove inactivity tracking from match_participants
-- ============================================================================

-- Remove last_interaction_at column (used for inactivity tracking)
ALTER TABLE match_participants
DROP COLUMN IF EXISTS last_interaction_at CASCADE;

-- Drop related indexes
DROP INDEX IF EXISTS idx_match_participants_last_interaction_at;
DROP INDEX IF EXISTS idx_match_participants_match_last_interaction;

-- ============================================================================
-- Part 3: Drop inactivity_warnings table
-- ============================================================================

DROP TABLE IF EXISTS inactivity_warnings CASCADE;

COMMIT;

-- ============================================================================
-- Summary
-- ============================================================================
-- Removed columns:
--   - profiles.notify_new_matches
--   - profiles.notify_inactivity_warnings
--   - match_participants.last_interaction_at
-- Dropped tables:
--   - inactivity_warnings
-- Dropped indexes:
--   - idx_match_participants_last_interaction_at
--   - idx_match_participants_match_last_interaction
-- ============================================================================
