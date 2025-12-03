# Supabase Security Configuration

This document outlines manual security configuration steps that need to be completed in the Supabase Dashboard.

## Auth Configuration

### Enable Leaked Password Protection

**Status:** ⚠️ Not Enabled (Pro Plan Required)

**Description:** Supabase Auth can prevent users from using compromised passwords by checking against the HaveIBeenPwned.org database. This feature is currently disabled.

**⚠️ Note:** This feature requires a **Pro plan or higher**. It is not available on the Free tier.

**Steps to Enable (if on Pro plan):**

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Navigate to your project
3. Go to **Authentication** > **Providers** > **Email**
4. Toggle on **"Prevent use of leaked passwords"**
5. The setting will auto-save

**Reference:** https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

**Security Impact:**
- Prevents users from using passwords that have been compromised in data breaches
- Reduces the risk of account takeover attacks
- Improves overall application security

**Decision:** Leaving this disabled on Free tier is acceptable. Consider enabling when upgrading to Pro.

---

## Database Migrations Applied

The following security fixes have been applied via database migrations:

✅ **Function Search Path Security** (Migration: `20251203_fix_function_search_path.sql`)
- Fixed `is_blocked_in_match` function
- Fixed `is_blocked_in_event` function
- Fixed `is_blocked_in_circle` function
- Fixed `get_report_context` function

✅ **Extension Schema Isolation** (Migration: `20251203_move_pg_net_extension.sql`)
- Moved `pg_net` extension from `public` schema to `extensions` schema

---

## Verification

After completing the manual configuration steps above, you can verify all security issues are resolved by running the Supabase Database Linter:

1. Go to **Database** > **Linter** in your Supabase Dashboard
2. Click **Run Linter**
3. Verify that all warnings have been resolved
