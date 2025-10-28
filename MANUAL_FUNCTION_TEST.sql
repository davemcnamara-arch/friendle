-- Manual test: Call the function via SQL and capture response
-- This should show us what the function is actually returning

-- First check: Can we reach the function at all?
DO $$
DECLARE
  response_id bigint;
BEGIN
  -- Call the function
  SELECT net.http_post(
    url := 'https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/event-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt4c2V3a2piaHh0ZnFieXRmdGJ1Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODg1MTg4NCwiZXhwIjoyMDc0NDI3ODg0fQ.WjXsHa36bF6Strbt2oVkvbCxl5PAEA_AUbn4UO-XF8Y'
    ),
    body := '{}'::jsonb
  ) INTO response_id;

  RAISE NOTICE 'HTTP request ID: %', response_id;
END $$;

-- Then check if any logs were created in the last minute
SELECT
  execution_time,
  step,
  status,
  message,
  data
FROM function_execution_logs
WHERE execution_time > NOW() - INTERVAL '2 minutes'
ORDER BY execution_time DESC;
