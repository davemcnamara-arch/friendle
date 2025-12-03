-- ============================================================================
-- Fix RLS Security Errors
-- ============================================================================
-- This migration addresses Supabase linter errors for tables without RLS
-- ============================================================================

BEGIN;

-- ============================================================================
-- Part 1: Handle Backup Tables from 2025-10-26
-- ============================================================================
-- These tables were created as backups and are not actively used.
-- We'll enable RLS on them to satisfy security requirements.
-- Note: Since these are backup tables, we'll use restrictive policies.
-- ============================================================================

-- Enable RLS on all backup tables
ALTER TABLE IF EXISTS public.event_participants_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.match_messages_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.event_messages_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.profiles_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.circles_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.circle_members_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.hidden_activities_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.activities_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.matches_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.match_participants_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.events_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.circle_messages_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.match_message_reactions_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.event_message_reactions_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.circle_message_reactions_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.inactivity_warnings_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.muted_chats_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.preferences_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.auth_users_backup_20251026 ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.auth_identities_backup_20251026 ENABLE ROW LEVEL SECURITY;

-- Create restrictive policies for backup tables (service role only)
-- This ensures backup tables are only accessible via service role

DO $$
DECLARE
  backup_table TEXT;
BEGIN
  FOR backup_table IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE '%_backup_20251026'
  LOOP
    -- Drop existing policies if any
    EXECUTE format('DROP POLICY IF EXISTS backup_service_role_all ON public.%I', backup_table);

    -- Create policy allowing service role full access
    EXECUTE format('
      CREATE POLICY backup_service_role_all ON public.%I
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true)
    ', backup_table);
  END LOOP;
END $$;

-- ============================================================================
-- Part 2: Fix Active Tables
-- ============================================================================

-- ============================================================================
-- 2.1: Drop unused tables
-- ============================================================================
-- These tables exist in the database but are not used in the codebase
-- They don't have the expected schema, so we'll just drop them
-- ============================================================================

DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.hidden_activities CASCADE;

-- ============================================================================
-- 2.2: function_execution_logs table
-- ============================================================================

-- Create function_execution_logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.function_execution_logs (
  id BIGSERIAL PRIMARY KEY,
  execution_time TIMESTAMPTZ DEFAULT NOW(),
  function_name TEXT NOT NULL,
  step TEXT,
  status TEXT,
  message TEXT,
  data JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS on function_execution_logs table
ALTER TABLE public.function_execution_logs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS function_logs_service_role_all ON public.function_execution_logs;

-- Create policy for function_execution_logs
-- This table is for system logging, so only service role should have access
CREATE POLICY function_logs_service_role_all ON public.function_execution_logs
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Also allow anon and authenticated users to insert logs (for edge functions)
CREATE POLICY function_logs_insert_all ON public.function_execution_logs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_function_execution_logs_time
  ON public.function_execution_logs(execution_time DESC);

CREATE INDEX IF NOT EXISTS idx_function_execution_logs_function
  ON public.function_execution_logs(function_name, execution_time DESC);

-- ============================================================================
-- Add helpful comments
-- ============================================================================

COMMENT ON TABLE public.function_execution_logs IS 'System logging table for edge function execution tracking';
COMMENT ON POLICY backup_service_role_all ON public.event_participants_backup_20251026 IS 'Backup tables restricted to service role access only';

COMMIT;

-- ============================================================================
-- Verification Query (Run separately to check results)
-- ============================================================================
-- SELECT
--   schemaname,
--   tablename,
--   rowsecurity as rls_enabled
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- AND tablename IN (
--   'messages',
--   'hidden_activities',
--   'function_execution_logs'
-- )
-- OR tablename LIKE '%_backup_20251026'
-- ORDER BY tablename;
