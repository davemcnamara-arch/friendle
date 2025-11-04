// BROWSER CONSOLE TEST SCRIPT: Critical Mass Notifications
// Copy and paste this into your browser console when logged into Friendle

// =============================================================================
// STEP 1: Setup - Get test data IDs
// =============================================================================

async function getTestData() {
    console.log('🔍 Finding test data...\n');

    // Get first circle
    const { data: circles } = await supabase
        .from('circles')
        .select('id, name')
        .limit(1)
        .single();

    console.log('Circle:', circles.name, '(' + circles.id + ')');

    // Get first activity
    const { data: activity } = await supabase
        .from('activities')
        .select('id, name')
        .limit(1)
        .single();

    console.log('Activity:', activity.name, '(' + activity.id + ')');

    // Get users with OneSignal player IDs
    const { data: users } = await supabase
        .from('profiles')
        .select('id, name, onesignal_player_id')
        .not('onesignal_player_id', 'is', null)
        .limit(8);

    console.log('Found', users.length, 'users with push notifications enabled\n');

    return { circles, activity, users };
}

// =============================================================================
// STEP 2: Simulate users swiping right to reach threshold
// =============================================================================

async function simulateSwipesToThreshold(circleId, activityId, users, targetThreshold = 4) {
    console.log(`\n🎯 Simulating swipes to reach threshold ${targetThreshold}...\n`);

    // Clean up existing preferences first
    console.log('Cleaning up existing preferences...');
    await supabase
        .from('preferences')
        .delete()
        .eq('circle_id', circleId)
        .eq('activity_id', activityId);

    // Reset match notification flags
    await supabase
        .from('matches')
        .update({
            notified_at_4: null,
            notified_at_8: null
        })
        .eq('circle_id', circleId)
        .eq('activity_id', activityId);

    // Get or create match
    let { data: match } = await supabase
        .from('matches')
        .select('id')
        .eq('circle_id', circleId)
        .eq('activity_id', activityId)
        .single();

    if (!match) {
        const { data: newMatch } = await supabase
            .from('matches')
            .insert({
                circle_id: circleId,
                activity_id: activityId,
                created_at: new Date().toISOString()
            })
            .select('id')
            .single();
        match = newMatch;
        console.log('✅ Created new match:', match.id);
    } else {
        console.log('✅ Using existing match:', match.id);
    }

    // Add users one by one
    for (let i = 0; i < Math.min(targetThreshold, users.length); i++) {
        const user = users[i];

        await supabase
            .from('preferences')
            .insert({
                profile_id: user.id,
                circle_id: circleId,
                activity_id: activityId,
                selected: true
            });

        console.log(`✅ User ${i + 1}/${targetThreshold} (${user.name}) swiped right`);

        // Count interested users
        const { data: prefs } = await supabase
            .from('preferences')
            .select('profile_id')
            .eq('circle_id', circleId)
            .eq('activity_id', activityId)
            .eq('selected', true);

        const count = prefs.length;

        if (count === 4) {
            console.log('\n🎯 THRESHOLD 4 REACHED!\n');
        }
        if (count === 8) {
            console.log('\n🎯🎯 THRESHOLD 8 REACHED!\n');
        }
    }

    return match.id;
}

// =============================================================================
// STEP 3: Trigger the Edge Function
// =============================================================================

async function triggerNotification(matchId, threshold) {
    console.log(`\n📤 Invoking Edge Function for threshold ${threshold}...\n`);

    const { data, error } = await supabase.functions.invoke('send-critical-mass-notification', {
        body: {
            matchId: matchId,
            threshold: threshold
        }
    });

    if (error) {
        console.error('❌ Error invoking Edge Function:', error);
        return null;
    }

    console.log('✅ Edge Function response:', data);
    return data;
}

// =============================================================================
// STEP 4: Verify notification was sent
// =============================================================================

async function verifyNotificationSent(matchId, threshold) {
    console.log('\n🔍 Verifying notification was sent...\n');

    const { data: match } = await supabase
        .from('matches')
        .select(`
            id,
            notified_at_4,
            notified_at_8,
            activities (name),
            circles (name)
        `)
        .eq('id', matchId)
        .single();

    console.log('Match:', match.activities.name, 'in', match.circles.name);
    console.log('Notified at 4:', match.notified_at_4 || 'NOT SENT');
    console.log('Notified at 8:', match.notified_at_8 || 'NOT SENT');

    const field = threshold === 4 ? 'notified_at_4' : 'notified_at_8';
    if (match[field]) {
        console.log(`\n✅ SUCCESS! Threshold ${threshold} notification was sent at ${match[field]}`);
        return true;
    } else {
        console.log(`\n❌ FAILED! Threshold ${threshold} notification was NOT sent`);
        return false;
    }
}

// =============================================================================
// COMPLETE TEST FLOW
// =============================================================================

async function testThreshold4() {
    console.log('🧪 ========================================');
    console.log('🧪 TEST: Critical Mass Notification (Threshold 4)');
    console.log('🧪 ========================================\n');

    try {
        // Step 1: Get test data
        const { circles, activity, users } = await getTestData();

        // Step 2: Simulate swipes to reach threshold 4
        const matchId = await simulateSwipesToThreshold(circles.id, activity.id, users, 4);

        // Step 3: Trigger the notification
        await triggerNotification(matchId, 4);

        // Step 4: Verify
        await verifyNotificationSent(matchId, 4);

        console.log('\n✅ Test complete! Check your notifications.');

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

async function testThreshold8() {
    console.log('🧪 ========================================');
    console.log('🧪 TEST: Critical Mass Notification (Threshold 8)');
    console.log('🧪 ========================================\n');

    try {
        // Step 1: Get test data
        const { circles, activity, users } = await getTestData();

        // Step 2: Simulate swipes to reach threshold 8
        const matchId = await simulateSwipesToThreshold(circles.id, activity.id, users, 8);

        // Step 3: Trigger the notification
        await triggerNotification(matchId, 8);

        // Step 4: Verify
        await verifyNotificationSent(matchId, 8);

        console.log('\n✅ Test complete! Check your notifications.');

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

async function testBothThresholds() {
    console.log('🧪 ========================================');
    console.log('🧪 TEST: Both Thresholds (4 and 8)');
    console.log('🧪 ========================================\n');

    try {
        // Step 1: Get test data
        const { circles, activity, users } = await getTestData();

        // Step 2: Simulate swipes to reach threshold 4
        const matchId = await simulateSwipesToThreshold(circles.id, activity.id, users, 4);

        // Step 3: Trigger threshold 4 notification
        console.log('\n--- Testing Threshold 4 ---');
        await triggerNotification(matchId, 4);
        await verifyNotificationSent(matchId, 4);

        // Step 4: Add 4 more users to reach threshold 8
        console.log('\n--- Adding more users for Threshold 8 ---');
        for (let i = 4; i < Math.min(8, users.length); i++) {
            const user = users[i];
            await supabase
                .from('preferences')
                .insert({
                    profile_id: user.id,
                    circle_id: circles.id,
                    activity_id: activity.id,
                    selected: true
                });
            console.log(`✅ User ${i + 1}/8 (${user.name}) swiped right`);
        }

        console.log('\n🎯🎯 THRESHOLD 8 REACHED!\n');

        // Step 5: Trigger threshold 8 notification
        console.log('\n--- Testing Threshold 8 ---');
        await triggerNotification(matchId, 8);
        await verifyNotificationSent(matchId, 8);

        console.log('\n✅ Both threshold tests complete! Check your notifications.');

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

// =============================================================================
// INSTRUCTIONS
// =============================================================================

console.log(`
🧪 Critical Mass Notification Test Suite
=========================================

Available test functions:

1. testThreshold4()
   - Simulates 4 users swiping right
   - Triggers threshold 4 notification
   - Verifies notification was sent

2. testThreshold8()
   - Simulates 8 users swiping right
   - Triggers threshold 8 notification
   - Verifies notification was sent

3. testBothThresholds()
   - Tests both thresholds in sequence
   - Simulates realistic scenario

USAGE:
------
Just run one of the functions in the console:

  await testThreshold4()

  OR

  await testThreshold8()

  OR

  await testBothThresholds()

REQUIREMENTS:
-------------
- You must be logged into Friendle
- You need at least 4-8 users with OneSignal player IDs
- Edge Function must be deployed

NOTE: You should receive actual push notifications if:
- Your user is in the interested list
- You have notifications enabled in settings
- You're not in quiet hours (midnight-7am)
`);
