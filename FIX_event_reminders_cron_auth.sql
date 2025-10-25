-- Fix: Update event-reminders cron job with correct Supabase service role key
-- The cron job was using the OneSignal API key instead of the Supabase service role key

-- Step 1: Remove the existing job
SELECT cron.unschedule('event-reminders-hourly') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'event-reminders-hourly'
);

-- Step 2: Recreate with the CORRECT Supabase service role key
SELECT cron.schedule(
  'event-reminders-hourly',
  '0 * * * *',  -- Every hour at minute 0
  $$
    SELECT
      net.http_post(
        url := 'https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/event-reminders',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4c2V3a2piaHh0ZnFieXRmdGJ1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODg1MTg4NCwiZXhwIjoyMDc0NDI3ODg0fQ.WjXsHa36bF6Strbt2oVkvbCxl5PAEA_AUbn4UO-XF8Y'
        ),
        body := '{}'::jsonb
      ) as request_id;
  $$
);

-- Step 3: Verify the job was updated
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'event-reminders-hourly';
