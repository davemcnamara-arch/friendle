# Phase 4: Inactivity Auto-Cleanup System

## Overview

Automatically manages inactive match participants to keep the platform active and engaged:
- **Day 5**: Send "Still interested?" warning notification with "Stay Interested" button
- **Day 7**: Auto-remove inactive participants (NEVER removes if they have upcoming events)

## Architecture

### Database Changes

**Migration**: `MIGRATION_add_inactivity_tracking.sql`

New columns and tables:
- `match_participants.last_interaction_at` - Tracks last user activity timestamp
- `inactivity_warnings` - Tracks Day 5 warnings and their status

### Edge Functions

#### 1. `inactivity-cleanup` (Cron Job)
- **Runs**: Daily via Supabase cron
- **Day 5 Logic**:
  - Finds participants inactive for 5+ days
  - Sends push notifications via OneSignal
  - Records warnings in `inactivity_warnings` table
  - Batches notifications (max 2000 per batch)
- **Day 7 Logic**:
  - Finds participants inactive for 7+ days with pending warnings
  - Checks for upcoming events
  - Removes participants WITHOUT upcoming events
  - Updates warning status to 'removed'

#### 2. `stay-interested` (API Endpoint)
- **Purpose**: Called when user clicks "Stay Interested" button
- **Actions**:
  - Updates `last_interaction_at` to current timestamp
  - Resolves pending inactivity warnings

### Interaction Tracking

`last_interaction_at` is automatically updated when users:
1. **Send match messages** (`index.html:5626-5631`)
2. **Create events** (`index.html:5994-5999`)
3. **Join events** (`index.html:5513-5520`)
4. **Click "Stay Interested"** (via `stay-interested` edge function)

### UI Integration

**Warning Display** (`index.html:5368-5376`):
- Shows prominent red warning box when user has pending inactivity warning
- Displays "⚠️ Still interested?" message
- Includes "👍 Yes, I'm Still Interested" button
- Only shown to users in matches with pending warnings

## Deployment Instructions

### 1. Run Database Migration

```sql
-- Run in Supabase SQL Editor
-- File: MIGRATION_add_inactivity_tracking.sql
```

This will:
- Add `last_interaction_at` column to `match_participants`
- Create `inactivity_warnings` table
- Add necessary indexes
- Initialize existing records with current timestamp

### 2. Deploy Edge Functions

```bash
# Deploy inactivity-cleanup function
supabase functions deploy inactivity-cleanup

# Deploy stay-interested function
supabase functions deploy stay-interested
```

### 3. Set Environment Variables

Required environment variables in Supabase:
- `ONESIGNAL_REST_API_KEY` - OneSignal REST API key for push notifications
- `SUPABASE_URL` - Auto-provided by Supabase
- `SUPABASE_SERVICE_ROLE_KEY` - Auto-provided by Supabase

Set in Supabase Dashboard:
1. Go to Project Settings → Edge Functions
2. Add secret: `ONESIGNAL_REST_API_KEY`

### 4. Set Up Cron Job

**Option A: Supabase Cron (Recommended)**

Create a cron job in Supabase Dashboard:
1. Go to Database → Cron Jobs (via pg_cron extension)
2. Create new job:

```sql
-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create daily job at 10:00 AM UTC
SELECT cron.schedule(
    'inactivity-cleanup-daily',
    '0 10 * * *',  -- Every day at 10:00 AM UTC
    $$
    SELECT
      net.http_post(
          url:='https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/inactivity-cleanup',
          headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
      ) as request_id;
    $$
);
```

**Option B: External Cron (Alternative)**

Use an external service like:
- GitHub Actions (with scheduled workflows)
- Vercel Cron
- Cron-job.org

Example curl command:
```bash
curl -X POST \
  https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/inactivity-cleanup \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

## Testing

### Manual Testing

#### Test Stay Interested:
1. Open browser console
2. Run: `await stayInterested('MATCH_ID')`
3. Verify `last_interaction_at` is updated in database
4. Verify warning status changes to 'resolved'

#### Test Inactivity Cleanup:
```bash
# Manually trigger the edge function
curl -X POST \
  https://kxsewkjbhxtfqbytftbu.supabase.co/functions/v1/inactivity-cleanup \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

#### Simulate Inactive User:
```sql
-- Manually set a user as inactive (for testing)
UPDATE match_participants
SET last_interaction_at = NOW() - INTERVAL '6 days'
WHERE profile_id = 'USER_ID' AND match_id = 'MATCH_ID';

-- Then run the edge function to see Day 5 warning
```

### Verify Upcoming Events Check:
```sql
-- Create a future event for the inactive user
-- Then manually trigger Day 7 removal
-- User should NOT be removed if they have upcoming events
```

## Monitoring

### Check Warning Status:
```sql
SELECT
    iw.*,
    p.name as user_name,
    m.activity_id,
    mp.last_interaction_at,
    EXTRACT(DAY FROM NOW() - mp.last_interaction_at) as days_inactive
FROM inactivity_warnings iw
JOIN profiles p ON iw.profile_id = p.id
JOIN matches m ON iw.match_id = m.id
JOIN match_participants mp ON mp.match_id = iw.match_id AND mp.profile_id = iw.profile_id
WHERE iw.status = 'pending'
ORDER BY iw.warned_at DESC;
```

### Check Inactive Users:
```sql
SELECT
    mp.*,
    p.name,
    EXTRACT(DAY FROM NOW() - mp.last_interaction_at) as days_inactive,
    EXISTS(
        SELECT 1 FROM events e
        JOIN event_participants ep ON e.id = ep.event_id
        WHERE e.match_id = mp.match_id
        AND ep.profile_id = mp.profile_id
        AND e.scheduled_date >= NOW()
        AND e.status = 'scheduled'
    ) as has_upcoming_events
FROM match_participants mp
JOIN profiles p ON mp.profile_id = p.id
WHERE mp.last_interaction_at < NOW() - INTERVAL '5 days'
ORDER BY mp.last_interaction_at ASC;
```

### View Edge Function Logs:
```bash
# View inactivity-cleanup logs
supabase functions logs inactivity-cleanup --tail

# View stay-interested logs
supabase functions logs stay-interested --tail
```

## Key Features

✅ **Batched Notifications** - Sends up to 2000 notifications per batch to avoid rate limits

✅ **Smart Removal** - Never removes users with upcoming events

✅ **Activity Tracking** - Automatically tracks all user interactions

✅ **Visual Warnings** - Prominent UI warning when user needs to confirm interest

✅ **Performance Optimized** - Uses batch queries to minimize database calls

✅ **Clean Up Old Data** - Automatically removes warnings older than 30 days

## Troubleshooting

### Warning not showing up:
1. Check if warning exists: `SELECT * FROM inactivity_warnings WHERE profile_id = 'USER_ID'`
2. Verify user is inactive: `SELECT last_interaction_at FROM match_participants WHERE profile_id = 'USER_ID'`
3. Check browser console for errors

### Edge function not running:
1. Check cron job status: `SELECT * FROM cron.job WHERE jobname = 'inactivity-cleanup-daily'`
2. View function logs in Supabase Dashboard
3. Verify environment variables are set

### User not being removed on Day 7:
1. Check if they have upcoming events
2. Verify they have a pending warning
3. Check edge function logs for errors

## Future Enhancements

Possible improvements:
- Configurable inactivity periods (admin setting)
- Email notifications in addition to push
- Grace period extension option
- Analytics dashboard for inactivity metrics
- Re-engagement campaigns for removed users
