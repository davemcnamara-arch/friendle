-- ========================================
-- Migration: Add Reporting Feature
-- ========================================
-- This migration adds a reports table to allow users to report problematic
-- content/behavior to administrators for moderation.
--
-- Users can report:
-- - Other users (harassment, fake profiles, spam)
-- - Messages (inappropriate content, harassment)
-- - Circles (spam, inappropriate)
-- - Events (spam, inappropriate)
--
-- IMPORTANT: This migration is safe to run on existing data.
-- It will not delete or modify any existing rows.
--
-- Run this migration in your Supabase SQL Editor.
-- ========================================

-- Create reports table
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reported_type TEXT NOT NULL CHECK (reported_type IN ('user', 'message', 'circle', 'event')),
    reported_id UUID NOT NULL,
    reason_category TEXT NOT NULL CHECK (reason_category IN (
        'harassment',
        'spam',
        'inappropriate_content',
        'fake_profile',
        'threatening_behavior',
        'other'
    )),
    reason_details TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',
        'under_review',
        'resolved',
        'dismissed'
    )),
    admin_notes TEXT,
    reviewed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient lookups
CREATE INDEX IF NOT EXISTS idx_reports_reporter
ON reports(reporter_id);

CREATE INDEX IF NOT EXISTS idx_reports_reported
ON reports(reported_type, reported_id);

CREATE INDEX IF NOT EXISTS idx_reports_status
ON reports(status);

CREATE INDEX IF NOT EXISTS idx_reports_created
ON reports(created_at DESC);

-- Enable RLS on reports table
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- ========================================
-- REPORTS TABLE POLICIES
-- ========================================

-- Users can read their own reports
DROP POLICY IF EXISTS "Users can read own reports" ON reports;
CREATE POLICY "Users can read own reports"
ON reports FOR SELECT
USING (reporter_id = auth.uid());

-- Users can create reports
DROP POLICY IF EXISTS "Users can create reports" ON reports;
CREATE POLICY "Users can create reports"
ON reports FOR INSERT
WITH CHECK (
    reporter_id = auth.uid()
    AND status = 'pending' -- New reports must start as pending
);

-- Users can update only the details of their pending reports (not status)
DROP POLICY IF EXISTS "Users can update own pending reports" ON reports;
CREATE POLICY "Users can update own pending reports"
ON reports FOR UPDATE
USING (
    reporter_id = auth.uid()
    AND status = 'pending'
)
WITH CHECK (
    reporter_id = auth.uid()
    AND status = 'pending' -- Can't change status
);

-- Note: Only admins (via service role) can update report status and admin_notes
-- This requires separate admin tooling outside of RLS

-- ========================================
-- Helper function to get report context
-- ========================================

-- This function helps retrieve context about a report for admin review
CREATE OR REPLACE FUNCTION get_report_context(report_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    report_record RECORD;
    context JSON;
BEGIN
    -- Get the report
    SELECT * INTO report_record FROM reports WHERE id = report_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Build context based on reported type
    CASE report_record.reported_type
        WHEN 'user' THEN
            SELECT json_build_object(
                'report', row_to_json(report_record),
                'reported_user', row_to_json(p),
                'reporter', row_to_json(r)
            ) INTO context
            FROM profiles p, profiles r
            WHERE p.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        WHEN 'message' THEN
            -- Try to find in match_messages, event_messages, or circle_messages
            SELECT json_build_object(
                'report', row_to_json(report_record),
                'message', COALESCE(
                    (SELECT row_to_json(mm) FROM match_messages mm WHERE mm.id = report_record.reported_id),
                    (SELECT row_to_json(em) FROM event_messages em WHERE em.id = report_record.reported_id),
                    (SELECT row_to_json(cm) FROM circle_messages cm WHERE cm.id = report_record.reported_id)
                ),
                'reporter', row_to_json(r)
            ) INTO context
            FROM profiles r
            WHERE r.id = report_record.reporter_id;

        WHEN 'circle' THEN
            SELECT json_build_object(
                'report', row_to_json(report_record),
                'circle', row_to_json(c),
                'reporter', row_to_json(r)
            ) INTO context
            FROM circles c, profiles r
            WHERE c.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        WHEN 'event' THEN
            SELECT json_build_object(
                'report', row_to_json(report_record),
                'event', row_to_json(e),
                'reporter', row_to_json(r)
            ) INTO context
            FROM events e, profiles r
            WHERE e.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        ELSE
            context := json_build_object('report', row_to_json(report_record));
    END CASE;

    RETURN context;
END;
$$;

-- ========================================
-- Grant necessary permissions
-- ========================================

GRANT SELECT, INSERT, UPDATE ON reports TO authenticated;

-- ========================================
-- Verification Query
-- ========================================

-- Run this to verify policies were created successfully:
SELECT
    schemaname,
    tablename,
    policyname,
    cmd as command
FROM pg_policies
WHERE tablename = 'reports'
ORDER BY policyname;

-- Expected result: You should see 3 policies for reports

-- ========================================
-- TESTING INSTRUCTIONS
-- ========================================

-- After running this migration, test the following:

-- 1. Test that users can create reports:
--    INSERT INTO reports (reporter_id, reported_type, reported_id, reason_category, reason_details)
--    VALUES (auth.uid(), 'user', 'some-user-id', 'spam', 'This user is sending spam messages');

-- 2. Test that users can see their own reports:
--    SELECT * FROM reports WHERE reporter_id = auth.uid();

-- 3. Test that users cannot see other users' reports:
--    SELECT * FROM reports WHERE reporter_id != auth.uid();
--    (Should return empty)

-- 4. Test that users cannot change report status:
--    UPDATE reports SET status = 'resolved' WHERE id = 'some-report-id';
--    (Should fail or not update status)

-- 5. Test the context function (as admin):
--    SELECT get_report_context('some-report-id');

-- ========================================
-- ADMIN USAGE
-- ========================================

-- Admins should use the service role key to:

-- 1. Get all pending reports:
--    SELECT * FROM reports WHERE status = 'pending' ORDER BY created_at DESC;

-- 2. Get report with full context:
--    SELECT get_report_context('report-id');

-- 3. Update report status:
--    UPDATE reports
--    SET status = 'resolved',
--        admin_notes = 'User was warned',
--        reviewed_by = 'admin-profile-id',
--        reviewed_at = NOW()
--    WHERE id = 'report-id';

-- 4. Get report statistics:
--    SELECT
--        status,
--        reported_type,
--        reason_category,
--        COUNT(*) as count
--    FROM reports
--    GROUP BY status, reported_type, reason_category
--    ORDER BY count DESC;

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON TABLE reports IS 'RLS enabled: Users can report problematic content/behavior for admin review';
COMMENT ON FUNCTION get_report_context IS 'Helper function to retrieve full context about a report for admin review';
