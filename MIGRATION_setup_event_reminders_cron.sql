-- Migration: Setup pg_cron job for timezone-aware event reminders
-- This sets up an hourly cron job to send 9am reminders in each user's timezone

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing jobs if they exist (to allow re-running this migration)
SELECT cron.unschedule('event-reminders-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'event-reminders-daily'
);

SELECT cron.unschedule('event-reminders-hourly') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'event-reminders-hourly'
);

-- Schedule the event-reminders function to run every hour
-- The function will check which users are currently in their 9am hour
-- and send reminders for events scheduled today in their timezone
--
-- IMPORTANT: Before running this, replace the following placeholders:
--   - YOUR_PROJECT_REF: Find in Supabase Dashboard → Settings → General → Reference ID
--   - YOUR_SERVICE_ROLE_KEY: Find in Supabase Dashboard → Settings → API → Service Role Key
--
SELECT cron.schedule(
  'event-reminders-hourly',          -- Job name
  '0 * * * *',                       -- Cron expression: Every hour at minute 0
  $$
    SELECT
      net.http_post(
        url := 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/event-reminders',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer YOUR_SERVICE_ROLE_KEY'
        ),
        body := '{}'::jsonb
      ) as request_id;
  $$
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA cron TO postgres;

-- Verify the job was created
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'event-reminders-hourly';

-- ==========================================
-- SETUP INSTRUCTIONS
-- ==========================================
--
-- This migration requires you to manually replace two placeholders in the SQL above:
--
-- 1. YOUR_PROJECT_REF
--    - Location: Supabase Dashboard → Settings → General → Reference ID
--    - Example: "abcdefghijklmnop"
--
-- 2. YOUR_SERVICE_ROLE_KEY
--    - Location: Supabase Dashboard → Settings → API → Service Role Key
--    - Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJ..."
--    - ⚠️  IMPORTANT: Keep this secret! Only use in secure database queries.
--
-- Note: We hardcode these values because Supabase doesn't allow setting custom
-- database-level parameters (ALTER DATABASE ... SET app.settings.*) without
-- superuser privileges. The edge function will receive these credentials and
-- use its own environment variables (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
-- for subsequent operations.
