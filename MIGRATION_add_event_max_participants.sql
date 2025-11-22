-- Migration: Add max_participants column to events table
-- This allows event creators to optionally set a participant limit

-- Add the max_participants column (nullable, so unlimited by default)
ALTER TABLE events
ADD COLUMN IF NOT EXISTS max_participants INTEGER DEFAULT NULL;

-- Add a check constraint to ensure max_participants is positive if set
ALTER TABLE events
ADD CONSTRAINT events_max_participants_positive
CHECK (max_participants IS NULL OR max_participants > 0);
