# Profile Picture Upload Feature

## Overview
Added a comprehensive profile picture upload feature that allows users to upload, change, and remove their profile pictures. Images are stored in Supabase Storage and displayed throughout the app.

## Changes Made

### 1. Database & Storage (`MIGRATION_add_profile_pictures.sql`)
- Created `avatars` bucket in Supabase Storage (public)
- Implemented Row Level Security (RLS) policies:
  - Users can upload/update/delete their own avatars
  - Everyone can view all avatars (public bucket)
- Avatar files stored as: `{user_id}/avatar.{extension}`

### 2. User Interface (Settings Page)
- **Profile Picture Display:**
  - Large circular avatar (120x120px) at top of Settings page
  - Supports both image URLs and emoji avatars
  - Hover effect for better UX

- **Upload UI:**
  - Camera icon overlay on profile picture
  - Click to select new image
  - Hidden file input with `accept="image/*"`

- **Remove Picture Button:**
  - Only shows when user has uploaded a picture
  - Confirms before removing
  - Reverts to default emoji avatar (😊)

### 3. CSS Styling
Added new CSS classes:
- `.profile-picture-container` - Container with camera overlay
- `.profile-picture` - Main avatar display area
- `.profile-picture-overlay` - Camera icon button
- `.avatar-display` - Handles both image and emoji display
- `.avatar-display.emoji` - Emoji-specific styling

### 4. JavaScript Functions

#### `uploadProfilePicture(event)`
- Validates file type (images only) and size (max 5MB)
- Deletes old avatar from storage before uploading new one
- Uploads to Supabase Storage: `avatars/{user_id}/avatar.{ext}`
- Updates profile record with public URL
- Updates UI and local storage

#### `removeProfilePicture()`
- Confirms deletion with user
- Removes file from Supabase Storage
- Resets avatar to default emoji (😊)
- Updates profile record and UI

#### `updateProfile()`
- Enhanced to handle both image URLs and emojis
- Shows/hides "Remove Picture" button appropriately
- Renders correct avatar format in Settings page

#### `renderAvatar(avatar, size)`
- Helper function for consistent avatar rendering
- Detects if avatar is URL (starts with 'http') or emoji
- Returns appropriate HTML for images or emoji display
- Used throughout the app for consistent avatar rendering

### 5. Avatar Display Updates
Updated chat message rendering:
- `appendMessage()` - Main chat messages
- `appendMessageToContainer()` - Archived messages
- Both now use `renderAvatar()` helper for consistent display

## Avatar Data Structure

The `profiles.avatar` field now supports two formats:

1. **Emoji (backward compatible):**
   ```
   avatar: "😊"
   ```

2. **Image URL:**
   ```
   avatar: "https://kxsewkjbhxtfqbytftbu.supabase.co/storage/v1/object/public/avatars/{user_id}/avatar.jpg"
   ```

## Features

✅ Upload profile pictures from Settings page
✅ Store images in Supabase Storage
✅ Display profile pictures in all chats (event, match, circle)
✅ Default emoji avatar if no picture uploaded
✅ Update profiles table with image URL
✅ Remove profile picture option
✅ Image validation (type and size)
✅ Backward compatible with emoji avatars
✅ Responsive and mobile-friendly UI

## Usage Instructions

### For Users:
1. Go to Settings page
2. Click on your profile picture or the camera icon
3. Select an image (max 5MB)
4. Image uploads and displays immediately
5. To remove: click "Remove Picture" button

### For Developers:
1. Run the SQL migration to create the storage bucket:
   ```sql
   -- Execute MIGRATION_add_profile_pictures.sql in Supabase SQL editor
   ```

2. Ensure Supabase Storage is enabled in your project

3. The feature is now ready to use!

## Technical Notes

- **File Storage Pattern:** `{user_id}/avatar.{extension}`
- **Max File Size:** 5MB
- **Supported Formats:** All image types (jpg, png, gif, webp, etc.)
- **Cache Control:** 1 hour (3600 seconds)
- **Backward Compatibility:** Existing emoji avatars continue to work
- **Default Avatar:** 👤 emoji when no avatar set

## Testing Checklist

- [ ] Upload profile picture from Settings
- [ ] Verify image displays in Settings page
- [ ] Check avatar appears in event chat messages
- [ ] Check avatar appears in match chat messages
- [ ] Check avatar appears in circle chat messages
- [ ] Remove profile picture and verify emoji fallback
- [ ] Test with different image formats (jpg, png, gif)
- [ ] Test file size validation (try uploading >5MB)
- [ ] Test with different users to ensure RLS policies work
- [ ] Verify old avatars are deleted when uploading new ones

## Security

- Row Level Security (RLS) enforced on storage.objects
- Users can only modify their own avatar files
- Public read access for all avatars (public bucket design)
- File paths scoped to user ID
- Server-side validation via RLS policies
