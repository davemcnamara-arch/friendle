# RLS Testing Guide

This guide helps you verify that Row Level Security (RLS) is working correctly after applying the migration.

## Quick Testing Strategy

You have two options:
1. **SQL Testing** (5 minutes) - Run queries in Supabase SQL Editor
2. **Application Testing** (15 minutes) - Test the live app

---

## Option 1: SQL Testing (Recommended First)

### Prerequisites
- You need at least 2 test users in different circles
- Access to Supabase SQL Editor

### Test 1: Verify RLS is Enabled

```sql
-- Check that RLS is enabled on all tables
SELECT
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
    'profiles', 'circles', 'circle_members', 'matches',
    'match_participants', 'events', 'event_participants',
    'preferences', 'activities', 'inactivity_warnings',
    'muted_chats', 'match_messages'
)
ORDER BY tablename;
```

**Expected Result:** All tables should show `rls_enabled = true`

---

### Test 2: Test Profile Access Control

```sql
-- First, get your user ID (replace with actual user email)
SELECT id, email, name FROM auth.users WHERE email = 'your-email@example.com';

-- Copy the user ID, then run this as that user:
-- This simulates being authenticated as a specific user
SET LOCAL auth.uid TO 'paste-user-id-here';

-- Try to read all profiles
SELECT id, name, email FROM profiles;

-- Expected: Should only return:
-- 1. Your own profile
-- 2. Profiles of people in your circles
-- Should NOT return all users in the database
```

**✅ PASS:** Returns only your profile + circle members
**❌ FAIL:** Returns all profiles in database (RLS not working)

---

### Test 3: Test Circle Access Control

```sql
-- Set your user ID
SET LOCAL auth.uid TO 'your-user-id-here';

-- Try to read all circles
SELECT * FROM circles;

-- Expected: Should only return circles you're a member of
```

**✅ PASS:** Returns only your circles
**❌ FAIL:** Returns all circles (RLS not working)

---

### Test 4: Test Cross-User Access Prevention

```sql
-- Get two different user IDs
SELECT id, email FROM auth.users LIMIT 2;

-- Test as User A
SET LOCAL auth.uid TO 'user-a-id-here';
SELECT * FROM preferences WHERE profile_id != 'user-a-id-here';

-- Expected: Should return EMPTY
-- (User A cannot see User B's preferences)

-- Reset the session
RESET auth.uid;
```

**✅ PASS:** Returns empty (User A cannot see User B's preferences)
**❌ FAIL:** Returns other users' preferences (SECURITY BUG!)

---

### Test 5: Test Match Access Control

```sql
-- As User A (in Circle 1)
SET LOCAL auth.uid TO 'user-a-id-here';
SELECT * FROM matches;

-- Expected: Only matches from Circle 1
-- Should NOT see matches from circles you're not in

RESET auth.uid;
```

**✅ PASS:** Returns only matches from your circles
**❌ FAIL:** Returns all matches (RLS not working)

---

### Test 6: Test Message Access Control

```sql
-- As User A
SET LOCAL auth.uid TO 'user-a-id-here';
SELECT * FROM match_messages;

-- Expected: Only messages from matches you're part of
-- Should NOT see messages from other people's matches

RESET auth.uid;
```

**✅ PASS:** Returns only messages from your matches
**❌ FAIL:** Returns all messages (MAJOR SECURITY ISSUE!)

---

## Option 2: Application Testing

### Setup
1. Open your Friendle app in a browser
2. Have 2 different user accounts ready (or create them)
3. Open browser DevTools (F12) to see any errors

---

### Test Suite

#### **Test 1: Basic Authentication** ⏱️ 2 min

**Steps:**
1. Log out if logged in
2. Log in with an existing account
3. Check that profile loads correctly

**Expected:**
- ✅ Login succeeds
- ✅ Profile data displays
- ✅ No console errors about "permission denied"

**If it fails:**
- Check browser console for RLS errors
- Look for "new row violates row-level security policy"

---

#### **Test 2: Circle Operations** ⏱️ 3 min

**Steps:**
1. View your circles list
2. Create a new circle (or try to)
3. Join an existing circle with invite code
4. Try to view circle members

**Expected:**
- ✅ Your circles display
- ✅ Can create new circles
- ✅ Can join circles with valid code
- ✅ Can see circle members
- ✅ CANNOT see circles you're not in (test by checking network tab)

**If it fails:**
- Open DevTools Network tab
- Look for failed requests with 403/401 status
- Check console for RLS policy violations

---

#### **Test 3: Match Operations** ⏱️ 3 min

**Steps:**
1. Go to Matches tab
2. Select some activities
3. View matches
4. Join a match
5. Send a message in match chat

**Expected:**
- ✅ Can view matches for your circles only
- ✅ Can join matches
- ✅ Can send messages
- ✅ Messages display correctly (no HTML injection if you try `<script>alert('test')</script>`)

**If it fails:**
- Check if match list is empty (might be RLS filtering too much)
- Check console for errors
- Verify you're in at least one circle with activities

---

#### **Test 4: Event Operations** ⏱️ 3 min

**Steps:**
1. Go to Events tab (if visible)
2. Create a new event
3. Join an event
4. Send a message in event chat

**Expected:**
- ✅ Can create events in your circles
- ✅ Can join events
- ✅ Can send messages
- ✅ Messages are sanitized (XSS protection)

**If it fails:**
- Look for "permission denied for table events"
- Check if you're a member of the circle

---

#### **Test 5: Profile Operations** ⏱️ 2 min

**Steps:**
1. Go to Profile page
2. Update your name or avatar
3. Try to view another user's profile (from a circle member)

**Expected:**
- ✅ Can update your own profile
- ✅ Can view profiles of circle members
- ✅ Profile picture uploads work

**If it fails:**
- Check console for "update" permission errors
- Verify storage policies are working

---

#### **Test 6: XSS Protection** ⏱️ 2 min

**Steps:**
1. Go to any chat (match, event, or circle)
2. Try sending these messages:
   - `<script>alert('XSS')</script>`
   - `<img src=x onerror="alert('XSS')">`
   - `<b>Bold text</b>`

**Expected:**
- ✅ Messages appear as plain text (not executed)
- ✅ HTML tags are escaped and visible as text
- ✅ No alert popup appears
- ✅ No console errors

**If it fails:**
- If alerts pop up: XSS vulnerability still exists! ⚠️
- If HTML renders (bold text shows): Sanitization not working

---

### Test 7: Cross-User Security Test ⏱️ 5 min

**Steps:**
1. Open app in 2 different browser profiles (or use Incognito + Normal)
2. User A: Join Circle X
3. User B: Stay in Circle Y (different from X)
4. User A: Create a match in Circle X
5. User B: Try to access User A's match (you'll need to know the match ID)

**How to test:**
```javascript
// In User B's browser console, try to access User A's match:
const { data, error } = await supabase
  .from('matches')
  .select('*')
  .eq('id', 'user-a-match-id-here');

console.log('Data:', data);
console.log('Error:', error);
```

**Expected:**
- ✅ `data` should be empty `[]` or null
- ✅ User B cannot see User A's match from Circle X

**If it fails:**
- If User B can see the match: **CRITICAL SECURITY BUG** ⚠️
- RLS policies not working correctly

---

## Quick Test Results Checklist

Use this to track your testing:

```
[ ] SQL Test 1: RLS Enabled - PASS / FAIL
[ ] SQL Test 2: Profile Access - PASS / FAIL
[ ] SQL Test 3: Circle Access - PASS / FAIL
[ ] SQL Test 4: Cross-User Prevention - PASS / FAIL
[ ] SQL Test 5: Match Access - PASS / FAIL
[ ] SQL Test 6: Message Access - PASS / FAIL

[ ] App Test 1: Authentication - PASS / FAIL
[ ] App Test 2: Circle Operations - PASS / FAIL
[ ] App Test 3: Match Operations - PASS / FAIL
[ ] App Test 4: Event Operations - PASS / FAIL
[ ] App Test 5: Profile Operations - PASS / FAIL
[ ] App Test 6: XSS Protection - PASS / FAIL
[ ] App Test 7: Cross-User Security - PASS / FAIL
```

---

## Common Issues & Solutions

### Issue 1: "new row violates row-level security policy"

**Symptom:** Insert/update operations fail
**Cause:** RLS policy preventing the operation
**Solution:** Check if the WITH CHECK clause is too restrictive

**Example Fix:**
```sql
-- If you see this error when creating a circle, check:
SELECT * FROM pg_policies WHERE tablename = 'circles' AND cmd = 'INSERT';

-- The policy should allow created_by = auth.uid()
```

---

### Issue 2: Empty Results Everywhere

**Symptom:** All queries return empty arrays
**Cause:** User not properly authenticated or policies too restrictive
**Solution:**

1. Check authentication:
```javascript
const { data: { session } } = await supabase.auth.getSession();
console.log('Session:', session);
```

2. Check if user is in any circles:
```sql
SELECT * FROM circle_members WHERE profile_id = auth.uid();
```

---

### Issue 3: Can See Other Users' Data

**Symptom:** User A can see User B's private data
**Cause:** **CRITICAL - RLS not working**
**Solution:**

1. Verify RLS is enabled:
```sql
SELECT tablename, rowsecurity FROM pg_tables
WHERE tablename = 'profiles' AND schemaname = 'public';
```

2. Check policies exist:
```sql
SELECT * FROM pg_policies WHERE tablename = 'profiles';
```

3. If policies missing, re-run the migration

---

### Issue 4: "permission denied for table X"

**Symptom:** Queries fail with permission denied
**Cause:** Missing GRANT statements
**Solution:** Re-run the migration, which includes:

```sql
GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;
-- etc.
```

---

## Performance Testing (Optional)

If you want to test performance with RLS:

```sql
-- Test query performance
EXPLAIN ANALYZE
SELECT * FROM matches
WHERE EXISTS (
  SELECT 1 FROM circle_members
  WHERE circle_members.circle_id = matches.circle_id
  AND circle_members.profile_id = auth.uid()
);
```

**Expected:** Query should complete in < 50ms for small datasets

---

## Emergency Rollback

If RLS is breaking everything and you need to disable it temporarily:

```sql
-- ⚠️ WARNING: This removes all security protections!
-- Only use for testing/debugging

ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circles DISABLE ROW LEVEL SECURITY;
-- ... (repeat for all tables)
```

**To re-enable:** Just re-run the migration SQL file.

---

## What to Report Back

After testing, report:

1. **Which tests passed/failed**
2. **Any console errors** (copy/paste exact error messages)
3. **Which features broke** (if any)
4. **Any unexpected behavior**

Example report:
```
✅ All SQL tests passed
✅ Authentication works
✅ Circles work
❌ Match creation fails with "permission denied for table matches"
❌ Event messages show HTML tags (XSS fix not working)
```

---

## Summary

**Minimum Testing (5 minutes):**
- Run SQL Tests 1-3
- Test login + view circles in app

**Recommended Testing (15 minutes):**
- All SQL tests
- App Tests 1-5

**Thorough Testing (30 minutes):**
- All tests including cross-user security test
- Try to break things intentionally

Good luck! 🚀
