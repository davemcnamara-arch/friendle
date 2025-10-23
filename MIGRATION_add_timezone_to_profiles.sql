-- Migration: Add timezone support to profiles table
-- This allows users to receive reminders at 9am in their local timezone

-- Add timezone column to profiles table
-- Using text type to store IANA timezone names (e.g., 'America/New_York', 'Europe/London')
-- Default to 'America/Los_Angeles' for existing users (can be updated in settings)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'America/Los_Angeles';

-- Add index for efficient timezone-based queries
CREATE INDEX IF NOT EXISTS idx_profiles_timezone
ON profiles(timezone) WHERE event_reminders_enabled = true;

-- Add comment for documentation
COMMENT ON COLUMN profiles.timezone IS 'IANA timezone name for user (e.g., America/New_York). Used for timezone-specific event reminders.';

-- Update any NULL timezones to default
UPDATE profiles
SET timezone = 'America/Los_Angeles'
WHERE timezone IS NULL;
