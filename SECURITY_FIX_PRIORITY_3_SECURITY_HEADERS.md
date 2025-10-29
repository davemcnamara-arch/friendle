# Priority 3: Security Headers Implementation

## Problem
The app is missing **ALL standard security headers** that protect against common web attacks:
- ❌ No Content-Security-Policy (CSP)
- ❌ No X-Frame-Options (clickjacking protection)
- ❌ No X-Content-Type-Options (MIME sniffing protection)
- ❌ No Referrer-Policy
- ❌ No Permissions-Policy

## Challenge: App Uses Inline Scripts & Styles

**Critical Finding:**
- 362 inline `style=""` attributes
- Many inline `onclick=""` event handlers
- Inline `<style>` blocks
- Inline `<script>` blocks

**This means:** We CANNOT use strict CSP without breaking the app.

**Compromise:** Use CSP with `'unsafe-inline'` but still restrict external sources.

---

## Solution: App-Compatible Security Headers

### Headers to Add

Add these `<meta>` tags to `index.html` in the `<head>` section (around line 11, after viewport meta tag):

```html
<!-- ========================================
     SECURITY HEADERS
     ========================================
     These headers protect against common web attacks
     while maintaining compatibility with inline scripts/styles
     ======================================== -->

<!-- Content Security Policy: Controls what resources can be loaded -->
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self';
               script-src 'self' 'unsafe-inline' https://cdn.supabase.co https://cdn.onesignal.com https://unpkg.com;
               style-src 'self' 'unsafe-inline' https://fonts.googleapis.com;
               font-src 'self' https://fonts.gstatic.com;
               img-src 'self' data: blob: https://kxsewkjbhxtfqbytftbu.supabase.co https://onesignal.com;
               connect-src 'self' https://kxsewkjbhxtfqbytftbu.supabase.co https://onesignal.com https://api.onesignal.com wss://kxsewkjbhxtfqbytftbu.supabase.co;
               frame-src 'none';
               object-src 'none';
               base-uri 'self';
               form-action 'self';
               frame-ancestors 'none';
               upgrade-insecure-requests;">

<!-- Prevent clickjacking attacks -->
<meta http-equiv="X-Frame-Options" content="DENY">

<!-- Prevent MIME type sniffing -->
<meta http-equiv="X-Content-Type-Options" content="nosniff">

<!-- Control referrer information -->
<meta http-equiv="Referrer-Policy" content="strict-origin-when-cross-origin">

<!-- Control browser features/permissions -->
<meta http-equiv="Permissions-Policy"
      content="geolocation=(),
               microphone=(),
               camera=(),
               payment=(),
               usb=(),
               magnetometer=(),
               gyroscope=(),
               accelerometer=()">
```

---

## CSP Directive Breakdown

Let me explain each CSP directive:

### `default-src 'self'`
- Default policy: only load resources from same origin
- Fallback for directives not explicitly set

### `script-src 'self' 'unsafe-inline' https://cdn.supabase.co ...`
- **'self'**: Load scripts from same origin
- **'unsafe-inline'**: Allow inline `<script>` and `onclick=""` (REQUIRED for app)
- **https://cdn.supabase.co**: Supabase client library
- **https://cdn.onesignal.com**: OneSignal push notifications
- **https://unpkg.com**: Supabase dependencies

⚠️ **'unsafe-inline' reduces security** but is necessary due to app architecture

### `style-src 'self' 'unsafe-inline' https://fonts.googleapis.com`
- **'self'**: Load CSS from same origin
- **'unsafe-inline'**: Allow inline `<style>` and `style=""` (REQUIRED - 362 uses)
- **https://fonts.googleapis.com**: Google Fonts CSS

### `font-src 'self' https://fonts.gstatic.com`
- Allow fonts from same origin and Google Fonts CDN

### `img-src 'self' data: blob: https://...`
- **'self'**: Images from same origin
- **data:**: Data URIs (base64 images)
- **blob:**: Blob URLs (for image previews)
- **https://kxsewkjbhxtfqbytftbu.supabase.co**: User uploaded avatars/photos
- **https://onesignal.com**: OneSignal notification icons

### `connect-src 'self' https://... wss://...`
- Controls AJAX, fetch, WebSocket connections
- **Supabase**: Database queries
- **OneSignal**: Push notification API
- **wss://**: WebSocket for Realtime subscriptions

### `frame-src 'none'`
- Block ALL iframes - app doesn't use iframes

### `object-src 'none'`
- Block plugins (Flash, Java, etc.)

### `base-uri 'self'`
- Prevent `<base>` tag injection attacks

### `form-action 'self'`
- Forms can only submit to same origin

### `frame-ancestors 'none'`
- Prevent page from being embedded in iframes (clickjacking protection)
- Same as X-Frame-Options but for CSP

### `upgrade-insecure-requests`
- Automatically upgrade HTTP to HTTPS

---

## Other Security Headers Explained

### X-Frame-Options: DENY
- Prevents page from being loaded in `<iframe>`
- Protects against clickjacking attacks
- Redundant with CSP `frame-ancestors 'none'` but provides fallback

### X-Content-Type-Options: nosniff
- Prevents browser from MIME-sniffing
- Forces browser to respect Content-Type headers
- Prevents attacks where attacker uploads `.jpg` containing JavaScript

### Referrer-Policy: strict-origin-when-cross-origin
- Controls Referer header sent to other sites
- **Same-origin**: Full URL sent
- **Cross-origin**: Only origin sent (not full path)
- **HTTPS→HTTP**: Nothing sent
- Protects user privacy and prevents leaking sensitive URLs

### Permissions-Policy
- Blocks browser features the app doesn't use
- Prevents malicious scripts from accessing:
  - Geolocation
  - Camera/Microphone
  - Payment API
  - USB devices
  - Motion sensors
- Even if XSS occurs, attacker can't access these features

---

## Implementation Steps

### Step 1: Locate the `<head>` section in index.html

Around line 3-11:

```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Friendle - Who's in?</title>

    <!-- ADD SECURITY HEADERS HERE -->

    <link rel="manifest" href="/manifest.json">
    ...
</head>
```

### Step 2: Add Security Headers

Insert the security headers block from above.

### Step 3: Test Thoroughly

**Expected Behavior:**
- ✅ App loads normally
- ✅ All features work
- ✅ No console errors
- ✅ Images load
- ✅ Fonts load
- ✅ Supabase connections work
- ✅ OneSignal works

**Common Issues & Fixes:**

#### Issue 1: "Refused to load script"
**Cause:** Missing domain in `script-src`
**Fix:** Add domain to CSP

#### Issue 2: "Refused to connect"
**Cause:** Missing domain in `connect-src`
**Fix:** Add API endpoint to CSP

#### Issue 3: "Refused to load image"
**Cause:** Missing domain in `img-src`
**Fix:** Add image host to CSP

### Step 4: Verify CSP is Active

Open browser DevTools → Console:
- If CSP is working, you'll see warnings for blocked resources (if any)
- No warnings = CSP is allowing everything correctly

---

## Testing Checklist

After adding security headers:

**Basic Functionality:**
- [ ] App loads without errors
- [ ] Can sign up / log in
- [ ] Can create circles
- [ ] Can upload profile picture
- [ ] Can send messages
- [ ] Can create events
- [ ] OneSignal notifications work
- [ ] All buttons and clicks work

**Security Verification:**
- [ ] Check DevTools console for CSP violations
- [ ] Try embedding app in iframe (should fail)
- [ ] Verify with https://securityheaders.com
- [ ] Test on mobile device
- [ ] Test in incognito/private mode

**Browser Compatibility:**
- [ ] Chrome/Edge
- [ ] Firefox
- [ ] Safari (iOS)
- [ ] Mobile browsers

---

## Security Impact

### What This DOES Protect Against:

✅ **External script injection** - Attackers can't load scripts from malicious domains
✅ **Clickjacking** - Page can't be embedded in iframe to trick users
✅ **MIME sniffing attacks** - Browser can't reinterpret file types
✅ **Referrer leakage** - Sensitive URLs not leaked to third parties
✅ **Unwanted permissions** - Malicious scripts can't access camera/location
✅ **HTTP downgrade** - All requests upgraded to HTTPS

### What This DOESN'T Protect Against:

⚠️ **Inline XSS** - CSP allows 'unsafe-inline' due to app architecture
⚠️ **Stored XSS** - CSP doesn't prevent XSS, just limits damage
⚠️ **DOM-based XSS** - Inline scripts can still be vulnerable

**Mitigation:** The `sanitizeHTML()` function (already implemented) provides XSS protection.

---

## Future Improvements

### Phase 1: Remove Inline Event Handlers

Convert inline `onclick=""` to event listeners:

**Before:**
```html
<button onclick="showPage('matches')">Matches</button>
```

**After:**
```html
<button id="matches-btn">Matches</button>
<script>
  document.getElementById('matches-btn').addEventListener('click', () => {
    showPage('matches');
  });
</script>
```

**Benefit:** Can remove `'unsafe-inline'` from script-src

### Phase 2: Extract Inline Styles

Move inline `style=""` to CSS classes:

**Before:**
```html
<div style="color: red; font-size: 14px;">Error</div>
```

**After:**
```html
<div class="error-message">Error</div>
<style>
.error-message { color: red; font-size: 14px; }
</style>
```

**Benefit:** Can remove `'unsafe-inline'` from style-src

### Phase 3: Use Nonces or Hashes

For inline scripts that remain, use CSP nonces:

```html
<meta http-equiv="Content-Security-Policy"
      content="script-src 'self' 'nonce-abc123';">

<script nonce="abc123">
  // This script is allowed
</script>
```

**Benefit:** Strict CSP without 'unsafe-inline'

### Phase 4: Implement CSP Reporting

Add CSP violation reporting:

```html
<meta http-equiv="Content-Security-Policy"
      content="...; report-uri /api/csp-report;">
```

Create Edge Function to receive CSP violation reports and send alerts.

**Benefit:** Monitor for CSP violations and potential attacks

---

## Professional Deployment

For production, consider using HTTP headers instead of meta tags:

**Supabase Hosting / Vercel:**
Create `vercel.json`:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.supabase.co ..."
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        },
        {
          "key": "Permissions-Policy",
          "value": "geolocation=(), microphone=(), camera=()"
        }
      ]
    }
  ]
}
```

**Benefit:** HTTP headers are more secure than meta tags (can't be injected)

---

## Comparison: With vs Without Headers

| Attack | Without Headers | With Headers |
|--------|-----------------|--------------|
| **Clickjacking** | ❌ Vulnerable | ✅ Protected |
| **MIME Sniffing** | ❌ Vulnerable | ✅ Protected |
| **External Script Injection** | ❌ Vulnerable | ✅ Protected |
| **Referrer Leakage** | ❌ Leaks full URLs | ✅ Only origin sent |
| **Unwanted Camera Access** | ⚠️ Possible | ✅ Blocked |
| **HTTP Downgrade** | ⚠️ Possible | ✅ Auto-upgraded |
| **Inline XSS** | ❌ Vulnerable | ⚠️ Still vulnerable* |

*Mitigated by `sanitizeHTML()` function

---

## Verification Tools

After deployment, test with:

1. **https://securityheaders.com**
   - Enter your app URL
   - Should get A or A+ rating

2. **Chrome DevTools → Security Tab**
   - Check "Secure connection"
   - Verify certificate

3. **CSP Evaluator**
   - https://csp-evaluator.withgoogle.com
   - Paste your CSP
   - Check for issues

4. **Observatory by Mozilla**
   - https://observatory.mozilla.org
   - Scan your site
   - Get security recommendations

---

## Related Files

- `index.html` (lines 3-11) - Add headers here
- `SECURITY_AUDIT_REPORT.md` - Original finding

---

**Status**: ✅ SAFE TO IMPLEMENT
**Risk**: 🟡 MEDIUM (CSP can break things if misconfigured)
**Benefit**: 🔴 HIGH (Blocks multiple attack vectors)

**Testing Required**: 2-3 hours to verify all features work
**Production Ready**: Yes, after testing
