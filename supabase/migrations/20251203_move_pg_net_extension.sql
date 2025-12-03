-- ========================================
-- Migration: Move pg_net Extension to Extensions Schema
-- ========================================
-- This migration moves the pg_net extension from the public schema
-- to a dedicated extensions schema to follow security best practices.
--
-- This fixes the Supabase linter warning:
-- "Extension pg_net is installed in the public schema. Move it to another schema."
--
-- Reference: https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public
-- ========================================

-- Create extensions schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Move pg_net extension to extensions schema
-- Note: We need to drop and recreate the extension because
-- PostgreSQL doesn't support moving extensions between schemas
DROP EXTENSION IF EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- Grant usage on the extensions schema to authenticated users
GRANT USAGE ON SCHEMA extensions TO authenticated;
GRANT USAGE ON SCHEMA extensions TO service_role;

-- ========================================
-- Migration Complete
-- ========================================

COMMENT ON SCHEMA extensions IS 'Schema for PostgreSQL extensions to keep them separate from application tables';
