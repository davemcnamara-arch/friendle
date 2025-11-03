# Blocking Behavior in Friendle

## Overview

Friendle implements **unilateral (one-way) blocking**, matching the behavior of modern social platforms like Twitter/X, Instagram, Discord, and WhatsApp.

---

## How Unilateral Blocking Works

### When User A Blocks User B:

| Action | User A (Blocker) | User B (Blocked) |
|--------|------------------|------------------|
| **Seeing messages** | ❌ Cannot see B's messages | ✅ Can still see A's messages |
| **Sending messages** | ✅ Can send messages | ✅ Can send messages |
| **Message visibility** | B's messages are hidden from A | A's messages are visible to B |
| **Knows they're blocked?** | ✅ Yes (they initiated) | ❌ No (invisible blocking) |
| **Participant lists** | B is hidden from A's view | A is visible to B |

### Key Points:

✅ **Blocker is in control**: User A controls what THEY see
✅ **Blocked user unaware**: User B doesn't get error messages or know they're blocked
✅ **Asymmetric**: Blocking only affects what the blocker sees, not what the blocked user sees
✅ **Safer**: Doesn't alert potential harassers that they've been blocked

---

## Technical Implementation

### SELECT Policies (Reading Messages)

```sql
-- Only check if the VIEWER has blocked the SENDER (one-way)
AND NOT EXISTS (
    SELECT 1 FROM blocked_users
    WHERE blocker_id = auth.uid() AND blocked_id = match_messages.sender_id
)
```

**Result**: User A doesn't see messages from anyone they blocked.

### INSERT Policies (Sending Messages)

```sql
-- Check if any RECIPIENT in the conversation has blocked the SENDER
RETURN EXISTS (
    SELECT 1
    FROM blocked_users bu
    JOIN match_participants mp ON mp.profile_id = bu.blocker_id
    WHERE mp.match_id = check_match_id
      AND bu.blocked_id = user_id
);
```

**Result**: User B cannot send messages if ANY participant in the conversation has blocked them.

---

## Examples

### Example 1: Basic Block

**Setup**: Alice and Bob are in a match together.

1. Alice blocks Bob
   ```sql
   INSERT INTO blocked_users (blocker_id, blocked_id)
   VALUES ('alice-id', 'bob-id');
   ```

2. **Alice's experience**:
   - Doesn't see Bob's messages ❌
   - Can still send messages ✅
   - Bob is hidden from participant list ❌

3. **Bob's experience**:
   - Sees all messages (including Alice's) ✅
   - Can still send messages ✅
   - Gets 403 error when sending (because Alice blocked him) ❌
   - Sees Alice in participant list ✅

---

### Example 2: Group Chat with Block

**Setup**: Alice, Bob, and Charlie are in a circle chat.

1. Alice blocks Bob (Bob doesn't block anyone)

2. **Alice's view**:
   ```
   [Charlie]: Hey everyone!      ✅ Visible
   [Alice]: Hello Charlie!       ✅ Visible
   [Bob]: Hi Alice!              ❌ Hidden (Alice blocked Bob)
   [Charlie]: What's up Bob?     ✅ Visible
   ```

3. **Bob's view**:
   ```
   [Charlie]: Hey everyone!      ✅ Visible
   [Alice]: Hello Charlie!       ✅ Visible
   [Bob]: Hi Alice!              ✅ Visible (his own message)
   [Charlie]: What's up Bob?     ✅ Visible
   ```

4. **Charlie's view**:
   ```
   [Charlie]: Hey everyone!      ✅ Visible
   [Alice]: Hello Charlie!       ✅ Visible
   [Bob]: Hi Alice!              ✅ Visible
   [Charlie]: What's up Bob?     ✅ Visible
   ```

5. **When Bob tries to send a message**:
   - Gets **403 Forbidden** error (because Alice, a participant, has blocked him)
   - Error message doesn't explicitly say "Alice blocked you" (privacy)
   - Bob might infer he's blocked, but doesn't know by whom

---

### Example 3: Mutual Block

**Setup**: Alice and Bob both block each other.

1. Alice blocks Bob:
   ```sql
   INSERT INTO blocked_users (blocker_id, blocked_id)
   VALUES ('alice-id', 'bob-id');
   ```

2. Bob blocks Alice:
   ```sql
   INSERT INTO blocked_users (blocker_id, blocked_id)
   VALUES ('bob-id', 'alice-id');
   ```

3. **Result**:
   - Alice doesn't see Bob's messages ❌
   - Bob doesn't see Alice's messages ❌
   - Alice gets 403 when trying to send (Bob blocked her) ❌
   - Bob gets 403 when trying to send (Alice blocked him) ❌
   - Effectively bidirectional, but only because BOTH users chose to block

---

## Comparison: Bidirectional vs Unilateral

| Feature | Bidirectional (Old) | Unilateral (New) |
|---------|---------------------|------------------|
| **A blocks B** | Both blocked | Only A hides B |
| **B knows they're blocked?** | ✅ Yes (gets 403 immediately) | ❌ Not initially |
| **B can send messages?** | ❌ No (403 error) | ❌ No (403 error) |
| **B can see A's messages?** | ❌ No (hidden) | ✅ Yes (visible) |
| **Escalation risk** | ⚠️ Higher (B knows immediately) | ✅ Lower (B doesn't realize) |
| **User control** | ⚠️ Both users affected | ✅ Blocker has full control |
| **Matches social platforms?** | ❌ No | ✅ Yes |

---

## Why Unilateral is Better

### 1. **User Agency**
- The person being harassed controls what THEY see
- Blocker isn't prevented from sending (though rare use case)

### 2. **Safety**
- Blocked user doesn't immediately know they're blocked
- Reduces risk of escalation via other channels
- Harasser doesn't get instant confirmation

### 3. **Privacy**
- Block is invisible to the blocked user
- Matches expectations from other platforms

### 4. **Modern UX**
- Twitter/X: Blocker hides blocked user's content
- Instagram: Blocker controls visibility
- Discord: Blocker hides messages
- WhatsApp: Blocker doesn't receive messages

---

## Database Schema

### `blocked_users` Table

```sql
CREATE TABLE blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES profiles(id),  -- Who initiated the block
    blocked_id UUID NOT NULL REFERENCES profiles(id),  -- Who is being blocked
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);
```

### Helper Functions

- `is_blocked_in_match(user_id, match_id)` - Checks if any match participant blocked the user
- `is_blocked_in_event(user_id, event_id)` - Checks if any event participant blocked the user
- `is_blocked_in_circle(user_id, circle_id)` - Checks if any circle member blocked the user

---

## Migration Path

To migrate from bidirectional to unilateral blocking:

1. Run `MIGRATION_unilateral_blocking.sql`
2. Test with the scenarios above
3. Verify SELECT policies only check `blocker_id = auth.uid()`
4. Verify INSERT functions check if recipient blocked sender

**No data migration needed** - existing blocks work the same way from the blocker's perspective.

---

## Testing

### Test Scenario 1: Basic Block
```sql
-- User A blocks User B
INSERT INTO blocked_users (blocker_id, blocked_id)
VALUES ('user-a-id', 'user-b-id');

-- As User A: Should NOT see B's messages
-- As User B: SHOULD see A's messages
-- As User B: Should get 403 when trying to send
```

### Test Scenario 2: Unblock
```sql
-- User A unblocks User B
DELETE FROM blocked_users
WHERE blocker_id = 'user-a-id' AND blocked_id = 'user-b-id';

-- Both users can now interact normally
```

---

## Edge Cases

### What if both users block each other?
- Effectively becomes bidirectional (neither sees the other's messages)
- Both get 403 when trying to send
- This is by choice, not forced

### What about existing matches/events?
- Blocked users stay in existing matches/events (they're already members)
- Blocker just doesn't see their messages
- Blocked user gets 403 when trying to send

### Can admin see blocked user interactions?
- Admin queries don't go through RLS policies
- Admin can see all messages and blocks
- Useful for moderation and debugging

---

## API Usage

### Block a User
```typescript
const { error } = await supabase
  .from('blocked_users')
  .insert({
    blocker_id: currentUserId,
    blocked_id: userToBlockId,
    reason: 'spam' // optional
  });
```

### Unblock a User
```typescript
const { error } = await supabase
  .from('blocked_users')
  .delete()
  .match({
    blocker_id: currentUserId,
    blocked_id: userToUnblockId
  });
```

### Check if User is Blocked
```typescript
const { data, error } = await supabase
  .from('blocked_users')
  .select('id')
  .match({
    blocker_id: currentUserId,
    blocked_id: otherUserId
  })
  .single();

const isBlocked = !!data;
```

### Get List of Blocked Users
```typescript
const { data, error } = await supabase
  .from('blocked_users')
  .select('blocked_id, profiles:blocked_id(id, username, avatar_url)')
  .eq('blocker_id', currentUserId);
```

---

## Summary

**Unilateral blocking gives users control over their own experience without alerting potential harassers.**

- ✅ Blocker hides blocked user's content
- ✅ Blocked user can still send (but blocker won't see it)
- ✅ Blocked user doesn't immediately know
- ✅ Safer and more privacy-focused
- ✅ Matches modern social platform behavior
