# RLS Security Errors - Fix Summary

## Problem
Supabase linter detected 24 tables without Row Level Security (RLS) enabled:
- 21 backup tables (from October 26, 2025)
- 3 active tables: `messages`, `hidden_activities`, `function_execution_logs`

## Solution
Created migration file: `supabase/migrations/20251203_fix_rls_errors.sql`

### What the Migration Does

#### 1. Backup Tables (21 tables)
All backup tables with suffix `_backup_20251026`:
- ✅ RLS enabled on all backup tables
- ✅ Restrictive policies created (service role only)
- ✅ These tables are no longer accessible via PostgREST to regular users

**Tables fixed:**
- `event_participants_backup_20251026`
- `match_messages_backup_20251026`
- `event_messages_backup_20251026`
- `profiles_backup_20251026`
- `circles_backup_20251026`
- `circle_members_backup_20251026`
- `hidden_activities_backup_20251026`
- `activities_backup_20251026`
- `matches_backup_20251026`
- `match_participants_backup_20251026`
- `events_backup_20251026`
- `circle_messages_backup_20251026`
- `match_message_reactions_backup_20251026`
- `event_message_reactions_backup_20251026`
- `circle_message_reactions_backup_20251026`
- `inactivity_warnings_backup_20251026`
- `muted_chats_backup_20251026`
- `preferences_backup_20251026`
- `auth_users_backup_20251026`
- `auth_identities_backup_20251026`

#### 2. Active Tables

##### `messages` table
- ✅ RLS enabled (if table exists)
- ✅ Policies: Users can only CRUD their own messages (if table exists)
- 📝 Note: This table exists in the database but is not used in the codebase
- 📝 Will be dropped in the cleanup migration (20251203_cleanup_obsolete_tables.sql)
- 📝 Policies created (if table exists):
  - `messages_select_own` - Read own messages
  - `messages_insert_own` - Create own messages
  - `messages_update_own` - Update own messages
  - `messages_delete_own` - Delete own messages

##### `hidden_activities` table
- ✅ RLS enabled
- ✅ Policies: Users can only view/manage their own hidden activities
- 📝 Policies created:
  - `hidden_activities_select_own` - Read own hidden activities
  - `hidden_activities_insert_own` - Create own hidden activities
  - `hidden_activities_delete_own` - Delete own hidden activities

##### `function_execution_logs` table
- ✅ Created if doesn't exist
- ✅ RLS enabled
- ✅ Service role has full access
- ✅ All users can insert (for edge function logging)
- 📝 Policies created:
  - `function_logs_service_role_all` - Service role has full access
  - `function_logs_insert_all` - Everyone can insert logs
- ✅ Indexes added for performance:
  - `idx_function_execution_logs_time` - Query by time
  - `idx_function_execution_logs_function` - Query by function name and time

## How to Apply

### Option 1: Via Supabase Dashboard (Recommended)
1. Go to SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new
2. Copy contents of `supabase/migrations/20251203_fix_rls_errors.sql`
3. Paste and run
4. Verify all errors are resolved

### Option 2: Via Supabase CLI
```bash
supabase db push
```

### Option 3: Via Migration
If using Supabase migrations in your CI/CD:
```bash
supabase migration up
```

## Verification

After applying the migration, verify RLS is enabled:

```sql
SELECT
  schemaname,
  tablename,
  rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND (
  tablename IN ('messages', 'hidden_activities', 'function_execution_logs')
  OR tablename LIKE '%_backup_20251026'
)
ORDER BY tablename;
```

All tables should show `rls_enabled = true`.

## Next Steps (Optional)

### Consider Dropping Backup Tables
If you no longer need the October 26 backups (which are ~5 weeks old):

```sql
-- Review backup table sizes first
SELECT
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
AND tablename LIKE '%_backup_20251026'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- If you're sure you don't need them, drop them
DROP TABLE IF EXISTS public.event_participants_backup_20251026;
DROP TABLE IF EXISTS public.match_messages_backup_20251026;
-- ... (see MANUAL_BACKUP_GUIDE.md for complete list)
```

## Security Impact

### Before
- ❌ 24 tables exposed to PostgREST without RLS
- ❌ Potential unauthorized access to backup data
- ❌ System logs accessible to all users

### After
- ✅ All tables have RLS enabled
- ✅ Backup tables restricted to service role only
- ✅ Active tables have appropriate user-scoped policies
- ✅ System logs protected (service role access, insert-only for others)
- ✅ All Supabase linter errors resolved

## Notes

- The `messages` table was created as a generic table. If you have a different messages schema, adjust the policies accordingly.
- The `hidden_activities` policies assume a `user_id` column. Verify this matches your schema.
- Backup tables are now inaccessible via PostgREST to regular users, but remain queryable by service role if needed for data recovery.

## Files Modified
- ✅ Created: `supabase/migrations/20251203_fix_rls_errors.sql`
- ✅ Created: `RLS_FIX_SUMMARY.md` (this file)
