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
SELECT cron.schedule(
  'event-reminders-hourly',          -- Job name
  '0 * * * *',                       -- Cron expression: Every hour at minute 0
  $$
    SELECT
      net.http_post(
        url := 'https://' || current_setting('app.settings.project_ref') || '.supabase.co/functions/v1/event-reminders',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
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

-- Note: You'll need to set the following settings in your Supabase project:
-- ALTER DATABASE postgres SET app.settings.project_ref = 'your-project-ref';
-- ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';
