-- Critical Mass Notification System
-- Add tracking columns to matches table and user preferences to profiles table

-- Track when notifications were sent for each threshold
ALTER TABLE matches
ADD COLUMN IF NOT EXISTS notified_at_4 TIMESTAMP,
ADD COLUMN IF NOT EXISTS notified_at_8 TIMESTAMP;

-- User preferences for notification types
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notify_at_4 BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS notify_at_8 BOOLEAN DEFAULT true;

-- Add index for efficient threshold queries
CREATE INDEX IF NOT EXISTS idx_matches_notifications
ON matches(notified_at_4, notified_at_8);

-- Add comment for documentation
COMMENT ON COLUMN matches.notified_at_4 IS 'Timestamp when critical mass notification was sent at 4 interested users';
COMMENT ON COLUMN matches.notified_at_8 IS 'Timestamp when critical mass notification was sent at 8 interested users';
COMMENT ON COLUMN profiles.notify_at_4 IS 'User preference to receive notifications when activities reach 4 interested users';
COMMENT ON COLUMN profiles.notify_at_8 IS 'User preference to receive notifications when activities reach 8 interested users';
