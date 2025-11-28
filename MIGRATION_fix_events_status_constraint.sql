-- Migration: Fix Events Status Check Constraint
-- This fixes the events_status_check constraint to properly allow all valid status values

BEGIN;

-- Step 1: Drop any existing check constraint on events.status
-- (there might be multiple or incorrectly named constraints)
DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    FOR constraint_record IN
        SELECT conname
        FROM pg_constraint
        WHERE conrelid = 'events'::regclass
        AND contype = 'c'
        AND conname LIKE '%status%'
    LOOP
        EXECUTE format('ALTER TABLE events DROP CONSTRAINT IF EXISTS %I', constraint_record.conname);
        RAISE NOTICE 'Dropped constraint: %', constraint_record.conname;
    END LOOP;
END $$;

-- Step 2: Ensure the status column exists with correct type
ALTER TABLE events
ALTER COLUMN status TYPE TEXT,
ALTER COLUMN status SET DEFAULT 'scheduled';

-- Step 3: Update any NULL status values to 'scheduled'
UPDATE events
SET status = 'scheduled'
WHERE status IS NULL;

-- Step 4: Add the properly named check constraint
ALTER TABLE events
ADD CONSTRAINT events_status_valid
CHECK (status IN ('planning', 'scheduled', 'completed', 'cancelled'));

-- Step 5: Create index for status queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_events_status ON events(status);

COMMIT;

-- Verify the constraint was added
SELECT
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'events'::regclass
AND contype = 'c';
