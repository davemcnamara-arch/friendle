# Manual Database Backup Guide (No Supabase UI Backups)

If you don't see automatic backups in your Supabase dashboard, you're likely on the **Free tier** which has limited backup visibility. Don't worry - here are several ways to create your own backup before running the reset.

---

## Option 1: SQL Export via Supabase Dashboard (RECOMMENDED)

This is the easiest method and works on all plans.

### Steps:

1. Go to your SQL Editor:
   ```
   https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/sql/new
   ```

2. Copy and paste this backup script:

```sql
-- ============================================================================
-- FRIENDLE DATA BACKUP - Run this BEFORE reset
-- ============================================================================
-- This creates backup tables with a timestamp suffix
-- You can restore from these if needed
-- ============================================================================

BEGIN;

-- Create backup tables with current data
CREATE TABLE profiles_backup_20251026 AS SELECT * FROM profiles;
CREATE TABLE circles_backup_20251026 AS SELECT * FROM circles;
CREATE TABLE circle_members_backup_20251026 AS SELECT * FROM circle_members;
CREATE TABLE activities_backup_20251026 AS SELECT * FROM activities;
CREATE TABLE matches_backup_20251026 AS SELECT * FROM matches;
CREATE TABLE match_participants_backup_20251026 AS SELECT * FROM match_participants;
CREATE TABLE events_backup_20251026 AS SELECT * FROM events;
CREATE TABLE event_participants_backup_20251026 AS SELECT * FROM event_participants;
CREATE TABLE match_messages_backup_20251026 AS SELECT * FROM match_messages;
CREATE TABLE event_messages_backup_20251026 AS SELECT * FROM event_messages;
CREATE TABLE circle_messages_backup_20251026 AS SELECT * FROM circle_messages;
CREATE TABLE match_message_reactions_backup_20251026 AS SELECT * FROM match_message_reactions;
CREATE TABLE event_message_reactions_backup_20251026 AS SELECT * FROM event_message_reactions;
CREATE TABLE circle_message_reactions_backup_20251026 AS SELECT * FROM circle_message_reactions;
CREATE TABLE inactivity_warnings_backup_20251026 AS SELECT * FROM inactivity_warnings;
CREATE TABLE muted_chats_backup_20251026 AS SELECT * FROM muted_chats;
CREATE TABLE preferences_backup_20251026 AS SELECT * FROM preferences;

-- Backup auth users (important!)
CREATE TABLE auth_users_backup_20251026 AS SELECT * FROM auth.users;
CREATE TABLE auth_identities_backup_20251026 AS SELECT * FROM auth.identities;

COMMIT;

-- Verify backups were created
SELECT
  'profiles' as table_name,
  (SELECT COUNT(*) FROM profiles) as original,
  (SELECT COUNT(*) FROM profiles_backup_20251026) as backup
UNION ALL
SELECT 'circles', COUNT(*), (SELECT COUNT(*) FROM circles_backup_20251026) FROM circles
UNION ALL
SELECT 'matches', COUNT(*), (SELECT COUNT(*) FROM matches_backup_20251026) FROM matches
UNION ALL
SELECT 'events', COUNT(*), (SELECT COUNT(*) FROM events_backup_20251026) FROM events
UNION ALL
SELECT 'auth.users', COUNT(*), (SELECT COUNT(*) FROM auth_users_backup_20251026) FROM auth.users;

-- Expected: original and backup counts should match
```

3. Click **"Run"**

4. Verify the counts match in the results

**Storage required:** Only the actual data size (likely <100MB for dev/testing)

**Restore time:** 5 minutes

---

## Option 2: Export to CSV Files

If you want backups outside of Supabase:

### Using Supabase SQL Editor:

```sql
-- Note: This shows you the data, which you can copy/paste to CSV
-- Not ideal for large datasets, but works for small dev databases

SELECT * FROM profiles;
-- Copy results, save as profiles.csv

SELECT * FROM circles;
-- Copy results, save as circles.csv

-- Repeat for all tables...
```

**Limitation:** Manual and tedious, but works for small amounts of data

---

## Option 3: pg_dump (If You Have Connection String)

If you have your database connection details:

### Steps:

1. Get your database credentials:
   - Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/settings/database
   - Look for "Connection string" or "Direct connection"
   - Copy the connection details

2. Run pg_dump (requires PostgreSQL client installed):

```bash
# Full database backup (schema + data)
pg_dump "postgresql://postgres:[PASSWORD]@db.kxsewkjbhxtfqbytftbu.supabase.co:5432/postgres" \
  -f friendle_full_backup_$(date +%Y%m%d).sql

# Or just data (no schema)
pg_dump "postgresql://postgres:[PASSWORD]@db.kxsewkjbhxtfqbytftbu.supabase.co:5432/postgres" \
  --data-only \
  -f friendle_data_backup_$(date +%Y%m%d).sql
```

**Storage:** Creates a .sql file you can restore from

**Restore command:**
```bash
psql "postgresql://postgres:[PASSWORD]@db.kxsewkjbhxtfqbytftbu.supabase.co:5432/postgres" \
  -f friendle_data_backup_20251026.sql
```

---

## Option 4: Supabase CLI

Using the Supabase command-line tool:

### Setup:

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link to your project
supabase link --project-ref kxsewkjbhxtfqbytftbu
```

### Backup:

```bash
# Dump database
supabase db dump -f friendle_backup.sql

# Or specific table
supabase db dump --table profiles -f profiles_backup.sql
```

### Restore:

```bash
supabase db push --dry-run -f friendle_backup.sql  # Preview
supabase db push -f friendle_backup.sql             # Actual restore
```

---

## 🎯 RECOMMENDED: Option 1 (SQL Backup Tables)

**Why I recommend this:**

✅ **Fast:** Creates backup in 5 seconds
✅ **Easy:** Just copy/paste SQL and run
✅ **Safe:** Backup lives in same database (won't lose it)
✅ **Quick restore:** Simple INSERT statements to restore
✅ **No external tools needed:** Works entirely in Supabase Dashboard

**Downside:**
- Uses database storage (minimal for dev data)
- If entire Supabase project is deleted, backup is lost too
- For production, you'd want off-site backups

**For beta testing prep, this is perfect.**

---

## 📋 Restore Procedure (If Using Backup Tables)

If you need to restore after running the reset:

```sql
BEGIN;

-- Restore auth users FIRST (other tables depend on this)
INSERT INTO auth.users SELECT * FROM auth_users_backup_20251026;
INSERT INTO auth.identities SELECT * FROM auth_identities_backup_20251026;

-- Restore profiles
INSERT INTO profiles SELECT * FROM profiles_backup_20251026;

-- Restore circles
INSERT INTO circles SELECT * FROM circles_backup_20251026;

-- Restore circle members
INSERT INTO circle_members SELECT * FROM circle_members_backup_20251026;

-- Restore activities
INSERT INTO activities SELECT * FROM activities_backup_20251026;

-- Restore matches
INSERT INTO matches SELECT * FROM matches_backup_20251026;

-- Restore match participants
INSERT INTO match_participants SELECT * FROM match_participants_backup_20251026;

-- Restore events
INSERT INTO events SELECT * FROM events_backup_20251026;

-- Restore event participants
INSERT INTO event_participants SELECT * FROM event_participants_backup_20251026;

-- Restore messages
INSERT INTO match_messages SELECT * FROM match_messages_backup_20251026;
INSERT INTO event_messages SELECT * FROM event_messages_backup_20251026;
INSERT INTO circle_messages SELECT * FROM circle_messages_backup_20251026;

-- Restore reactions
INSERT INTO match_message_reactions SELECT * FROM match_message_reactions_backup_20251026;
INSERT INTO event_message_reactions SELECT * FROM event_message_reactions_backup_20251026;
INSERT INTO circle_message_reactions SELECT * FROM circle_message_reactions_backup_20251026;

-- Restore system tables
INSERT INTO inactivity_warnings SELECT * FROM inactivity_warnings_backup_20251026;
INSERT INTO muted_chats SELECT * FROM muted_chats_backup_20251026;
INSERT INTO preferences SELECT * FROM preferences_backup_20251026;

COMMIT;

-- Verify restoration
SELECT COUNT(*) as profiles FROM profiles;
SELECT COUNT(*) as circles FROM circles;
SELECT COUNT(*) as auth_users FROM auth.users;
```

**Restore time:** ~2 minutes

---

## 🧹 Cleanup (After Successful Beta Launch)

Once you're confident the reset worked and beta is going well:

```sql
-- Drop all backup tables to free up space
DROP TABLE profiles_backup_20251026;
DROP TABLE circles_backup_20251026;
DROP TABLE circle_members_backup_20251026;
DROP TABLE activities_backup_20251026;
DROP TABLE matches_backup_20251026;
DROP TABLE match_participants_backup_20251026;
DROP TABLE events_backup_20251026;
DROP TABLE event_participants_backup_20251026;
DROP TABLE match_messages_backup_20251026;
DROP TABLE event_messages_backup_20251026;
DROP TABLE circle_messages_backup_20251026;
DROP TABLE match_message_reactions_backup_20251026;
DROP TABLE event_message_reactions_backup_20251026;
DROP TABLE circle_message_reactions_backup_20251026;
DROP TABLE inactivity_warnings_backup_20251026;
DROP TABLE muted_chats_backup_20251026;
DROP TABLE preferences_backup_20251026;
DROP TABLE auth_users_backup_20251026;
DROP TABLE auth_identities_backup_20251026;
```

---

## ⚠️ Important Notes

### Storage Bucket (Avatars)

**The backup tables do NOT backup uploaded files** (profile pictures in storage).

To backup storage:
1. Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/storage/buckets/avatars
2. Manually download important images (if any)

**For beta:** You're starting fresh, so old avatars aren't critical.

### Auth Users Caveat

Restoring auth.users is tricky because:
- Password hashes need to be preserved
- Sessions might be invalid
- Users may need to re-login

**Recommendation:** If you restore auth users, tell users to log out and back in.

---

## 🚀 Your Reset Workflow (With Backup)

### Step 1: Create Backup (5 minutes)
```
Run the SQL backup script above
Verify counts match
```

### Step 2: Run Reset (2 minutes)
```
Run RESET_EVERYTHING.sql
Verify all tables show 0 rows
```

### Step 3: Test Fresh (10 minutes)
```
Sign up new user
Create circle
Test core features
```

### Step 4: Keep or Restore (1 minute decision)
```
If everything works: Drop backup tables
If something broke: Run restore script
```

**Total time:** 20 minutes max

---

## 📞 Questions?

If you have issues with any of these backup methods:
1. Try Option 1 first (backup tables) - it's the most reliable
2. Check Supabase docs: https://supabase.com/docs/guides/database/backups
3. Contact Supabase support for plan-specific backup features

---

## ✅ Ready to Proceed?

Once you've run the backup script and verified the counts match, you're safe to run the reset!
