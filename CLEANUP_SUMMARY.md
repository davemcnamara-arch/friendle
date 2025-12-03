# Database Cleanup - Obsolete Tables Removed

## Summary
Removed 22 obsolete tables to free up database storage and reduce maintenance overhead.

## What Was Removed

### 1. Backup Tables (21 tables)
All backup tables created on October 26, 2025 (~5 weeks old):

- `event_participants_backup_20251026`
- `match_messages_backup_20251026` ⚠️ Obsolete - original table was dropped
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
- `match_message_reactions_backup_20251026` ⚠️ Obsolete - original table was dropped
- `event_message_reactions_backup_20251026`
- `circle_message_reactions_backup_20251026`
- `inactivity_warnings_backup_20251026`
- `muted_chats_backup_20251026`
- `preferences_backup_20251026`
- `auth_users_backup_20251026`
- `auth_identities_backup_20251026`

⚠️ **Note:** Some backup tables backed up data that no longer exists in the current schema:
- `match_messages` and `match_message_reactions` tables were removed in the "remove match chat" migration
- Backing up these obsolete tables was unnecessary

### 2. Unused Generic Table (1 table)
- `messages` - Generic messages table that exists in database but is not used in the codebase
  - The app uses specific message tables instead: `event_messages`, `circle_messages`

## Migration File
`supabase/migrations/20251203_cleanup_obsolete_tables.sql`

## How to Apply

### Via Supabase Dashboard (Recommended)
1. Go to SQL Editor: https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new
2. Copy contents of `supabase/migrations/20251203_cleanup_obsolete_tables.sql`
3. Paste and run

### Via Supabase CLI
```bash
supabase db push
```

## Benefits

✅ **Freed up database storage** - Removed 22 obsolete tables
✅ **Reduced complexity** - Fewer tables to maintain and backup
✅ **Cleaner schema** - Removed tables that backed up data that no longer exists
✅ **Better security** - Fewer attack surfaces and data exposure points

## Important Note

⚠️ **This action is irreversible!**

The backup tables from October 26, 2025 will be permanently deleted. If you need any data from these backups, extract it BEFORE running this migration.

To check backup table sizes before dropping:
```sql
SELECT
  tablename,
  pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
AND tablename LIKE '%_backup_20251026'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;
```

## Related Migrations

This cleanup should be run AFTER:
- ✅ `20251203_fix_rls_errors.sql` - Fixes RLS errors (including on backup tables)

The sequence:
1. First migration enables RLS on all tables (including backups)
2. This migration drops the backup tables and unused generic messages table

## What Remains

After this cleanup, your active tables will be:
- `profiles`
- `circles`
- `circle_members`
- `circle_messages`
- `hidden_activities`
- `activities`
- `matches`
- `match_participants`
- `events`
- `event_participants`
- `event_messages`
- `polls`
- `poll_votes`
- `event_message_reactions`
- `circle_message_reactions`
- `inactivity_warnings`
- `muted_chats`
- `preferences`
- `function_execution_logs`

All with proper RLS policies and security measures in place!
