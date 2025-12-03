-- ========================================
-- Migration: Fix Function Search Path Security
-- ========================================
-- This migration adds search_path restrictions to SECURITY DEFINER functions
-- to prevent search path manipulation attacks (CVE-2018-1058 class vulnerabilities).
--
-- The search_path parameter ensures that functions always use fully qualified
-- object names and aren't vulnerable to malicious schema manipulation.
--
-- This fixes the Supabase linter warning:
-- "Function has a role mutable search_path"
-- ========================================

-- Fix is_blocked_in_match function
CREATE OR REPLACE FUNCTION is_blocked_in_match(user_id UUID, check_match_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM public.match_participants WHERE match_id = check_match_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM public.match_participants WHERE match_id = check_match_id
      ))
    )
  );
END;
$$;

-- Fix is_blocked_in_event function
CREATE OR REPLACE FUNCTION is_blocked_in_event(user_id UUID, check_event_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM public.event_participants WHERE event_id = check_event_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM public.event_participants WHERE event_id = check_event_id
      ))
    )
  );
END;
$$;

-- Fix is_blocked_in_circle function
CREATE OR REPLACE FUNCTION is_blocked_in_circle(user_id UUID, check_circle_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.blocked_users bu
    WHERE (
      (bu.blocker_id = user_id AND bu.blocked_id IN (
        SELECT profile_id FROM public.circle_members WHERE circle_id = check_circle_id
      ))
      OR (bu.blocked_id = user_id AND bu.blocker_id IN (
        SELECT profile_id FROM public.circle_members WHERE circle_id = check_circle_id
      ))
    )
  );
END;
$$;

-- Fix get_report_context function
CREATE OR REPLACE FUNCTION get_report_context(report_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    report_record RECORD;
    context JSON;
BEGIN
    -- Get the report
    SELECT * INTO report_record FROM public.reports WHERE id = report_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- Build context based on reported type
    CASE report_record.reported_type
        WHEN 'user' THEN
            SELECT public.json_build_object(
                'report', public.row_to_json(report_record),
                'reported_user', public.row_to_json(p),
                'reporter', public.row_to_json(r)
            ) INTO context
            FROM public.profiles p, public.profiles r
            WHERE p.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        WHEN 'message' THEN
            -- Try to find in match_messages, event_messages, or circle_messages
            SELECT public.json_build_object(
                'report', public.row_to_json(report_record),
                'message', COALESCE(
                    (SELECT public.row_to_json(mm) FROM public.match_messages mm WHERE mm.id = report_record.reported_id),
                    (SELECT public.row_to_json(em) FROM public.event_messages em WHERE em.id = report_record.reported_id),
                    (SELECT public.row_to_json(cm) FROM public.circle_messages cm WHERE cm.id = report_record.reported_id)
                ),
                'reporter', public.row_to_json(r)
            ) INTO context
            FROM public.profiles r
            WHERE r.id = report_record.reporter_id;

        WHEN 'circle' THEN
            SELECT public.json_build_object(
                'report', public.row_to_json(report_record),
                'circle', public.row_to_json(c),
                'reporter', public.row_to_json(r)
            ) INTO context
            FROM public.circles c, public.profiles r
            WHERE c.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        WHEN 'event' THEN
            SELECT public.json_build_object(
                'report', public.row_to_json(report_record),
                'event', public.row_to_json(e),
                'reporter', public.row_to_json(r)
            ) INTO context
            FROM public.events e, public.profiles r
            WHERE e.id = report_record.reported_id
            AND r.id = report_record.reporter_id;

        ELSE
            context := public.json_build_object('report', public.row_to_json(report_record));
    END CASE;

    RETURN context;
END;
$$;

-- Restore function comments
COMMENT ON FUNCTION is_blocked_in_match IS 'Checks if a user has a block relationship with any participant in a match';
COMMENT ON FUNCTION is_blocked_in_event IS 'Checks if a user has a block relationship with any participant in an event';
COMMENT ON FUNCTION is_blocked_in_circle IS 'Checks if a user has a block relationship with any member in a circle';
COMMENT ON FUNCTION get_report_context IS 'Helper function to retrieve full context about a report for admin review';

-- ========================================
-- Migration Complete
-- ========================================
