// DEBUG: Why didn't anyone receive the notification?
// Run this to see who's eligible and why

console.log('🔍 Debugging Notification Eligibility\n');

async function debugEligibility() {
    const matchId = 'b218d192-6feb-4866-8c49-29786082e917';
    const circleId = '7da14b8e-0417-4dfc-8084-25f412a4873d';
    const activityId = '23dc4e03-2a5d-48b1-ae56-7f605a1af87f';

    try {
        console.log('Match ID:', matchId);
        console.log('Circle: Test');
        console.log('Activity: Coffee\n');

        // Get all interested users
        const { data: interested, error: intError } = await supabase
            .from('preferences')
            .select('profile_id, profiles(id, name, onesignal_player_id, notify_at_4, notify_at_8)')
            .eq('circle_id', circleId)
            .eq('activity_id', activityId)
            .eq('selected', true);

        if (intError) {
            console.error('Error fetching interested users:', intError);
            return;
        }

        console.log('═══════════════════════════════════════');
        console.log('👥 INTERESTED USERS (', interested.length, ')');
        console.log('═══════════════════════════════════════\n');

        // Get users who already joined the match
        const { data: participants, error: partError } = await supabase
            .from('match_participants')
            .select('profile_id, profiles(name)')
            .eq('match_id', matchId);

        const joinedIds = new Set(participants?.map(p => p.profile_id) || []);

        console.log('Already joined match:', participants?.length || 0, 'users');
        if (participants && participants.length > 0) {
            participants.forEach(p => {
                console.log('  - ' + p.profiles.name);
            });
        }
        console.log('');

        // Analyze each interested user
        interested.forEach((pref, index) => {
            const user = pref.profiles;
            console.log(`User ${index + 1}: ${user.name}`);
            console.log('─────────────────────────────────────');

            // Check 1: Already joined?
            const alreadyJoined = joinedIds.has(user.id);
            console.log('Already joined match:', alreadyJoined ? '❌ YES (won\'t notify)' : '✅ NO');

            // Check 2: Has OneSignal player ID?
            const hasPlayerId = !!user.onesignal_player_id;
            console.log('Has OneSignal player ID:', hasPlayerId ? '✅ YES' : '❌ NO (won\'t notify)');
            if (hasPlayerId) {
                console.log('  Player ID:', user.onesignal_player_id.substring(0, 20) + '...');
            }

            // Check 3: Has notify_at_4 enabled?
            const hasNotifyPref = user.notify_at_4 !== false;
            console.log('notify_at_4 enabled:', hasNotifyPref ? '✅ YES' : '❌ NO (won\'t notify)');
            console.log('  (actual value:', user.notify_at_4, ')');

            // Check 4: Eligible?
            const isEligible = !alreadyJoined && hasPlayerId && hasNotifyPref;
            console.log('\n🎯 ELIGIBLE FOR NOTIFICATION:', isEligible ? '✅ YES!' : '❌ NO');

            if (!isEligible) {
                console.log('❌ Blocked because:');
                if (alreadyJoined) console.log('   - Already joined the match');
                if (!hasPlayerId) console.log('   - No OneSignal player ID');
                if (!hasNotifyPref) console.log('   - Notifications disabled in settings');
            }

            console.log('');
        });

        // Summary
        const eligibleCount = interested.filter(pref => {
            const user = pref.profiles;
            return !joinedIds.has(user.id) &&
                   user.onesignal_player_id &&
                   user.notify_at_4 !== false;
        }).length;

        console.log('═══════════════════════════════════════');
        console.log('📊 SUMMARY');
        console.log('═══════════════════════════════════════');
        console.log('Total interested:', interested.length);
        console.log('Already joined:', participants?.length || 0);
        console.log('Eligible for notification:', eligibleCount);
        console.log('');

        if (eligibleCount === 0) {
            console.log('❌ NO ELIGIBLE USERS');
            console.log('\n💡 TO FIX:\n');

            const withoutPlayerIds = interested.filter(p => !p.profiles.onesignal_player_id && !joinedIds.has(p.profile_id));
            const withDisabledNotifs = interested.filter(p => p.profiles.notify_at_4 === false && !joinedIds.has(p.profile_id));
            const allJoined = interested.filter(p => joinedIds.has(p.profile_id));

            if (allJoined.length === interested.length) {
                console.log('All interested users have already joined the match.');
                console.log('→ This is expected! Users who join don\'t need notifications.');
                console.log('→ Test with users who are interested but haven\'t joined yet.');
            }

            if (withoutPlayerIds.length > 0) {
                console.log(`${withoutPlayerIds.length} user(s) don't have push notifications set up.`);
                console.log('→ Those users need to:');
                console.log('   1. Allow notifications when prompted');
                console.log('   2. Refresh the page');
                console.log('   3. Check Settings → ensure toggles are ON');
            }

            if (withDisabledNotifs.length > 0) {
                console.log(`${withDisabledNotifs.length} user(s) have disabled threshold notifications.`);
                console.log('→ Go to Settings → Notifications → Enable "Activity Momentum Alerts"');
            }

            console.log('\n🧪 TO TEST WITH CURRENT SETUP:');
            console.log('1. Make sure at least one interested user has NOT joined the match');
            console.log('2. That user must have push notifications enabled');
            console.log('3. That user must have "Notify at 4 interested" enabled in Settings');
        } else {
            console.log('✅ ELIGIBLE USERS FOUND!');
            console.log('\nThose users should have received notifications.');
            console.log('Check:');
            console.log('- Browser notifications (desktop)');
            console.log('- Mobile notifications');
            console.log('- Notification settings in browser/OS');
        }

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

debugEligibility();
