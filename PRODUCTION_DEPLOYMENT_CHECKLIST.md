# Production Deployment Checklist - Friendle Security Fixes

**Date**: [FILL IN DATE]
**Deployed By**: [YOUR NAME]
**Environment**: Production
**Fixes**: Priority 1-3 Security Improvements

---

## 🎯 Overview

This checklist guides you through deploying the three critical security fixes:

1. **Priority 1**: RLS (Row Level Security) Policies
2. **Priority 2**: Debug Logging Control
3. **Priority 3**: Security Headers

**Estimated Time**: 2-4 hours (including testing)
**Risk Level**: Medium (RLS has highest risk, others are low)
**Rollback Plan**: Included for each priority

---

## ⚠️ BEFORE YOU START

### Prerequisites

- [ ] **Backup Database** - Supabase Dashboard → Database → Backups → Create backup
- [ ] **Low Traffic Time** - Schedule during off-peak hours
- [ ] **Test Account Ready** - Have 2-3 test user accounts
- [ ] **Browser DevTools Open** - Monitor console for errors
- [ ] **Rollback Scripts Ready** - Keep terminal/SQL editor open
- [ ] **Team Notified** - Alert team of deployment window
- [ ] **Read All Documentation** - Review all SECURITY_FIX_PRIORITY_*.md files

### Backup Files

```bash
# Create timestamped backup
DATE=$(date +%Y%m%d_%H%M%S)
cp index.html index.html.backup_$DATE
echo "Backup created: index.html.backup_$DATE"

# Verify backup
ls -lh index.html.backup_*
```

---

## 🔴 PRIORITY 1: RLS Policies (HIGHEST RISK)

**Purpose**: Prevent unauthorized data access
**Risk**: HIGH - Could break queries if policies are wrong
**Time**: 30-60 minutes
**Impact**: Critical security fix

### Step 1: Pre-Deployment Verification

**In Supabase SQL Editor**, run:

```sql
-- File: SECURITY_FIX_PRIORITY_1_RLS_VERIFICATION.sql

-- 1. Check current RLS status
SELECT tablename, rowsecurity AS "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('profiles', 'circles', 'circle_members', 'matches');

-- 2. Save current row counts
SELECT 'profiles' AS table_name, COUNT(*) AS row_count FROM profiles
UNION ALL
SELECT 'circles', COUNT(*) FROM circles
UNION ALL
SELECT 'circle_members', COUNT(*) FROM circle_members
UNION ALL
SELECT 'matches', COUNT(*) FROM matches;
```

**Save the output** - you'll verify these counts after migration.

- [ ] RLS status saved
- [ ] Row counts saved
- [ ] Database backup confirmed

### Step 2: Deploy RLS Migration

**In Supabase SQL Editor**, run **entire file**:

```
MIGRATION_add_rls_policies_all_tables.sql
```

**Expected output:**
- Multiple "ALTER TABLE" success messages
- "CREATE POLICY" success messages
- Final SELECT showing all policies

**If errors occur:**
- ⚠️ Read error message carefully
- ⚠️ Most common: "policy already exists" - this is OK, migration handles it
- ❌ If "permission denied" - contact Supabase support
- ❌ If syntax errors - DO NOT CONTINUE, investigate

- [ ] Migration executed successfully
- [ ] No critical errors in output
- [ ] Policies created (verify with verification query below)

### Step 3: Verify Policies Applied

```sql
-- Count policies created
SELECT COUNT(*) AS "Total Policies Created"
FROM pg_policies
WHERE schemaname = 'public';

-- List policies by table
SELECT tablename, COUNT(*) AS "Policy Count"
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY tablename
ORDER BY tablename;

-- Verify row counts unchanged
SELECT 'profiles' AS table_name, COUNT(*) AS row_count FROM profiles
UNION ALL
SELECT 'circles', COUNT(*) FROM circles
UNION ALL
SELECT 'circle_members', COUNT(*) FROM circle_members
UNION ALL
SELECT 'matches', COUNT(*) FROM matches;
```

**Expected:**
- At least 20+ policies created
- Row counts **exactly match** pre-deployment counts
- Each table has multiple policies

- [ ] Policies created successfully
- [ ] Row counts match exactly
- [ ] No data lost

### Step 4: Test RLS Functionality

**Test 1: Login as Test User 1**
```
Navigate to: [YOUR APP URL]
Login with: test-user-1@example.com
```

- [ ] Login succeeds
- [ ] Can see own profile
- [ ] Can see own circles
- [ ] Can send messages in circles
- [ ] Can create events

**Test 2: Login as Test User 2 (different circle)**
```
Login with: test-user-2@example.com
```

- [ ] Login succeeds
- [ ] Cannot see User 1's circles
- [ ] Can only see own data
- [ ] Cannot access User 1's matches

**Test 3: Verify Security Working**

In browser console (as User 1):
```javascript
// Try to read all profiles (should only return circle members)
const { data, error } = await supabase.from('profiles').select('*');
console.log('Profiles visible:', data.length);
// Should be LOW number (only circle members), not ALL users

// Try to read all circles (should only return user's circles)
const { data: circles } = await supabase.from('circles').select('*');
console.log('Circles visible:', circles.length);
// Should only be circles user is member of
```

- [ ] User can only see own data + circle members
- [ ] User CANNOT see all users/circles (security working!)

### Step 5: Monitor for Issues

**Keep monitoring for 30 minutes:**

- [ ] Check Supabase Dashboard → Logs for errors
- [ ] Test all core features work
- [ ] No increase in error rate
- [ ] Users not reporting issues

### Rollback Plan (if needed)

**If something breaks**, run immediately:

```sql
-- EMERGENCY ROLLBACK: Disable RLS (keeps data safe)
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circle_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE events DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE preferences DISABLE ROW LEVEL SECURITY;
ALTER TABLE activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE inactivity_warnings DISABLE ROW LEVEL SECURITY;
ALTER TABLE muted_chats DISABLE ROW LEVEL SECURITY;

-- App should work normally again (without RLS protection)
-- Fix policies and re-enable later
```

- [ ] Rollback script ready if needed
- [ ] Team knows how to execute rollback

---

## 🟠 PRIORITY 2: Debug Logging Control (LOW RISK)

**Purpose**: Prevent sensitive data leakage via console.log
**Risk**: LOW - Only adds wrapper, doesn't modify existing code
**Time**: 15-30 minutes
**Impact**: Stops information disclosure

### Step 1: Add Debug Wrapper

**Edit index.html:**

Find line ~1410 (after Supabase client initialization):
```javascript
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
```

**Immediately after**, paste the entire contents of:
```
APPLY_DEBUG_WRAPPER.js
```

- [ ] Debug wrapper code added
- [ ] Located after Supabase client initialization
- [ ] No syntax errors (check browser console)

### Step 2: Set Production Mode

In the debug wrapper code, find:
```javascript
const DEBUG_MODE = false; // Set to false for production
```

**Ensure it's set to `false`** for production deployment.

- [ ] DEBUG_MODE = false
- [ ] Verified in code

### Step 3: Test Debug Mode

**With DEBUG_MODE = true:**
```javascript
// Temporarily set to true for testing
const DEBUG_MODE = true;
```

- [ ] Console.log statements appear
- [ ] App functions normally
- [ ] No errors

**With DEBUG_MODE = false:**
```javascript
const DEBUG_MODE = false;
```

- [ ] Console is silent (no debug logs)
- [ ] App still functions normally
- [ ] Critical errors still logged (if using debugConsole.production)

- [ ] Both modes tested
- [ ] Production mode active (DEBUG_MODE = false)

### Step 4: (Optional) Replace Critical Console.log Calls

**High-priority replacements** (manual, optional but recommended):

Find and replace these sensitive logs:

```javascript
// Password recovery (line ~1565)
// BEFORE: console.log('Password recovery detected...');
// AFTER:  debugConsole.log('Password recovery detected...');

// Database queries with user data
// BEFORE: console.log('User profile:', profileData);
// AFTER:  debugConsole.log('User profile:', profileData);

// Error handling that should always log
// BEFORE: console.error('Critical error:', error);
// AFTER:  debugConsole.production('Critical error:', error);
```

**Optional - Automated replacement:**
```bash
# BACKUP FIRST!
cp index.html index.html.before_console_replace

# Replace console.log with debugConsole.log
sed -i 's/console\.log(/debugConsole.log(/g' index.html
sed -i 's/console\.error(/debugConsole.error(/g' index.html
sed -i 's/console\.warn(/debugConsole.warn(/g' index.html

# IMPORTANT: Test thoroughly after automated replacement!
```

- [ ] Manual replacements done (recommended), OR
- [ ] Automated replacement done + tested thoroughly
- [ ] No broken functionality

### Step 5: Verify No Info Leakage

**Open browser DevTools → Console:**

- [ ] Navigate through entire app
- [ ] No debug logs visible
- [ ] Sensitive data not logged
- [ ] App functions normally

### Rollback Plan

**If debug wrapper causes issues:**

1. Remove the debug wrapper code block
2. Reload page
3. App should work as before

```bash
# Or restore from backup
cp index.html.backup_[DATE] index.html
```

- [ ] Rollback plan ready
- [ ] Backup file accessible

---

## 🟡 PRIORITY 3: Security Headers (MEDIUM RISK)

**Purpose**: Block XSS, clickjacking, MIME sniffing attacks
**Risk**: MEDIUM - CSP can break app if misconfigured
**Time**: 20-40 minutes
**Impact**: Protects against multiple attack vectors

### Step 1: Add Security Headers

**Edit index.html:**

Find the `<head>` section (lines 3-11):
```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Friendle - Who's in?</title>

    <!-- ADD SECURITY HEADERS HERE -->
```

**Paste the security headers** from:
```
APPLY_SECURITY_HEADERS.patch
```

Or manually copy the meta tags from:
```
SECURITY_FIX_PRIORITY_3_SECURITY_HEADERS.md (lines 15-62)
```

- [ ] Security headers added to <head>
- [ ] Headers placed before other meta tags
- [ ] No syntax errors

### Step 2: Verify Headers Applied

**Open browser DevTools → Network tab:**

1. Reload page
2. Click on main document request
3. Check **Response Headers**

**Should see:**
- `content-security-policy: default-src 'self'...`
- `x-frame-options: DENY`
- `x-content-type-options: nosniff`
- `referrer-policy: strict-origin-when-cross-origin`

⚠️ **Note**: Meta tag headers may not show in Network tab - this is OK.
CSP will show violations in Console if it's working.

- [ ] Headers present (or meta tags visible in HTML)

### Step 3: Test App Functionality

**Full feature test:**

- [ ] App loads without errors
- [ ] No CSP violations in console (or only expected ones)
- [ ] Can sign up / log in
- [ ] Can upload profile picture
- [ ] Images load correctly
- [ ] Google Fonts load
- [ ] Can create circles
- [ ] Can send messages
- [ ] Can create events
- [ ] OneSignal notifications work
- [ ] All buttons work (onclick handlers)
- [ ] Styles applied correctly

**Common CSP Errors:**

If you see: `Refused to load the script '...' because it violates the following Content Security Policy directive`

**Fix**: Add the domain to appropriate CSP directive:
- Scripts: Add to `script-src`
- Images: Add to `img-src`
- API calls: Add to `connect-src`

- [ ] No blocking CSP errors
- [ ] All features functional

### Step 4: Test Security Features

**Test 1: Clickjacking Protection**

Try embedding app in iframe:
```html
<!-- Create test.html -->
<iframe src="[YOUR APP URL]"></iframe>
```

- [ ] Iframe blocked (should not load)
- [ ] Console shows: "Refused to display in a frame"

**Test 2: External Script Blocked**

In browser console, try:
```javascript
const script = document.createElement('script');
script.src = 'https://malicious-site.com/evil.js';
document.body.appendChild(script);
```

- [ ] Script blocked by CSP
- [ ] Console shows: "Refused to load the script... violates CSP"

### Step 5: Test on Multiple Browsers

- [ ] Chrome/Edge - Works
- [ ] Firefox - Works
- [ ] Safari (desktop) - Works
- [ ] Mobile Safari (iOS) - Works
- [ ] Mobile Chrome (Android) - Works

### Step 6: Verify with Security Tools

**Test with securityheaders.com:**

1. Go to https://securityheaders.com
2. Enter your app URL
3. Check score

**Expected**: B or higher (A+ requires stricter CSP)

- [ ] Security headers verified
- [ ] Score acceptable

### Rollback Plan

**If CSP breaks app:**

**Option 1**: Remove specific CSP directive causing issue
```html
<!-- Remove or comment out CSP meta tag -->
<!-- <meta http-equiv="Content-Security-Policy" content="..."> -->
```

**Option 2**: Make CSP less strict
```html
<!-- Change CSP to report-only mode for debugging -->
<meta http-equiv="Content-Security-Policy-Report-Only" content="...">
```

**Option 3**: Full rollback
```bash
cp index.html.backup_[DATE] index.html
```

- [ ] Rollback plan ready
- [ ] Can quickly disable CSP if needed

---

## ✅ POST-DEPLOYMENT VERIFICATION

**30 Minutes After Deployment:**

### All Priorities

- [ ] No increase in error rate (check Supabase logs)
- [ ] No user complaints
- [ ] All features working normally
- [ ] Performance unchanged

### Priority 1 (RLS)

- [ ] Users can still access their own data
- [ ] Users CANNOT access others' data (security working)
- [ ] No "permission denied" errors

### Priority 2 (Debug Logging)

- [ ] Console is clean (no sensitive data)
- [ ] No debug logs visible in production

### Priority 3 (Security Headers)

- [ ] App loads correctly
- [ ] No CSP violations
- [ ] Images/fonts loading

---

## 📊 SUCCESS CRITERIA

**Deployment is successful if ALL of these are true:**

- [ ] Database row counts unchanged after RLS migration
- [ ] 2+ test users can login and use app normally
- [ ] Users CANNOT see other users' private data (RLS working)
- [ ] Browser console shows NO sensitive debug logs
- [ ] No CSP violation errors in console
- [ ] App functions normally for 30+ minutes
- [ ] No increase in error rate
- [ ] All core features work (login, circles, messages, events)

**If ALL checked**: ✅ **DEPLOYMENT SUCCESSFUL**

**If ANY unchecked**: ⚠️ **INVESTIGATE BEFORE DECLARING SUCCESS**

---

## 🚨 EMERGENCY ROLLBACK (Full Revert)

**If multiple things break and you need to fully rollback:**

### 1. Restore index.html
```bash
cp index.html.backup_[DATE] index.html
# Or via git:
git checkout index.html
git push origin main
```

### 2. Disable RLS (keeps data safe)
```sql
-- Run in Supabase SQL Editor
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circles DISABLE ROW LEVEL SECURITY;
ALTER TABLE circle_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE matches DISABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE events DISABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants DISABLE ROW LEVEL SECURITY;
ALTER TABLE preferences DISABLE ROW LEVEL SECURITY;
ALTER TABLE activities DISABLE ROW LEVEL SECURITY;
ALTER TABLE inactivity_warnings DISABLE ROW LEVEL SECURITY;
ALTER TABLE muted_chats DISABLE ROW LEVEL SECURITY;
```

### 3. Verify Rollback Success
- [ ] App loads normally
- [ ] Users can login
- [ ] Features work
- [ ] Error rate returns to normal

### 4. Post-Mortem
- Document what went wrong
- Review logs
- Test fixes in staging before re-deploying

---

## 📝 DEPLOYMENT NOTES

**Date Deployed**: _______________
**Deployed By**: _______________
**Start Time**: _______________
**End Time**: _______________
**Total Duration**: _______________

**Issues Encountered:**
```
[Document any issues, even if resolved]




```

**Rollbacks Performed:**
```
[None if successful, or list what was rolled back]




```

**Final Status**:
- [ ] ✅ Fully Successful
- [ ] ⚠️ Partially Successful (document which priorities failed)
- [ ] ❌ Rolled Back (document reason)

**Notes:**
```
[Any additional notes, observations, or recommendations]




```

---

## 📚 Related Files Reference

- `SECURITY_AUDIT_REPORT.md` - Original security audit findings
- `SECURITY_FIX_PRIORITY_1_RLS_VERIFICATION.sql` - RLS verification script
- `SECURITY_FIX_PRIORITY_2_DEBUG_LOGGING.md` - Debug logging documentation
- `SECURITY_FIX_PRIORITY_3_SECURITY_HEADERS.md` - Security headers guide
- `MIGRATION_add_rls_policies_all_tables.sql` - RLS policies migration
- `APPLY_DEBUG_WRAPPER.js` - Debug mode wrapper code
- `APPLY_SECURITY_HEADERS.patch` - Security headers patch

---

## ✨ NEXT STEPS AFTER SUCCESSFUL DEPLOYMENT

After deployment is stable for 24+ hours:

1. **Monitor Metrics**
   - Check error rates daily for 1 week
   - Review user feedback
   - Monitor performance

2. **Implement Remaining Priorities** (from security audit)
   - Priority 4: Fix localStorage security
   - Priority 5: Strengthen password policy
   - Priority 6: Server-side rate limiting
   - Priority 7: Account security (2FA, lockout)

3. **Set Up Monitoring**
   - Integrate error tracking (Sentry, Rollbar)
   - Set up CSP violation reporting
   - Create audit log dashboard

4. **Schedule Security Review**
   - Run penetration testing
   - Review RLS policies with fresh eyes
   - Test with OWASP ZAP or Burp Suite

---

**Good luck with deployment! 🚀**

Remember: Test thoroughly, deploy during low-traffic, have rollback ready.
