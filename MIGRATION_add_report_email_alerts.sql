-- ========================================
-- Migration: Add Email Alerts for Reports
-- ========================================
-- This migration sets up automatic email notifications when new reports are created.
--
-- REQUIREMENTS:
-- 1. Deploy the send-report-alert Edge Function
-- 2. Configure ADMIN_EMAIL environment variable in Supabase
-- 3. Configure RESEND_API_KEY environment variable (or another email service)
--
-- Run this AFTER MIGRATION_add_reports.sql
-- ========================================

-- ========================================
-- STEP 1: Create Database Function to Call Edge Function
-- ========================================

-- This function is triggered whenever a new report is inserted
CREATE OR REPLACE FUNCTION notify_admin_of_new_report()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    request_id bigint;
BEGIN
    -- Call the Edge Function via pg_net (HTTP request from database)
    -- Note: pg_net extension must be enabled in Supabase
    SELECT net.http_post(
        url := current_setting('app.settings.supabase_url') || '/functions/v1/send-report-alert',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body := jsonb_build_object(
            'record', row_to_json(NEW)
        )
    ) INTO request_id;

    -- Log the request (optional)
    RAISE NOTICE 'Report alert HTTP request: %', request_id;

    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error but don't fail the report creation
        RAISE WARNING 'Failed to send report alert: %', SQLERRM;
        RETURN NEW;
END;
$$;

-- ========================================
-- STEP 2: Create Trigger on Reports Table
-- ========================================

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_report_created ON reports;

-- Create trigger that fires after INSERT on reports table
CREATE TRIGGER on_report_created
    AFTER INSERT ON reports
    FOR EACH ROW
    EXECUTE FUNCTION notify_admin_of_new_report();

-- ========================================
-- ALTERNATIVE: Using Database Webhooks (Easier Setup)
-- ========================================

-- Instead of using pg_net, you can use Supabase Database Webhooks
-- in the Supabase Dashboard:
--
-- 1. Go to Database → Webhooks in Supabase Dashboard
-- 2. Click "Create a new hook"
-- 3. Configure:
--    - Name: "report-created-alert"
--    - Table: "reports"
--    - Events: "INSERT"
--    - Type: "Supabase Edge Functions"
--    - Edge Function: "send-report-alert"
-- 4. Save
--
-- This is easier than the trigger approach above!

-- ========================================
-- STEP 3: Configure Environment Variables
-- ========================================

-- In Supabase Dashboard → Settings → Edge Functions → Environment Variables:
--
-- 1. ADMIN_EMAIL
--    Value: your-email@example.com
--    Description: Email address to receive report alerts
--
-- 2. RESEND_API_KEY (if using Resend for email)
--    Value: re_xxxxxxxxxxxxx
--    Description: API key from resend.com
--
-- Alternative email services:
-- - SendGrid: Use SENDGRID_API_KEY
-- - Postmark: Use POSTMARK_API_KEY
-- - AWS SES: Use AWS credentials
-- - SMTP: Use SMTP credentials

-- ========================================
-- STEP 4: Deploy Edge Function
-- ========================================

-- In your terminal:
-- supabase functions deploy send-report-alert

-- ========================================
-- TESTING
-- ========================================

-- Test by creating a report:
-- INSERT INTO reports (reporter_id, reported_type, reported_id, reason_category, reason_details)
-- VALUES (auth.uid(), 'user', 'some-user-id', 'spam', 'Test report for email alert');

-- You should receive an email at ADMIN_EMAIL with report details

-- ========================================
-- CLEANUP (if needed)
-- ========================================

-- To remove the trigger:
-- DROP TRIGGER IF EXISTS on_report_created ON reports;
-- DROP FUNCTION IF EXISTS notify_admin_of_new_report();

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON FUNCTION notify_admin_of_new_report IS 'Sends email alert to admin when a new report is created';
