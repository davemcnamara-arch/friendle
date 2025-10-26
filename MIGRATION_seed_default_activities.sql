-- ============================================================================
-- SEED DEFAULT ACTIVITIES MIGRATION
-- ============================================================================
-- Purpose: Insert default global activities that all circles can use
-- These activities have circle_id = NULL to indicate they're global/default
-- ============================================================================

BEGIN;

-- First, delete any existing default activities to avoid duplicates
DELETE FROM activities WHERE circle_id IS NULL;

-- Core Activities (most commonly used)
INSERT INTO activities (id, name, emoji, circle_id) VALUES
-- Social & Food
(gen_random_uuid(), 'Coffee', '☕', NULL),
(gen_random_uuid(), 'Dinner', '🍽️', NULL),
(gen_random_uuid(), 'Drinks', '🍻', NULL),
(gen_random_uuid(), 'Brunch', '🥞', NULL),
(gen_random_uuid(), 'Pizza Night', '🍕', NULL),
(gen_random_uuid(), 'Ice Cream', '🍦', NULL),

-- Outdoor Activities
(gen_random_uuid(), 'Hiking', '🥾', NULL),
(gen_random_uuid(), 'Beach', '🏖️', NULL),
(gen_random_uuid(), 'Walk in the Park', '🌳', NULL),

-- Entertainment
(gen_random_uuid(), 'Bowling', '🎳', NULL),
(gen_random_uuid(), 'Movie', '🎬', NULL),
(gen_random_uuid(), 'Trivia Night', '🧠', NULL),
(gen_random_uuid(), 'Arcade', '🕹️', NULL),
(gen_random_uuid(), 'Board Games', '🎲', NULL);

-- Extended Activities (additional options)
INSERT INTO activities (id, name, emoji, circle_id) VALUES
-- More Food & Dining
(gen_random_uuid(), 'Breakfast', '🍳', NULL),
(gen_random_uuid(), 'Lunch', '🥗', NULL),
(gen_random_uuid(), 'Happy Hour', '🍹', NULL),
(gen_random_uuid(), 'BBQ', '🍖', NULL),
(gen_random_uuid(), 'Sushi', '🍣', NULL),
(gen_random_uuid(), 'Tacos', '🌮', NULL),
(gen_random_uuid(), 'Burgers', '🍔', NULL),
(gen_random_uuid(), 'Dessert', '🍰', NULL),

-- Sports & Fitness
(gen_random_uuid(), 'Gym', '💪', NULL),
(gen_random_uuid(), 'Yoga', '🧘', NULL),
(gen_random_uuid(), 'Running', '🏃', NULL),
(gen_random_uuid(), 'Cycling', '🚴', NULL),
(gen_random_uuid(), 'Swimming', '🏊', NULL),
(gen_random_uuid(), 'Tennis', '🎾', NULL),
(gen_random_uuid(), 'Basketball', '🏀', NULL),
(gen_random_uuid(), 'Soccer', '⚽', NULL),
(gen_random_uuid(), 'Golf', '⛳', NULL),
(gen_random_uuid(), 'Rock Climbing', '🧗', NULL),

-- Arts & Culture
(gen_random_uuid(), 'Museum', '🖼️', NULL),
(gen_random_uuid(), 'Concert', '🎵', NULL),
(gen_random_uuid(), 'Theater', '🎭', NULL),
(gen_random_uuid(), 'Art Gallery', '🎨', NULL),
(gen_random_uuid(), 'Comedy Show', '😂', NULL),
(gen_random_uuid(), 'Karaoke', '🎤', NULL),

-- Outdoor & Adventure
(gen_random_uuid(), 'Camping', '⛺', NULL),
(gen_random_uuid(), 'Picnic', '🧺', NULL),
(gen_random_uuid(), 'Fishing', '🎣', NULL),
(gen_random_uuid(), 'Biking', '🚵', NULL),
(gen_random_uuid(), 'Park Hangout', '🌲', NULL),

-- Indoor Activities
(gen_random_uuid(), 'Video Games', '🎮', NULL),
(gen_random_uuid(), 'Book Club', '📚', NULL),
(gen_random_uuid(), 'Cooking Together', '👨‍🍳', NULL),
(gen_random_uuid(), 'Wine Tasting', '🍷', NULL),
(gen_random_uuid(), 'Crafts', '✂️', NULL),
(gen_random_uuid(), 'Movie Night', '📺', NULL),
(gen_random_uuid(), 'Game Night', '🃏', NULL),

-- Social Events
(gen_random_uuid(), 'Party', '🎉', NULL),
(gen_random_uuid(), 'Dance', '💃', NULL),
(gen_random_uuid(), 'Meetup', '👥', NULL),
(gen_random_uuid(), 'Study Session', '📖', NULL),
(gen_random_uuid(), 'Volunteering', '🤝', NULL);

COMMIT;

-- ============================================================================
-- VERIFICATION QUERY
-- ============================================================================
-- Run this to verify the default activities were inserted:

SELECT
    COUNT(*) as total_default_activities,
    COUNT(CASE WHEN name IN ('Coffee', 'Dinner', 'Drinks', 'Brunch', 'Pizza Night', 'Ice Cream',
                              'Hiking', 'Beach', 'Bowling', 'Walk in the Park',
                              'Movie', 'Trivia Night', 'Arcade', 'Board Games') THEN 1 END) as core_activities,
    COUNT(CASE WHEN name NOT IN ('Coffee', 'Dinner', 'Drinks', 'Brunch', 'Pizza Night', 'Ice Cream',
                                  'Hiking', 'Beach', 'Bowling', 'Walk in the Park',
                                  'Movie', 'Trivia Night', 'Arcade', 'Board Games') THEN 1 END) as extended_activities
FROM activities
WHERE circle_id IS NULL;

-- Expected: total_default_activities = 57, core_activities = 14, extended_activities = 43

-- View all default activities:
SELECT id, name, emoji
FROM activities
WHERE circle_id IS NULL
ORDER BY name;
