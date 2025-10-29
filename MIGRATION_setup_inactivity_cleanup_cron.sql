-- Migration: Setup pg_cron job for inactivity-cleanup Edge Function
-- This function runs daily at 10:00 AM UTC to:
-- - Day 5: Send "Still interested?" warning notifications
-- - Day 7: Auto-remove inactive participants (unless they have upcoming events)

-- IMPORTANT: pg_cron must be enabled in Supabase Dashboard first!
-- Go to: Database > Extensions > Search for "pg_cron" > Enable
-- Or contact Supabase support if you encounter privilege errors

-- Step 1: Verify pg_cron is available (will error if not enabled)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    RAISE EXCEPTION 'pg_cron extension is not enabled. Please enable it in Supabase Dashboard under Database > Extensions';
  END IF;
END $$;

-- Step 2: Unschedule any existing job (in case re-running)
SELECT cron.unschedule('inactivity-cleanup-daily') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'inactivity-cleanup-daily'
);

-- Step 3: Schedule the daily cron job at 10:00 AM UTC
SELECT cron.schedule(
  'inactivity-cleanup-daily',
  '0 10 * * *',  -- Every day at 10:00 AM UTC
  $$
    SELECT
      net.http_post(
        url := 'https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/inactivity-cleanup',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4c2V3a2piaHh0ZnFieXRmdGJ1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODg1MTg4NCwiZXhwIjoyMDc0NDI3ODg0fQ.WjXsHa36bF6Strbt2oVkvbCxl5PAEA_AUbn4UO-XF8Y'
        ),
        body := '{}'::jsonb
      ) as request_id;
  $$
);

-- Step 4: Verify the job was created successfully
SELECT jobid, jobname, schedule, command
FROM cron.job
WHERE jobname = 'inactivity-cleanup-daily';

-- Expected output:
-- jobid | jobname                   | schedule      | command
-- ------|---------------------------|---------------|--------
-- XXX   | inactivity-cleanup-daily  | 0 10 * * *    | SELECT net.http_post(...)

-- Note: The cron job will run automatically at 10:00 AM UTC daily.
-- For manual testing, use the MANUAL_TEST_inactivity_cleanup.sql file.

-- To view job run history:
-- SELECT jrd.*, j.jobname
-- FROM cron.job_run_details jrd
-- JOIN cron.job j ON j.jobid = jrd.jobid
-- WHERE j.jobname = 'inactivity-cleanup-daily'
-- ORDER BY jrd.start_time DESC
-- LIMIT 10;

-- To unschedule the job:
-- SELECT cron.unschedule('inactivity-cleanup-daily');
