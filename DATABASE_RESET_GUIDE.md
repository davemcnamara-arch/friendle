# Friendle Database Reset Guide for Beta Testing

This guide provides step-by-step instructions to completely wipe your Friendle database and prepare for beta testing.

## 📋 What Gets Deleted

### User Data (Will Be Deleted)
- ✅ All user profiles
- ✅ All circles and memberships
- ✅ All matches and participants
- ✅ All events and participants
- ✅ All messages (match, event, circle chats)
- ✅ All message reactions
- ✅ All user preferences
- ✅ All inactivity warnings
- ✅ All muted chats
- ✅ All user-created activities
- ✅ All profile pictures (avatar storage)
- ✅ All authentication users

### System Configuration (Preserved)
- ✅ Database schema and table structures
- ✅ RLS (Row Level Security) policies
- ✅ Database functions and triggers
- ✅ Edge Functions (event-reminders, inactivity-cleanup, etc.)
- ✅ Global activities (system defaults with circle_id = NULL)
- ✅ Storage bucket configuration
- ✅ OneSignal push notification settings

---

## 🚀 Quick Start (3 Steps)

### Step 1: Backup Current Database (Optional but Recommended)

Before wiping everything, create a backup:

1. Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/settings/general
2. Scroll to "Pause project" section
3. Click "Create backup" or use the automatic daily backups

### Step 2: Run Database Reset Script

1. Go to Supabase SQL Editor:
   ```
   https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/sql/new
   ```

2. Copy and paste the contents of `RESET_DATABASE_FOR_BETA.sql`

3. Click **"Run"** button

4. Wait for success message (should complete in < 5 seconds)

5. Verify all tables are empty by running the verification queries at the bottom of the script

### Step 3: Delete Authentication Users

**Option A: Via SQL (Recommended)**

1. In the same SQL Editor, create a new query

2. Copy and paste the contents of `RESET_AUTH_USERS.sql`

3. Click **"Run"** button

4. Verify with: `SELECT COUNT(*) FROM auth.users;` (should be 0)

**Option B: Via Dashboard UI**

1. Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/auth/users

2. Select all users (checkbox at top)

3. Click "Delete users" button

4. Confirm deletion

---

## 🧪 Verification Checklist

After completing the reset, verify everything is clean:

### 1. Check Database Tables

Run this query in SQL Editor:

```sql
SELECT
  (SELECT COUNT(*) FROM profiles) as profiles,
  (SELECT COUNT(*) FROM circles) as circles,
  (SELECT COUNT(*) FROM matches) as matches,
  (SELECT COUNT(*) FROM events) as events,
  (SELECT COUNT(*) FROM match_messages) as match_msgs,
  (SELECT COUNT(*) FROM event_messages) as event_msgs,
  (SELECT COUNT(*) FROM circle_messages) as circle_msgs,
  (SELECT COUNT(*) FROM storage.objects WHERE bucket_id = 'avatars') as avatars;
```

**Expected Result:** All values should be `0`

### 2. Check Authentication

```sql
SELECT COUNT(*) FROM auth.users;
```

**Expected Result:** `0`

### 3. Check Global Activities Preserved

```sql
SELECT id, name, circle_id FROM activities WHERE circle_id IS NULL ORDER BY name;
```

**Expected Result:** Should show your default activity templates (Basketball, Soccer, etc.)

### 4. Check RLS Policies Intact

```sql
SELECT tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
```

**Expected Result:** Should show all your RLS policies (should be 30+ policies)

### 5. Check Edge Functions

Go to: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/functions

**Expected Result:** Should see:
- `event-reminders` (with cron schedule)
- `inactivity-cleanup` (with cron schedule)
- `stay-interested`
- `send-notification`

---

## 🔍 Test Fresh Beta Experience

After reset, test the complete user flow:

### 1. New User Registration
- [ ] Sign up with email/password
- [ ] Verify email confirmation works (if enabled)
- [ ] Set up profile (name, avatar emoji)
- [ ] Upload profile picture

### 2. Circle Creation
- [ ] Create a new circle
- [ ] Copy circle invite code
- [ ] Share code with test user #2

### 3. Join Circle
- [ ] Second user joins via invite code
- [ ] Both users see each other in circle

### 4. Create Match
- [ ] Select an activity (verify global activities exist)
- [ ] Create a match
- [ ] Both users join the match
- [ ] Send messages in match chat

### 5. Schedule Event
- [ ] Create an event for the match
- [ ] Set scheduled date/time
- [ ] Both users join event
- [ ] Send messages in event chat

### 6. Test Notifications
- [ ] Send a chat message (other user should get push notification)
- [ ] Join an event (creator should get notification if enabled)
- [ ] Test mute/unmute chat

### 7. Test Profile Features
- [ ] Upload/change profile picture
- [ ] Verify picture displays in chat
- [ ] Change notification preferences
- [ ] Toggle dark mode

### 8. Test Message Features
- [ ] Send messages
- [ ] Edit messages
- [ ] Delete messages (soft delete)
- [ ] Add emoji reactions
- [ ] Remove reactions

---

## ⚠️ Troubleshooting

### Issue: "permission denied for table auth.users"

**Solution:** You need to run the auth deletion via the Supabase SQL Editor (which has service_role permissions) or use the Dashboard UI to manually delete users.

### Issue: "Foreign key violation" errors

**Solution:** The scripts are designed to delete in the correct order. If you get this error:
1. Run `ROLLBACK;`
2. Check if you modified the script order
3. Re-run the original script as-is

### Issue: Global activities are deleted

**Solution:** Global activities have `circle_id = NULL`. The script only deletes activities where `circle_id IS NOT NULL`. If they're missing:

```sql
-- Restore default global activities
INSERT INTO activities (id, name, circle_id) VALUES
  (gen_random_uuid(), 'Basketball', NULL),
  (gen_random_uuid(), 'Soccer', NULL),
  (gen_random_uuid(), 'Tennis', NULL),
  (gen_random_uuid(), 'Hiking', NULL),
  (gen_random_uuid(), 'Board Games', NULL);
```

### Issue: Storage bucket shows "access denied"

**Solution:** Check storage policies:

```sql
SELECT * FROM storage.policies WHERE bucket_id = 'avatars';
```

Should show policies for:
- Users can upload their own avatars
- Users can update their own avatars
- Users can delete their own avatars
- Everyone can view avatars (public bucket)

### Issue: RLS policies are missing

**Solution:** Run the RLS migration:

```bash
psql -f MIGRATION_add_rls_policies_all_tables.sql
```

Or apply via Supabase Dashboard > SQL Editor

---

## 📊 Database Statistics (After Reset)

Expected table structure (post-reset):

| Table | Rows | Notes |
|-------|------|-------|
| profiles | 0 | Will grow as users sign up |
| circles | 0 | Will grow as users create circles |
| circle_members | 0 | Will grow as users join circles |
| activities | 5-10 | Only global activities remain |
| matches | 0 | Will grow as users create matches |
| match_participants | 0 | Will grow as users join matches |
| events | 0 | Will grow as users schedule events |
| event_participants | 0 | Will grow as users join events |
| match_messages | 0 | Will grow as users chat |
| event_messages | 0 | Will grow as users chat |
| circle_messages | 0 | Will grow as users chat |
| match_message_reactions | 0 | Will grow as users react |
| event_message_reactions | 0 | Will grow as users react |
| circle_message_reactions | 0 | Will grow as users react |
| inactivity_warnings | 0 | Will grow as cron runs |
| muted_chats | 0 | Will grow as users mute |
| preferences | 0 | Will grow as users set preferences |
| storage.objects (avatars) | 0 | Will grow as users upload pictures |
| auth.users | 0 | Will grow as users sign up |

---

## 🔐 Security Notes

### Who Can Run These Scripts?

- **Database Reset Script:** Requires `service_role` key or Supabase Dashboard SQL Editor access
- **Auth Reset Script:** Requires `service_role` key or Supabase Dashboard access
- **Regular Users:** Cannot run these scripts (protected by RLS)

### Production Safety

- These scripts are designed for **development/beta environments only**
- For production, you should:
  - Have a formal backup/restore process
  - Use a staging environment for testing
  - Have a rollback plan
  - Notify users in advance

### Data Privacy (GDPR Compliance)

- This reset permanently deletes all user data
- Soft-deleted messages (`is_deleted = true`) are also purged
- Storage files (avatars) are permanently removed
- Auth records are completely wiped
- This satisfies "right to be forgotten" requirements

---

## 📞 Support

If you encounter issues:

1. Check the Supabase logs: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/logs/explorer
2. Review Edge Function logs: https://supabase.com/dashboard/project/kxsewkjbhxtfqbytftbu/functions
3. Check this guide's troubleshooting section
4. Review the migration files in the project root for schema details

---

## 🎉 Ready for Beta!

Once you've completed all steps and verified the checklist:

✅ Your database is clean
✅ Your auth is reset
✅ Your schema is intact
✅ Your policies are preserved
✅ Your Edge Functions are running
✅ You're ready for beta testers!

**Next steps:**
1. Announce beta to your testers
2. Share the app URL and instructions
3. Monitor for issues in Supabase logs
4. Collect feedback
5. Iterate and improve!

Good luck with your beta launch! 🚀
