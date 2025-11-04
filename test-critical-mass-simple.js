// SIMPLE TEST: Works with existing app permissions
// Just simulates the natural flow of users swiping right

console.log('🧪 Simple Critical Mass Test');
console.log('════════════════════════════════════════\n');

async function simpleTest() {
    try {
        // Step 1: Get current user's circles
        const { data: circles, error: circlesError } = await supabase
            .from('circle_members')
            .select('circles(id, name)')
            .eq('profile_id', currentUser.id)
            .limit(1)
            .single();

        if (circlesError || !circles) {
            console.log('❌ No circles found for your user');
            console.log('   Create a circle first or join one!\n');
            return;
        }

        const circle = circles.circles;
        console.log('✅ Using circle:', circle.name);
        console.log('   Circle ID:', circle.id, '\n');

        // Step 2: Get an activity
        const { data: activities, error: actError } = await supabase
            .from('activities')
            .select('id, name')
            .limit(5);

        if (actError || !activities || activities.length === 0) {
            console.log('❌ No activities found\n');
            return;
        }

        const activity = activities[0];
        console.log('✅ Using activity:', activity.name);
        console.log('   Activity ID:', activity.id, '\n');

        // Step 3: Check current interested count
        const { data: prefs, error: prefsError } = await supabase
            .from('preferences')
            .select('profile_id')
            .eq('circle_id', circle.id)
            .eq('activity_id', activity.id)
            .eq('selected', true);

        const currentCount = prefs?.length || 0;
        console.log('📊 Current interested users:', currentCount);

        // Step 4: Check match status
        const { data: match } = await supabase
            .from('matches')
            .select('id, notified_at_4, notified_at_8')
            .eq('circle_id', circle.id)
            .eq('activity_id', activity.id)
            .maybeSingle();

        if (match) {
            console.log('📋 Match exists:', match.id);
            console.log('   Notified at 4:', match.notified_at_4 || 'not yet');
            console.log('   Notified at 8:', match.notified_at_8 || 'not yet');
        } else {
            console.log('📋 No match exists yet (will be created on first interest)');
        }

        console.log('\n════════════════════════════════════════');
        console.log('📝 NEXT STEPS TO TEST:');
        console.log('════════════════════════════════════════\n');

        if (currentCount < 4) {
            console.log(`You need ${4 - currentCount} more user(s) to reach threshold 4`);
            console.log('\nOption 1: Manual test (RECOMMENDED)');
            console.log('─────────────────────────────────────');
            console.log('1. Get 3-4 friends to help');
            console.log('2. All join circle:', circle.name);
            console.log('3. Everyone swipes RIGHT on:', activity.name);
            console.log('4. When 4th person swipes → notification sent! 🔔\n');

            console.log('Option 2: SQL test (if you have admin access)');
            console.log('─────────────────────────────────────');
            console.log('Run this in Supabase SQL Editor:\n');
            console.log('-- Get 4 user IDs with push enabled');
            console.log(`SELECT id, name FROM profiles WHERE onesignal_player_id IS NOT NULL LIMIT 4;\n`);
            console.log('-- Then insert preferences for each user:');
            console.log(`INSERT INTO preferences (profile_id, circle_id, activity_id, selected)`);
            console.log(`VALUES ('USER_ID_HERE', '${circle.id}', '${activity.id}', true);\n`);
            console.log('-- Repeat for 4 different users');
            console.log('-- Then manually trigger:');
            console.log(`-- (Get match ID first)`);
            console.log(`SELECT id FROM matches WHERE circle_id = '${circle.id}' AND activity_id = '${activity.id}';\n`);
            console.log('-- Then in console:');
            console.log(`await supabase.functions.invoke('send-critical-mass-notification', {`);
            console.log(`  body: { matchId: 'MATCH_ID_FROM_ABOVE', threshold: 4 }`);
            console.log(`});\n`);

        } else if (currentCount >= 4 && !match?.notified_at_4) {
            console.log('🎯 You already have 4+ interested users!');
            console.log('Let\'s trigger the notification now!\n');

            if (match) {
                console.log('Triggering threshold 4 notification...');
                const { data, error } = await supabase.functions.invoke('send-critical-mass-notification', {
                    body: {
                        matchId: match.id,
                        threshold: 4
                    }
                });

                if (error) {
                    console.log('❌ Error:', error.message);
                } else {
                    console.log('✅ Success!', data);
                    console.log('\n🔔 Check your notifications!');
                }
            }

        } else if (match?.notified_at_4) {
            console.log('✅ Threshold 4 notification already sent!');
            console.log('   Sent at:', match.notified_at_4);

            if (currentCount >= 8 && !match.notified_at_8) {
                console.log('\n🎯 You have 8+ interested users!');
                console.log('Let\'s trigger threshold 8 notification!\n');

                const { data, error } = await supabase.functions.invoke('send-critical-mass-notification', {
                    body: {
                        matchId: match.id,
                        threshold: 8
                    }
                });

                if (error) {
                    console.log('❌ Error:', error.message);
                } else {
                    console.log('✅ Success!', data);
                    console.log('\n🔔 Check your notifications!');
                }
            } else if (match.notified_at_8) {
                console.log('\n✅ Threshold 8 notification also sent!');
                console.log('   Sent at:', match.notified_at_8);
                console.log('\n🎉 Both thresholds already triggered!');
            }
        }

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

simpleTest();
