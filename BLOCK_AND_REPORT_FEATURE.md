# Block and Report Feature Implementation

## Overview

This document describes the implementation of user blocking and content reporting features for Friendle, enhancing user safety and providing moderation capabilities.

## Features Implemented

### 1. Block User Feature

**Functionality:**
- Users can block other users to prevent interaction
- Blocked users are filtered from:
  - Profiles (bidirectional - neither can see the other)
  - Circle members lists
  - Match participants
  - Event participants
  - All messages (match, event, and circle chats)
- Users can view and manage their blocked users list in Settings
- Users can unblock at any time

**Database Schema:**
```sql
CREATE TABLE blocked_users (
    id UUID PRIMARY KEY,
    blocker_id UUID (references profiles),
    blocked_id UUID (references profiles),
    reason TEXT (optional),
    created_at TIMESTAMP,
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);
```

**UI Components:**
- Block user modal with confirmation and optional reason
- "Blocked Users" collapsible section in Settings page
- Block option in message actions menu (for other users' messages)
- Unblock button in blocked users list

**Access Points:**
- Message actions menu: Click the ⋯ button on any message from another user → "🚫 Block User"
- Settings page: "🚫 Blocked Users" section

---

### 2. Report Content Feature

**Functionality:**
- Users can report problematic content/behavior to admins
- Report types: User, Message, Circle, Event
- Report categories:
  - Harassment or bullying
  - Spam or scam
  - Inappropriate content
  - Fake profile or impersonation
  - Threatening behavior
  - Other
- Optional: Users can block while reporting
- Reports are stored for admin review with status tracking

**Database Schema:**
```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY,
    reporter_id UUID (references profiles),
    reported_type TEXT ('user', 'message', 'circle', 'event'),
    reported_id UUID (ID of reported content),
    reason_category TEXT (harassment, spam, etc.),
    reason_details TEXT (optional),
    status TEXT ('pending', 'under_review', 'resolved', 'dismissed'),
    admin_notes TEXT,
    reviewed_by UUID (admin profile_id),
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP
);
```

**UI Components:**
- Report modal with category selection and optional details
- Checkbox option to also block the user when reporting
- Report option in message actions menu (for other users' messages)

**Access Points:**
- Message actions menu: Click the ⋯ button on any message from another user → "⚠️ Report"

---

## Implementation Details

### Database Migrations

Two SQL migration files have been created:

1. **MIGRATION_add_blocked_users.sql**
   - Creates `blocked_users` table with RLS policies
   - Updates existing RLS policies on profiles, circle_members, match_participants, event_participants, and all message tables to filter blocked users
   - Ensures bidirectional blocking (both users are hidden from each other)

2. **MIGRATION_add_reports.sql**
   - Creates `reports` table with RLS policies
   - Includes helper function `get_report_context()` to retrieve full report context for admin review
   - Users can only view their own reports
   - Only service role can update report status and admin fields

### Frontend Implementation

**Location:** `index.html`

**New JavaScript Functions:**
- `toggleBlockedUsers()` - Expand/collapse blocked users section
- `initBlockedUsers()` - Initialize blocked users section state
- `loadBlockedUsers()` - Load and render blocked users list
- `openBlockUserModal(userId, userName)` - Open block confirmation dialog
- `closeBlockUserModal()` - Close block dialog
- `confirmBlockUser()` - Execute block action
- `unblockUser(userId, userName)` - Unblock a user
- `openReportModal(contentType, contentId, contentName)` - Open report dialog
- `closeReportModal()` - Close report dialog
- `submitReport()` - Submit report to database

**UI Additions:**
1. **Settings Page:**
   - New "🚫 Blocked Users" collapsible section
   - Lists all blocked users with avatars, names, and unblock buttons
   - Shows reason for blocking if provided

2. **Modals:**
   - Block User Modal - Confirmation dialog with optional reason field
   - Report Content Modal - Report form with category dropdown, details textarea, and "also block" checkbox

3. **Message Actions:**
   - Modified message action menus to show different options for own vs. other users' messages
   - Own messages: Edit, Delete
   - Other users' messages: Report, Block User

**CSS Additions:**
- `.profile-picture-small` - 40px circular avatar for blocked users list

---

## Row Level Security (RLS)

### Blocked Users Table Policies

1. **Users can read own blocks** - Users can see who they have blocked
2. **Users can see who blocked them** - Optional (can be disabled for production)
3. **Users can block others** - Insert policy
4. **Users can unblock others** - Delete policy

### Updated Policies on Existing Tables

All SELECT policies have been updated to filter out blocked users:
- `profiles` - Bidirectional blocking (neither can see the other)
- `circle_members` - Blocked users don't appear in member lists
- `match_participants` - Blocked users don't appear in matches
- `event_participants` - Blocked users don't appear in events
- `match_messages` - Messages from blocked users are hidden
- `event_messages` - Messages from blocked users are hidden
- `circle_messages` - Messages from blocked users are hidden

### Reports Table Policies

1. **Users can read own reports** - Users can see reports they've submitted
2. **Users can create reports** - Anyone can report content
3. **Users can update own pending reports** - Can edit details before review

---

## Admin Moderation

### Viewing Reports

Admins must use the Supabase service role key to access all reports:

```sql
-- Get all pending reports
SELECT * FROM reports
WHERE status = 'pending'
ORDER BY created_at DESC;

-- Get report with full context
SELECT get_report_context('report-id');
```

### Updating Reports

```sql
-- Mark report as reviewed
UPDATE reports
SET status = 'resolved',
    admin_notes = 'User was warned',
    reviewed_by = 'admin-profile-id',
    reviewed_at = NOW()
WHERE id = 'report-id';
```

### Report Statistics

```sql
SELECT
    status,
    reported_type,
    reason_category,
    COUNT(*) as count
FROM reports
GROUP BY status, reported_type, reason_category
ORDER BY count DESC;
```

---

## User Experience Flow

### Blocking a User

1. User sees inappropriate message from another user
2. Clicks ⋯ button on the message
3. Selects "🚫 Block User"
4. Sees confirmation modal explaining what will happen
5. Optionally provides reason for blocking
6. Clicks "Block User"
7. User is immediately blocked and hidden from view
8. Notification confirms the block

### Reporting Content

1. User sees problematic content
2. Clicks ⋯ button on the message
3. Selects "⚠️ Report"
4. Report modal opens
5. Selects reason category from dropdown
6. Optionally provides additional details
7. Optionally checks "Also block this user"
8. Clicks "Submit Report"
9. Report is sent to admins
10. Notification confirms submission

### Managing Blocked Users

1. User goes to Settings page
2. Scrolls to "🚫 Blocked Users" section
3. Clicks to expand
4. Sees list of all blocked users with avatars and names
5. Can click "Unblock" on any user
6. Confirms unblock action
7. User is unblocked and will appear in the app again

---

## Testing Instructions

### Testing Blocks

1. **Block a user:**
   - Open a chat with messages from multiple users
   - Click ⋯ on a message from another user
   - Select "Block User"
   - Verify the user disappears from:
     - Circle members
     - Match participants
     - All chat messages

2. **Unblock a user:**
   - Go to Settings → Blocked Users
   - Click Unblock on a blocked user
   - Verify the user reappears in circles, matches, and messages

3. **Test bidirectional blocking:**
   - User A blocks User B
   - User B should not see User A's profile or messages
   - User A should not see User B's profile or messages

### Testing Reports

1. **Report a message:**
   - Click ⋯ on a message from another user
   - Select "Report"
   - Fill out report form
   - Submit
   - Verify report appears in database

2. **Report with block:**
   - Report a message
   - Check "Also block this user"
   - Submit
   - Verify both report is created AND user is blocked

3. **Admin review:**
   - Use Supabase SQL editor with service role
   - Query `SELECT * FROM reports WHERE status = 'pending'`
   - Verify report data is complete
   - Test `get_report_context()` function

---

## Security Considerations

1. **RLS Policies:** All tables have proper RLS policies to prevent unauthorized access
2. **XSS Protection:** All user-generated content is sanitized before display
3. **Self-blocking Prevention:** CHECK constraint prevents users from blocking themselves
4. **Admin Only:** Report status can only be changed via service role (admins)
5. **Bidirectional Blocking:** Both parties are hidden from each other when blocked

---

## Future Enhancements

1. **Admin Dashboard:**
   - Build web interface for reviewing reports
   - Add user suspension/ban functionality
   - Create report analytics dashboard

2. **Additional Block Options:**
   - Block from specific circles only (partial blocking)
   - Temporary blocks with expiration
   - Block notifications (optional notification to blocked user)

3. **Enhanced Reporting:**
   - Attach screenshots to reports
   - Report history for repeat offenders
   - Automated flagging for certain keywords
   - Email notifications for admins on new reports

4. **User Controls:**
   - Export list of blocked users
   - Bulk blocking from CSV
   - Block recommendations based on behavior

---

## Files Modified

1. `MIGRATION_add_blocked_users.sql` - Database migration for blocking
2. `MIGRATION_add_reports.sql` - Database migration for reporting
3. `index.html` - UI and JavaScript implementation
4. `BLOCK_AND_REPORT_FEATURE.md` - This documentation

---

## Deployment Checklist

- [ ] Run `MIGRATION_add_blocked_users.sql` in Supabase SQL Editor
- [ ] Run `MIGRATION_add_reports.sql` in Supabase SQL Editor
- [ ] Verify RLS policies are active on all tables
- [ ] Test blocking functionality
- [ ] Test reporting functionality
- [ ] Set up admin access for reviewing reports
- [ ] Update user documentation/help section
- [ ] Monitor initial usage for issues

---

## Support

For questions or issues with this feature:
- Check Supabase logs for database errors
- Review browser console for JavaScript errors
- Verify RLS policies are correctly applied
- Ensure service role key is used for admin operations
