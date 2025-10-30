-- Add time support to events
-- This migration adds an optional scheduled_time field to the events table
-- to allow specifying a time for events in addition to the date

-- Add the scheduled_time column (nullable to support existing events)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS scheduled_time TIME;

-- Add a helpful comment
COMMENT ON COLUMN events.scheduled_time IS 'Optional time for the event (e.g., 14:30). If null, event is all-day.';
