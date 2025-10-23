# Setting Up Profile Picture Storage (Dashboard Method)

If you get a permissions error running the SQL migration, follow these steps to set up the storage bucket through the Supabase Dashboard instead.

## Step 1: Create the Storage Bucket

1. Go to your Supabase Dashboard: https://app.supabase.com
2. Select your project: **friendle_dev** (kxsewkjbhxtfqbytftbu)
3. Navigate to **Storage** in the left sidebar
4. Click **"New bucket"**
5. Configure the bucket:
   - **Name:** `avatars`
   - **Public bucket:** ✅ **Checked** (IMPORTANT!)
   - **File size limit:** 5MB (optional)
   - **Allowed MIME types:** image/* (optional)
6. Click **"Create bucket"**

## Step 2: Set Up Storage Policies

After creating the bucket, you need to add security policies:

1. Click on the **avatars** bucket you just created
2. Click on the **"Policies"** tab at the top
3. Click **"New Policy"**

### Policy 1: Allow Users to Upload Their Own Avatar

- **Policy name:** `Users can upload their own avatar`
- **Operation:** `INSERT`
- **Target roles:** `authenticated`
- **USING expression:** (leave empty for INSERT)
- **WITH CHECK expression:**
  ```sql
  (bucket_id = 'avatars') AND ((storage.foldername(name))[1] = (auth.uid())::text)
  ```
- Click **"Review"** then **"Save policy"**

### Policy 2: Allow Users to Update Their Own Avatar

- **Policy name:** `Users can update their own avatar`
- **Operation:** `UPDATE`
- **Target roles:** `authenticated`
- **USING expression:**
  ```sql
  (bucket_id = 'avatars') AND ((storage.foldername(name))[1] = (auth.uid())::text)
  ```
- **WITH CHECK expression:**
  ```sql
  (bucket_id = 'avatars') AND ((storage.foldername(name))[1] = (auth.uid())::text)
  ```
- Click **"Review"** then **"Save policy"**

### Policy 3: Allow Users to Delete Their Own Avatar

- **Policy name:** `Users can delete their own avatar`
- **Operation:** `DELETE`
- **Target roles:** `authenticated`
- **USING expression:**
  ```sql
  (bucket_id = 'avatars') AND ((storage.foldername(name))[1] = (auth.uid())::text)
  ```
- Click **"Review"** then **"Save policy"**

### Policy 4: Allow Everyone to View Avatars

- **Policy name:** `Anyone can view avatars`
- **Operation:** `SELECT`
- **Target roles:** `public`
- **USING expression:**
  ```sql
  bucket_id = 'avatars'
  ```
- Click **"Review"** then **"Save policy"**

## Step 3: Verify Setup

1. Go back to the **Storage** page
2. You should see the **avatars** bucket listed
3. Click on it and verify you see all 4 policies under the "Policies" tab

## You're Done! 🎉

The profile picture upload feature is now fully configured and ready to use. Users can:
- Upload profile pictures from the Settings page
- Pictures are stored in the `avatars` bucket
- Each user can only access their own pictures
- Everyone can view all profile pictures (public)

## Testing

1. Log into your app
2. Go to Settings
3. Click on your profile picture
4. Upload an image
5. Verify it displays correctly

If you see any errors in the browser console, check that:
- The bucket is marked as **Public**
- All 4 policies are created correctly
- The policy expressions match exactly as shown above

---

## Alternative: SQL Editor Method (Advanced)

If you have admin access, you can try running this simpler SQL in the SQL Editor:

```sql
-- Just create the bucket (policies can be added via Dashboard)
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;
```

Then follow Steps 2-3 above to add policies through the Dashboard.
