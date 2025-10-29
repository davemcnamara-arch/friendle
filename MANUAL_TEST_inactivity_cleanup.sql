-- Manual Test: Trigger inactivity-cleanup Edge Function
-- Use this to manually test the inactivity cleanup without waiting for the cron job

-- MANUAL TRIGGER: Direct HTTP call to the edge function
SELECT net.http_post(
  url := 'https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/inactivity-cleanup',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4c2V3a2piaHh0ZnFieXRmdGJ1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODg1MTg4NCwiZXhwIjoyMDc0NDI3ODg0fQ.WjXsHa36bF6Strbt2oVkvbCxl5PAEA_AUbn4UO-XF8Y'
  ),
  body := '{}'::jsonb
) as request_id;

-- View scheduled cron job details
SELECT jobid, jobname, schedule, active
FROM cron.job
WHERE jobname = 'inactivity-cleanup-daily';

-- View cron job execution history (joined with job table to get job name)
SELECT
  jrd.jobid,
  j.jobname,
  jrd.runid,
  jrd.start_time,
  jrd.end_time,
  jrd.status,
  jrd.return_message
FROM cron.job_run_details jrd
JOIN cron.job j ON j.jobid = jrd.jobid
WHERE j.jobname = 'inactivity-cleanup-daily'
ORDER BY jrd.start_time DESC
LIMIT 10;

-- Check for participants who would get Day 5 warnings
SELECT
  mp.id,
  mp.match_id,
  mp.profile_id,
  p.name,
  mp.last_interaction_at,
  NOW() - mp.last_interaction_at as inactive_duration
FROM match_participants mp
JOIN profiles p ON p.id = mp.profile_id
WHERE mp.status = 'active'
  AND mp.last_interaction_at < NOW() - INTERVAL '5 days'
  AND NOT EXISTS (
    SELECT 1 FROM inactivity_warnings iw
    WHERE iw.match_id = mp.match_id
      AND iw.profile_id = mp.profile_id
      AND iw.status = 'pending'
  )
ORDER BY mp.last_interaction_at ASC;

-- Check for participants who would be auto-removed (Day 7)
SELECT
  mp.id,
  mp.match_id,
  mp.profile_id,
  p.name,
  mp.last_interaction_at,
  NOW() - mp.last_interaction_at as inactive_duration,
  iw.warned_at,
  NOW() - iw.warned_at as time_since_warning
FROM match_participants mp
JOIN profiles p ON p.id = mp.profile_id
JOIN inactivity_warnings iw ON iw.match_id = mp.match_id AND iw.profile_id = mp.profile_id
WHERE mp.status = 'active'
  AND iw.status = 'pending'
  AND mp.last_interaction_at < NOW() - INTERVAL '7 days'
ORDER BY mp.last_interaction_at ASC;
