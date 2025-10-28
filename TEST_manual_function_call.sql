-- Check the actual HTTP response from the event-reminders function
-- This will show us what the function is actually returning

-- First, let's modify the cron job to capture the response
-- Run this to see the current setup
SELECT
  jobid,
  jobname,
  command
FROM cron.job
WHERE jobname = 'event-reminders-hourly';

-- Now let's create a test to manually call the function and see the response
-- This bypasses the cron job to test directly
SELECT
  net.http_post(
    url := 'https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/event-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4c2V3a2piaHh0ZnFieXRmdGJ1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODg1MTg4NCwiZXhwIjoyMDc0NDI3ODg0fQ.WjXsHa36bF6Strbt2oVkvbCxl5PAEA_AUbn4UO-XF8Y'
    ),
    body := '{}'::jsonb
  ) as request_result;
