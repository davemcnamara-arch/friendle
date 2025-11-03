# Report Email Alerts Setup Guide

This guide explains how to set up automatic email notifications when users submit reports in Friendle.

---

## 📋 Overview

When a user submits a report, you'll automatically receive an email with:
- Report details (ID, category, reason)
- Reporter information
- Reported content details
- Links to review in Supabase
- SQL commands to update report status

---

## 🚀 Quick Setup (Recommended)

The **easiest way** is using Supabase Database Webhooks:

### 1. Deploy the Edge Function

```bash
supabase functions deploy send-report-alert
```

### 2. Configure Environment Variables

In **Supabase Dashboard → Settings → Edge Functions → Environment Variables**, add:

| Variable | Value | Description |
|----------|-------|-------------|
| `ADMIN_EMAIL` | `your-email@example.com` | Where to send report alerts |
| `RESEND_API_KEY` | `re_xxxxxxxxxxxxx` | API key from [resend.com](https://resend.com) |

### 3. Create Database Webhook

In **Supabase Dashboard → Database → Webhooks**:

1. Click **"Create a new hook"**
2. Configure:
   - **Name**: `report-created-alert`
   - **Table**: `reports`
   - **Events**: Check **"INSERT"**
   - **Type**: **"Supabase Edge Functions"**
   - **Edge Function**: `send-report-alert`
3. Click **"Create webhook"**

### 4. Test It!

Create a test report in your app. You should receive an email within seconds!

---

## 📧 Email Service Setup

### Option 1: Resend (Recommended - Easy & Free Tier)

1. Sign up at [resend.com](https://resend.com)
2. Get your API key
3. Add to Supabase environment variables: `RESEND_API_KEY=re_xxxxx`
4. Done! ✅

**Free Tier**: 100 emails/day, 3,000/month

---

### Option 2: SendGrid

Modify `/supabase/functions/send-report-alert/index.ts`:

```typescript
const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')

// Replace the Resend API call with:
const sendgridResponse = await fetch('https://api.sendgrid.com/v3/mail/send', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${SENDGRID_API_KEY}`
  },
  body: JSON.stringify({
    personalizations: [{ to: [{ email: ADMIN_EMAIL }] }],
    from: { email: 'reports@yourdomain.com' },
    subject: emailSubject,
    content: [{ type: 'text/plain', value: emailBody }]
  })
})
```

**Free Tier**: 100 emails/day

---

### Option 3: Postmark

Modify `/supabase/functions/send-report-alert/index.ts`:

```typescript
const POSTMARK_API_KEY = Deno.env.get('POSTMARK_API_KEY')

// Replace the Resend API call with:
const postmarkResponse = await fetch('https://api.postmarkapp.com/email', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Postmark-Server-Token': POSTMARK_API_KEY
  },
  body: JSON.stringify({
    From: 'reports@yourdomain.com',
    To: ADMIN_EMAIL,
    Subject: emailSubject,
    TextBody: emailBody
  })
})
```

**Free Tier**: 100 emails/month

---

## 🔧 Alternative Setup (Database Trigger)

If you prefer using a database trigger instead of webhooks:

1. Deploy the Edge Function (same as above)
2. Configure environment variables (same as above)
3. Run the migration: `MIGRATION_add_report_email_alerts.sql`

This uses `pg_net` to call the Edge Function from the database.

---

## 📨 Email Format

You'll receive emails like this:

```
Subject: 🚨 New Report: harassment

A new report has been submitted in Friendle.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 REPORT DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Report ID: 123e4567-e89b-12d3-a456-426614174000
Status: pending
Created: 1/15/2025, 3:45:22 PM

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤 REPORTER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Name: Alice Smith
ID: abc123...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 REPORTED CONTENT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Type: user
Target: Bob Johnson

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️ REASON
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Category: harassment
Details: Sending inappropriate messages repeatedly

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔗 REVIEW IN SUPABASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

View report in Supabase Dashboard:
https://your-project.supabase.co/project/_/editor

Or run this SQL to get full context:
SELECT get_report_context('123e4567-e89b-12d3-a456-426614174000');
```

---

## 🧪 Testing

### Test the Edge Function Directly

```bash
curl -X POST \
  'https://your-project.supabase.co/functions/v1/send-report-alert' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "record": {
      "id": "test-id",
      "reporter_id": "test-reporter",
      "reported_type": "user",
      "reported_id": "test-user",
      "reason_category": "spam",
      "reason_details": "Test report",
      "status": "pending",
      "created_at": "'$(date -u +%Y-%m-%dT%H:%M:%S.000Z)'"
    }
  }'
```

### Test via Creating a Report

Just create a report in your Friendle app and check your email!

---

## 🐛 Troubleshooting

### Not receiving emails?

1. **Check Environment Variables**:
   - Go to Supabase Dashboard → Settings → Edge Functions
   - Verify `ADMIN_EMAIL` and `RESEND_API_KEY` are set

2. **Check Edge Function Logs**:
   - Go to Supabase Dashboard → Edge Functions → send-report-alert
   - Click "Logs" to see what happened
   - Look for errors like "No RESEND_API_KEY configured"

3. **Check Webhook Status**:
   - Go to Database → Webhooks
   - Check if webhook is enabled
   - View webhook logs to see if it's firing

4. **Test Edge Function Manually**:
   - Use the curl command above
   - Check if you receive an email

5. **Verify Email Service**:
   - Log into Resend/SendGrid/Postmark
   - Check your API key is valid
   - Check your sending domain is verified (if required)

### Email goes to spam?

- Verify your sending domain in your email service
- Use a dedicated subdomain (e.g., `reports@friendle.yourdomain.com`)
- Add SPF, DKIM, and DMARC records to your domain

---

## 🔒 Security Notes

- ✅ Edge Function uses `SECURITY DEFINER` and service role key
- ✅ Only admin receives emails (set via `ADMIN_EMAIL`)
- ✅ Email contains sensitive info - ensure `ADMIN_EMAIL` is secure
- ✅ API keys stored in Supabase environment variables (encrypted)
- ✅ Reporter cannot see other reports or manipulate alerts

---

## 💰 Cost Estimate

| Service | Free Tier | Paid |
|---------|-----------|------|
| **Supabase Edge Functions** | 500K invocations/month | $0.50/million after |
| **Resend** | 3,000 emails/month | $20/month for 50K |
| **SendGrid** | 100 emails/day | $20/month for 40K |
| **Postmark** | 100 emails/month | $15/month for 10K |

For typical usage (a few reports per day), **everything stays within free tiers**! 🎉

---

## 📝 Summary

1. ✅ Deploy Edge Function: `supabase functions deploy send-report-alert`
2. ✅ Add environment variables: `ADMIN_EMAIL` and `RESEND_API_KEY`
3. ✅ Create database webhook in Supabase Dashboard
4. ✅ Test by submitting a report
5. ✅ Check your email inbox!

**That's it!** You'll now get instant email alerts for all new reports. 📧🎉
