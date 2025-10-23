-- Migration: Add Message CRUD RLS Policies
-- This adds UPDATE and DELETE policies for match_messages and event_messages

-- ========== MATCH_MESSAGES POLICIES ==========

-- Enable RLS if not already enabled
ALTER TABLE match_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can update their own match messages
DROP POLICY IF EXISTS "Users can update their own match messages" ON match_messages;
CREATE POLICY "Users can update their own match messages"
ON match_messages FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- Policy: Users can delete their own match messages
DROP POLICY IF EXISTS "Users can delete their own match messages" ON match_messages;
CREATE POLICY "Users can delete their own match messages"
ON match_messages FOR DELETE
USING (sender_id = auth.uid());

-- Grant permissions if not already granted
GRANT UPDATE, DELETE ON match_messages TO authenticated;

-- ========== EVENT_MESSAGES POLICIES ==========

-- Enable RLS if not already enabled
ALTER TABLE event_messages ENABLE ROW LEVEL SECURITY;

-- Policy: Users can update their own event messages
DROP POLICY IF EXISTS "Users can update their own event messages" ON event_messages;
CREATE POLICY "Users can update their own event messages"
ON event_messages FOR UPDATE
USING (sender_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

-- Policy: Users can delete their own event messages
DROP POLICY IF EXISTS "Users can delete their own event messages" ON event_messages;
CREATE POLICY "Users can delete their own event messages"
ON event_messages FOR DELETE
USING (sender_id = auth.uid());

-- Grant permissions if not already granted
GRANT UPDATE, DELETE ON event_messages TO authenticated;

-- ========== VERIFICATION ==========

COMMENT ON POLICY "Users can update their own match messages" ON match_messages
IS 'Allows users to edit their own messages in match chats';

COMMENT ON POLICY "Users can delete their own match messages" ON match_messages
IS 'Allows users to delete their own messages in match chats';

COMMENT ON POLICY "Users can update their own event messages" ON event_messages
IS 'Allows users to edit their own messages in event chats';

COMMENT ON POLICY "Users can delete their own event messages" ON event_messages
IS 'Allows users to delete their own messages in event chats';
