# Local Development & Testing Guide

This guide explains how to test Friendle changes offline before deploying to production, avoiding user disruption.

## Current Situation

- **Production Database**: Single Supabase project (kxsewkjbhxtfqbytftbu.supabase.co)
- **No Staging Environment**: Changes are tested directly on production
- **Risk**: Database migrations and code changes can affect live users

---

## Solution 1: Local Supabase (Recommended for Offline Testing)

### Prerequisites

- Docker Desktop installed and running
- Node.js 16+ and npm

### Setup Steps

```bash
# 1. Install Supabase CLI
npm install -g supabase

# 2. Initialize local Supabase
cd /home/user/friendle
supabase init

# 3. Start local Supabase stack
supabase start
```

**What this provides:**
- Local PostgreSQL database (port 54322)
- Local Edge Functions runtime (port 54321)
- Local Studio UI (http://localhost:54323)
- Local authentication service
- Complete isolation from production

### Configuration

After `supabase start`, you'll see output like:

```
API URL: http://localhost:54321
DB URL: postgresql://postgres:postgres@localhost:54322/postgres
Studio URL: http://localhost:54323
anon key: eyJhbG...
service_role key: eyJhbG...
```

#### Option A: Create a Local HTML File

Create `index-local.html` (copy of index.html with local config):

```javascript
// Replace these lines in index-local.html
const SUPABASE_URL = "http://localhost:54321";
const SUPABASE_ANON_KEY = "your-local-anon-key-from-supabase-start";
```

#### Option B: Dynamic Environment Detection (Recommended)

Modify `index.html` to auto-detect environment:

```javascript
// Add at the top of the script section
const isLocal = window.location.hostname === 'localhost' ||
                window.location.hostname === '127.0.0.1';

const SUPABASE_URL = isLocal
  ? "http://localhost:54321"
  : "https://kxsewkjbhxtfqbytftbu.supabase.co";

const SUPABASE_ANON_KEY = isLocal
  ? "eyJhbG...(local-anon-key)"
  : "(production-anon-key)";
```

### Apply Migrations Locally

```bash
# Copy all MIGRATION_*.sql files to supabase/migrations/ directory
mkdir -p supabase/migrations
cp MIGRATION_*.sql supabase/migrations/

# Reset local database and apply all migrations
supabase db reset
```

### Testing Workflow

1. **Make changes** to `index.html` or Edge Functions
2. **Open local version**: `http://localhost:8000` (serve with `python3 -m http.server`)
3. **Test functionality** - Create users, circles, events
4. **Test Edge Functions**:
   ```bash
   # Deploy functions to local runtime
   supabase functions deploy event-reminders --no-verify-jwt

   # Test function locally
   curl -i http://localhost:54321/functions/v1/event-reminders \
     -H "Authorization: Bearer YOUR_LOCAL_ANON_KEY"
   ```
5. **Verify migrations** in local Studio: http://localhost:54323
6. **Once verified**, deploy to production

### Testing Edge Functions Locally

```bash
# Serve Edge Functions locally
supabase functions serve

# Test individual function
deno run --allow-net --allow-env \
  supabase/functions/event-reminders/index.ts
```

---

## Solution 2: Staging Supabase Project

### Setup

1. **Create new Supabase project** at https://app.supabase.com
   - Name: "Friendle Staging"
   - Region: Same as production (for consistency)

2. **Configure staging project**:
   - Copy all MIGRATION_*.sql files
   - Run migrations in Supabase SQL Editor (in order)
   - Set environment variables for Edge Functions:
     - `ONESIGNAL_REST_API_KEY` (use test key if available)

3. **Deploy Edge Functions to staging**:
   ```bash
   # Link to staging project
   supabase link --project-ref YOUR_STAGING_PROJECT_ID

   # Deploy functions
   supabase functions deploy event-reminders
   supabase functions deploy inactivity-cleanup
   supabase functions deploy send-notification
   supabase functions deploy stay-interested
   ```

4. **Create staging HTML file**:
   - Copy `index.html` to `index-staging.html`
   - Update Supabase URL and keys for staging project
   - Deploy to staging subdomain (e.g., staging.friendlecircles.app)

### Testing on Staging

1. Make changes on feature branch
2. Deploy to staging Supabase project
3. Test with real users (beta testers) or test accounts
4. Once verified, deploy same changes to production

---

## Solution 3: Hybrid Approach (Quick Start)

**For testing without full local setup:**

1. **Branch-based testing**:
   - Create feature branch (already doing this)
   - Deploy branch to temporary preview URL (Vercel/Netlify)
   - Connect to staging Supabase project

2. **Database transactions for testing**:
   ```sql
   -- In Supabase SQL Editor
   BEGIN;
   -- Run your migration or test query
   SELECT * FROM profiles;
   ROLLBACK; -- Undo changes
   ```

3. **Use test accounts**:
   - Create dedicated test users
   - Use test circles/events
   - Verify RLS policies with test data

---

## Testing Checklist Before Deployment

### Frontend Changes
- [ ] Test on local/staging environment
- [ ] Verify PWA functionality (offline mode)
- [ ] Test notification permissions
- [ ] Check mobile responsiveness
- [ ] Verify XSS sanitization

### Database Migrations
- [ ] Run migration on local/staging database first
- [ ] Verify RLS policies (use `RLS_TESTING_GUIDE.md`)
- [ ] Check foreign key constraints
- [ ] Test with existing data patterns
- [ ] Backup production database before applying

### Edge Functions
- [ ] Test locally with Deno or `supabase functions serve`
- [ ] Verify environment variables are set
- [ ] Test error handling and edge cases
- [ ] Check logging and monitoring
- [ ] Verify cron job schedules

### Integration Testing
- [ ] Test notification delivery (use `test-notifications.html`)
- [ ] Verify chat functionality
- [ ] Test event reminders manually (trigger cron job)
- [ ] Check inactivity cleanup logic
- [ ] Test across different timezones

---

## Quick Commands Reference

### Local Supabase
```bash
supabase start           # Start local stack
supabase stop            # Stop local stack
supabase db reset        # Reset and re-run migrations
supabase functions serve # Serve Edge Functions locally
supabase status          # Check running services
```

### Testing Edge Functions
```bash
# Test event reminders locally
deno run --allow-net --allow-env \
  supabase/functions/event-reminders/index.ts

# Test with local Supabase
curl http://localhost:54321/functions/v1/event-reminders \
  -H "Authorization: Bearer ANON_KEY"
```

### Serve Frontend Locally
```bash
# Python 3
python3 -m http.server 8000

# Or use any static server
npx http-server -p 8000
```

---

## Recommended Workflow

1. **Development Phase**:
   - Make changes on feature branch
   - Test locally with `supabase start` + local HTML
   - Run manual tests from `RLS_TESTING_GUIDE.md`

2. **Pre-Production Phase**:
   - Deploy to staging Supabase project (if available)
   - Test with real-world scenarios
   - Share staging link with beta testers

3. **Production Deployment**:
   - Backup production database
   - Apply migrations during low-traffic period
   - Deploy Edge Functions
   - Update frontend (index.html)
   - Monitor for errors

4. **Post-Deployment**:
   - Verify cron jobs are running
   - Check Edge Function logs
   - Monitor user reports
   - Have rollback plan ready

---

## Next Steps

1. **Immediate**: Install Supabase CLI and set up local environment
2. **Short-term**: Create staging Supabase project for pre-production testing
3. **Long-term**: Consider automated testing (Jest, Playwright) and CI/CD pipeline

---

## Additional Resources

- **Supabase Local Development**: https://supabase.com/docs/guides/cli/local-development
- **Edge Functions Testing**: https://supabase.com/docs/guides/functions/local-development
- **Database Migrations**: https://supabase.com/docs/guides/cli/local-development#database-migrations

---

## Troubleshooting

### Local Supabase won't start
- Ensure Docker Desktop is running
- Check port availability (54321, 54322, 54323)
- Run `supabase stop` and try again

### Edge Functions fail locally
- Check environment variables are set
- Verify Deno permissions (--allow-net, --allow-env)
- Check function logs with `supabase functions logs`

### Database migration errors
- Verify migration order (run in sequence)
- Check for dependency conflicts
- Use `supabase db reset` to start fresh

---

## Contact

If you encounter issues with local development setup, refer to:
- `RLS_TESTING_GUIDE.md` - Security testing procedures
- `EVENT_REMINDERS_DEBUG_REPORT.md` - Edge function debugging
- `DATABASE_RESET_GUIDE.md` - Database management
