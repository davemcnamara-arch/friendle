# localStorage Security Enhancement

## 🔒 Security Issue

**Current Problem:**
The app stores the entire user profile object in localStorage:
```javascript
localStorage.setItem('friendle_user', JSON.stringify(currentUser));
```

**What's Stored:**
- User ID
- Email
- Name
- Avatar URL
- OneSignal Player ID
- Notification preferences
- Timezone
- All other profile fields

**Risk:**
- localStorage persists forever (even after logout)
- Accessible to any JavaScript on the page
- If XSS occurs (despite our protections), attacker can steal all this data
- Data remains even after user closes browser

---

## ✅ Solution: Minimal Storage + sessionStorage

**Strategy:**
1. **localStorage**: Only store non-sensitive, essential data
   - User ID (needed to check if logged in on page load)
   - Last selected circle (UX convenience)

2. **sessionStorage**: Store session-specific data (clears on tab close)
   - User name, avatar (for UI display)
   - Preferences (cleared when tab closes)

3. **Memory only (currentUser variable)**: Everything else
   - Fetch from database on each page load
   - Never persist sensitive data

---

## 🔧 Implementation Plan

### Step 1: Create Safe Storage Helpers

```javascript
// SECURITY: Minimal localStorage storage
const SecureStorage = {
    // Only store user ID persistently
    setUserId(userId) {
        localStorage.setItem('friendle_user_id', userId);
    },

    getUserId() {
        return localStorage.getItem('friendle_user_id');
    },

    // Store UI data in session (clears on tab close)
    setSessionData(data) {
        sessionStorage.setItem('friendle_session', JSON.stringify({
            name: data.name,
            avatar: data.avatar
        }));
    },

    getSessionData() {
        const data = sessionStorage.getItem('friendle_session');
        return data ? JSON.parse(data) : null;
    },

    // Clear all on logout
    clearAll() {
        localStorage.removeItem('friendle_user_id');
        localStorage.removeItem('friendle_user'); // Legacy
        sessionStorage.clear();
    }
};
```

### Step 2: Update Login Flow

**Before:**
```javascript
currentUser = profileData;
localStorage.setItem('friendle_user', JSON.stringify(currentUser));
```

**After:**
```javascript
currentUser = profileData;
SecureStorage.setUserId(currentUser.id);
SecureStorage.setSessionData(currentUser);
```

### Step 3: Update App Initialization

**Before:**
```javascript
const storedUser = localStorage.getItem('friendle_user');
if (storedUser) {
    currentUser = JSON.parse(storedUser);
}
```

**After:**
```javascript
const userId = SecureStorage.getUserId();
if (userId) {
    // Fetch fresh profile from database
    const { data } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .single();
    currentUser = data;
    SecureStorage.setSessionData(data);
}
```

### Step 4: Update Logout

**Before:**
```javascript
localStorage.removeItem('friendle_user');
```

**After:**
```javascript
SecureStorage.clearAll();
```

---

## 📊 Security Improvement

| Data Type | Before | After | Benefit |
|-----------|--------|-------|---------|
| **User ID** | localStorage (forever) | localStorage | Needed for auto-login |
| **Email** | localStorage (forever) | Not stored | Protected if XSS |
| **Name** | localStorage (forever) | sessionStorage | Cleared on tab close |
| **Avatar** | localStorage (forever) | sessionStorage | Cleared on tab close |
| **Preferences** | localStorage (forever) | Not stored | Fetched fresh |
| **Player ID** | localStorage (forever) | Not stored | Not needed client-side |

**Impact:**
- ✅ XSS attacks steal less data (just user ID)
- ✅ Data cleared when user closes browser
- ✅ Fresh data fetched on each session
- ✅ Logout clears all stored data

---

## ⚠️ Trade-offs

**Pros:**
- Much better security
- Fresh data on each load
- sessionStorage cleared on tab close

**Cons:**
- One extra database query on app load (minimal impact)
- Profile updates require re-fetch (already happens)

---

## 🧪 Testing

After implementation:
1. Login → Check sessionStorage has minimal data
2. Refresh page → Should auto-login and fetch profile
3. Close tab and reopen → Session data should be gone, but auto-login still works
4. Logout → All storage should be cleared

---

## 📝 Implementation Status

- [ ] Create SecureStorage helper
- [ ] Update all login flows
- [ ] Update profile update flows
- [ ] Update logout flow
- [ ] Test on phone and desktop
- [ ] Verify data cleared after logout

---

**Ready to implement?** This will make the app much more resistant to data theft.
