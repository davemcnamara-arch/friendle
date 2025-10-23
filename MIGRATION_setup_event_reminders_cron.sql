-- Migration: Setup pg_cron job for event reminders
-- This sets up a daily cron job to send 9am reminders for events scheduled today

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Remove existing job if it exists (to allow re-running this migration)
SELECT cron.unschedule('event-reminders-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'event-reminders-daily'
);

-- Schedule the event-reminders function to run daily at 9:00 AM UTC
-- This will send reminders to users for events scheduled today
SELECT cron.schedule(
  'event-reminders-daily',           -- Job name
  '0 9 * * *',                       -- Cron expression: 9:00 AM UTC daily
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
WHERE jobname = 'event-reminders-daily';

-- Note: You'll need to set the following settings in your Supabase project:
-- ALTER DATABASE postgres SET app.settings.project_ref = 'your-project-ref';
-- ALTER DATABASE postgres SET app.settings.service_role_key = 'your-service-role-key';
