-- Migration: Add message read tracking tables
-- Description: Track which users have read which messages for read count display

-- Create circle_message_reads table
CREATE TABLE IF NOT EXISTS circle_message_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES circle_messages(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, profile_id)
);

-- Create event_message_reads table
CREATE TABLE IF NOT EXISTS event_message_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES event_messages(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, profile_id)
);

-- Create match_message_reads table
CREATE TABLE IF NOT EXISTS match_message_reads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES match_messages(id) ON DELETE CASCADE,
    profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(message_id, profile_id)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_circle_message_reads_message_id ON circle_message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_circle_message_reads_profile_id ON circle_message_reads(profile_id);

CREATE INDEX IF NOT EXISTS idx_event_message_reads_message_id ON event_message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_event_message_reads_profile_id ON event_message_reads(profile_id);

CREATE INDEX IF NOT EXISTS idx_match_message_reads_message_id ON match_message_reads(message_id);
CREATE INDEX IF NOT EXISTS idx_match_message_reads_profile_id ON match_message_reads(profile_id);

-- RLS Policies for circle_message_reads
ALTER TABLE circle_message_reads ENABLE ROW LEVEL SECURITY;

-- Users can insert their own read records
CREATE POLICY "Users can mark circle messages as read"
    ON circle_message_reads FOR INSERT
    WITH CHECK (auth.uid() = profile_id);

-- Users can view read records for messages in circles they're members of
CREATE POLICY "Users can view read records in their circles"
    ON circle_message_reads FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM circle_members cm
            JOIN circle_messages msg ON msg.circle_id = cm.circle_id
            WHERE cm.profile_id = auth.uid()
            AND msg.id = circle_message_reads.message_id
        )
    );

-- RLS Policies for event_message_reads
ALTER TABLE event_message_reads ENABLE ROW LEVEL SECURITY;

-- Users can insert their own read records
CREATE POLICY "Users can mark event messages as read"
    ON event_message_reads FOR INSERT
    WITH CHECK (auth.uid() = profile_id);

-- Users can view read records for messages in events they're participants of
CREATE POLICY "Users can view read records in their events"
    ON event_message_reads FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM event_participants ep
            JOIN event_messages msg ON msg.event_id = ep.event_id
            WHERE ep.profile_id = auth.uid()
            AND msg.id = event_message_reads.message_id
        )
    );

-- RLS Policies for match_message_reads
ALTER TABLE match_message_reads ENABLE ROW LEVEL SECURITY;

-- Users can insert their own read records
CREATE POLICY "Users can mark match messages as read"
    ON match_message_reads FOR INSERT
    WITH CHECK (auth.uid() = profile_id);

-- Users can view read records for messages in matches they're participants of
CREATE POLICY "Users can view read records in their matches"
    ON match_message_reads FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM match_participants mp
            JOIN match_messages msg ON msg.match_id = mp.match_id
            WHERE mp.profile_id = auth.uid()
            AND msg.id = match_message_reads.message_id
        )
    );
