# Message Deletion Strategy - Soft Delete Implementation

## Overview

Friendle implements **soft deletion** for all messages instead of permanently removing them from the database. This provides better privacy controls while maintaining data integrity and audit trails.

## Implementation Details

### Database Changes

Added to all message tables (`match_messages`, `circle_messages`, `event_messages`):

- `is_deleted BOOLEAN DEFAULT false` - Flag indicating message is deleted
- `deleted_at TIMESTAMP WITH TIME ZONE` - Timestamp when deletion occurred (for GDPR compliance)
- Indexes on `is_deleted` for optimized queries

### User Experience

**Deleted Messages Display:**
- Content replaced with greyed-out italic text: `[Deleted]`
- Sender name and timestamp remain visible
- Edit/Delete buttons hidden for deleted messages
- Reactions still visible (users can see previous engagement)

**Deletion Process:**
1. User clicks ⋯ menu on their own message
2. Clicks "Delete" button
3. Confirms deletion
4. Message content replaced with `[Deleted]` immediately
5. Database updated: `is_deleted = true`, `deleted_at = NOW()`
6. Other users see the update via real-time broadcast

### Security Benefits

✅ **Privacy**: Message content no longer visible to anyone
✅ **Audit Trail**: Database maintains record of who sent what and when it was deleted
✅ **GDPR Compliance**: `deleted_at` timestamp allows tracking deletion requests
✅ **Data Integrity**: Conversation flow preserved, no orphaned reactions or broken threads
✅ **Reversibility**: Admin can restore accidentally deleted messages if needed

### Technical Implementation

**Delete Function (index.html:7823-7907):**
```javascript
// Soft delete with UPDATE instead of DELETE
const { error } = await supabase
  .from('event_messages')
  .update({
    is_deleted: true,
    deleted_at: new Date().toISOString()
  })
  .eq('id', msgId)
  .eq('sender_id', currentUser.id);
```

**Display Functions (index.html:8784-8786, 8868-8870):**
```javascript
// Check is_deleted flag before rendering
const sanitizedContent = message.is_deleted
  ? '<span style="color: #999; font-style: italic;">[Deleted]</span>'
  : sanitizeHTML(message.content);
```

**Hide Actions for Deleted Messages (index.html:8898):**
```javascript
${isOwnMessage && !message.is_deleted ? `
  <div class="message-actions">
    <!-- Edit/Delete buttons -->
  </div>
` : ''}
```

## Migration Required

**File:** `MIGRATION_add_soft_delete_messages.sql`

**Run this migration in Supabase SQL Editor:**
```sql
-- Adds is_deleted and deleted_at columns to all message tables
-- Adds performance indexes
-- Updates RLS policies (uses existing UPDATE policies)
```

## Testing Checklist

- [ ] Send a message in match chat
- [ ] Delete the message - verify shows "[Deleted]" in grey italic
- [ ] Check other user's view - should see "[Deleted]"
- [ ] Verify Edit/Delete buttons don't appear on deleted messages
- [ ] Verify reactions still visible on deleted messages
- [ ] Test in circle chat
- [ ] Test in event chat
- [ ] Verify deletion broadcast works (real-time update for other users)

## GDPR Compliance

The `deleted_at` timestamp enables compliance with data deletion requests:

1. **Soft Delete** (immediate): User deletes message → content hidden, `is_deleted = true`
2. **Hard Delete** (batch process): Admin can run periodic cleanup to permanently remove messages older than X days where `is_deleted = true`

Example cleanup query (admin only):
```sql
DELETE FROM match_messages
WHERE is_deleted = true
  AND deleted_at < NOW() - INTERVAL '90 days';
```

## Future Enhancements

Potential improvements:

1. **Undo Delete**: Allow users to restore within 30 seconds
2. **Edit History**: Track message edits with audit trail
3. **Bulk Delete**: Select multiple messages to delete at once
4. **Auto-Cleanup**: Scheduled job to hard-delete old soft-deleted messages
5. **Admin View**: Show deleted messages to circle admins for moderation

## Related Files

- `MIGRATION_add_soft_delete_messages.sql` - Database migration
- `index.html:7823-7907` - Delete function implementation
- `index.html:8751-8833` - Message display (appendMessageToContainer)
- `index.html:8835-8924` - Message display (appendMessage)
- `SECURITY_AUDIT_REPORT.md` - Original security recommendation
