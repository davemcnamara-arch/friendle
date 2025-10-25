# Rate Limiting Implementation

## Overview

Friendle implements client-side rate limiting to prevent abuse and protect against denial-of-service (DoS) attacks. The rate limiter uses a sliding window algorithm to track operations per user.

## Rate Limits

### File Uploads
- **Limit**: 3 uploads per minute per user
- **Protects**: Storage quota, bandwidth, upload abuse
- **User Experience**: Clear error message with wait time

### Message Sending
- **Limit**: 20 messages per minute per user
- **Protects**: Database writes, spam, notification flooding
- **User Experience**: "Slow down!" message

### Activity Preferences
- **Limit**: 10 saves per minute per user
- **Protects**: Database writes, match recalculation load
- **User Experience**: "Please wait" message

## Technical Implementation

### RateLimiter Class (index.html:2108-2170)

**Sliding Window Algorithm:**
```javascript
const RateLimiter = {
    limits: new Map(), // operation -> array of timestamps

    checkLimit(operation, maxRequests, windowMs) {
        const now = Date.now();
        const operationKey = `${operation}_${currentUser?.id || 'anonymous'}`;

        // Get existing timestamps
        const timestamps = this.limits.get(operationKey) || [];

        // Remove old timestamps outside window
        const validTimestamps = timestamps.filter(ts => now - ts < windowMs);

        // Check if under limit
        if (validTimestamps.length >= maxRequests) {
            return false; // Rate limited
        }

        // Add current timestamp
        validTimestamps.push(now);
        this.limits.set(operationKey, validTimestamps);
        return true; // Allowed
    }
}
```

### Integration Points

**1. File Upload (index.html:3402-3407)**
```javascript
if (!RateLimiter.checkLimit('file_upload', 3, 60000)) {
    const remaining = RateLimiter.getRemaining('file_upload', 3, 60000);
    const waitTime = remaining === 0 ? '1 minute' : `${60 - remaining * 20} seconds`;
    return showNotification(`Too many uploads. Please wait ${waitTime}...`, 'error');
}
```

**2. Message Sending (index.html:9021-9024)**
```javascript
if (!RateLimiter.checkLimit('send_message', 20, 60000)) {
    return showNotification('Slow down! You\'re sending messages too quickly.', 'error');
}
```

**3. Activity Preferences (index.html:5343-5346)**
```javascript
if (!RateLimiter.checkLimit('save_activities', 10, 60000)) {
    return showNotification('Please wait before saving again.', 'error');
}
```

## How It Works

### Sliding Window Algorithm

1. **Track Timestamps**: Each operation stores an array of timestamps when it was performed
2. **Remove Old Data**: Before checking, remove timestamps older than the time window
3. **Count Valid Requests**: Count remaining timestamps within the window
4. **Allow or Block**: If count < max, allow and add new timestamp; otherwise block
5. **Per-User Tracking**: Each user has separate limits (tracked by user ID)

**Example:**
```
Operation: file_upload
User: abc123
Max Requests: 3
Window: 60000ms (1 minute)

Time: 10:00:00 - Upload 1 ✅ [timestamps: [10:00:00]]
Time: 10:00:15 - Upload 2 ✅ [timestamps: [10:00:00, 10:00:15]]
Time: 10:00:30 - Upload 3 ✅ [timestamps: [10:00:00, 10:00:15, 10:00:30]]
Time: 10:00:45 - Upload 4 ❌ BLOCKED (3/3 used, wait 15s)
Time: 10:01:01 - Upload 5 ✅ [timestamps: [10:00:15, 10:00:30, 10:01:01]]
                                    ↑ 10:00:00 expired, removed
```

## Benefits

✅ **DoS Protection**: Prevents overwhelming the server with requests
✅ **Storage Protection**: Limits file upload abuse
✅ **Spam Prevention**: Stops message flooding
✅ **User Experience**: Clear feedback on why action was blocked
✅ **Fair Usage**: Ensures resources distributed fairly among users
✅ **Client-Side**: No server changes needed, works immediately

## Limitations

⚠️ **Client-Side Only**: Can be bypassed by malicious users modifying code
⚠️ **Per-Session**: Limits reset on page refresh (stored in memory)
⚠️ **No Cross-Tab**: Separate browser tabs have separate limits

## Future Enhancements

For production deployment, consider:

### 1. Server-Side Rate Limiting
```sql
-- Database table to track rate limits
CREATE TABLE rate_limits (
    user_id UUID NOT NULL,
    operation TEXT NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, operation, timestamp)
);

-- Index for efficient queries
CREATE INDEX idx_rate_limits_user_op
ON rate_limits(user_id, operation, timestamp DESC);

-- Cleanup old entries
DELETE FROM rate_limits
WHERE timestamp < NOW() - INTERVAL '5 minutes';
```

### 2. Edge Function Rate Limiting
Use Supabase Edge Functions with Deno's built-in rate limiting:
```typescript
import { rateLimit } from "https://deno.land/x/hono_rate_limiter/index.ts"

const limiter = rateLimit({
  windowMs: 60000, // 1 minute
  max: 20, // 20 requests per window
  message: "Too many requests"
});
```

### 3. Redis-Based Rate Limiting
For high-scale deployments:
```javascript
// Use Redis INCR and EXPIRE for distributed rate limiting
const key = `rate:${userId}:${operation}`;
const count = await redis.incr(key);
if (count === 1) await redis.expire(key, 60); // 1 minute TTL
if (count > maxRequests) throw new Error('Rate limited');
```

### 4. Progressive Penalties
```javascript
// Increase wait time for repeated violations
const violations = countViolations(userId, operation);
const waitTime = baseWaitTime * Math.pow(2, violations); // Exponential backoff
```

## Testing

### Manual Testing
1. **File Upload**: Try uploading 4 profile pictures quickly
   - First 3 should succeed
   - 4th should be blocked with error message
   - Wait 20 seconds between each upload
   - After 1 minute from first upload, all limits reset

2. **Message Sending**: Send 21 messages quickly
   - First 20 should succeed
   - 21st should show "Slow down!" error
   - Wait 3 seconds between messages to stay under limit

3. **Activity Preferences**: Click "Save Preferences" 11 times quickly
   - First 10 should succeed
   - 11th should show "Please wait" error

### Automated Testing
```javascript
// Test rate limiter
console.assert(RateLimiter.checkLimit('test', 3, 1000) === true);  // 1/3
console.assert(RateLimiter.checkLimit('test', 3, 1000) === true);  // 2/3
console.assert(RateLimiter.checkLimit('test', 3, 1000) === true);  // 3/3
console.assert(RateLimiter.checkLimit('test', 3, 1000) === false); // BLOCKED
setTimeout(() => {
    console.assert(RateLimiter.checkLimit('test', 3, 1000) === true); // OK after 1s
}, 1100);
```

## Monitoring

Track rate limit violations to identify abuse patterns:

```javascript
RateLimiter.checkLimit = function(operation, maxRequests, windowMs) {
    // ... existing code ...

    if (validTimestamps.length >= maxRequests) {
        // Log violation for monitoring
        console.warn('Rate limit violation:', {
            user: currentUser?.id,
            operation,
            limit: maxRequests,
            window: windowMs
        });

        // Optional: Send to analytics
        analytics.track('rate_limit_exceeded', {
            operation,
            userId: currentUser?.id
        });

        return false;
    }

    // ... rest of code ...
}
```

## Related Files

- `index.html:2108-2170` - RateLimiter class implementation
- `index.html:3402-3407` - File upload rate limiting
- `index.html:9021-9024` - Message sending rate limiting
- `index.html:5343-5346` - Activity preferences rate limiting
- `SECURITY_AUDIT_REPORT.md` - Original security recommendation
