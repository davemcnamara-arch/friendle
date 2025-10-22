-- Migration: Add notification preferences to profiles table
-- Phase 5: Polish & Preferences

-- Add notification preference columns to profiles table
-- event_reminders_enabled already exists from previous implementation

-- Add new match notifications preference
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notify_new_matches BOOLEAN DEFAULT true;

-- Add event join notifications preference (when someone joins your event)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notify_event_joins BOOLEAN DEFAULT true;

-- Add inactivity warnings preference
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notify_inactivity_warnings BOOLEAN DEFAULT true;

-- Add chat message notifications preference
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notify_chat_messages BOOLEAN DEFAULT true;

-- Add dark mode preference
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS dark_mode_enabled BOOLEAN DEFAULT false;

-- Initialize existing users with default notification preferences (all enabled)
UPDATE profiles
SET
    notify_new_matches = COALESCE(notify_new_matches, true),
    notify_event_joins = COALESCE(notify_event_joins, true),
    notify_inactivity_warnings = COALESCE(notify_inactivity_warnings, true),
    notify_chat_messages = COALESCE(notify_chat_messages, true),
    dark_mode_enabled = COALESCE(dark_mode_enabled, false)
WHERE
    notify_new_matches IS NULL
    OR notify_event_joins IS NULL
    OR notify_inactivity_warnings IS NULL
    OR notify_chat_messages IS NULL
    OR dark_mode_enabled IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN profiles.notify_new_matches IS 'Send push notification when a new match is found';
COMMENT ON COLUMN profiles.notify_event_joins IS 'Send push notification when someone joins your event';
COMMENT ON COLUMN profiles.notify_inactivity_warnings IS 'Send push notification for Day 5 inactivity warnings';
COMMENT ON COLUMN profiles.notify_chat_messages IS 'Send push notification for new chat messages';
COMMENT ON COLUMN profiles.dark_mode_enabled IS 'User preference for dark mode UI';
