// SETUP: Create proper test scenario
// This will reset the match so you can test notifications properly

console.log('🔧 Setting up proper test scenario\n');

async function setupTest() {
    const matchId = 'b218d192-6feb-4866-8c49-29786082e917';

    try {
        console.log('This will:');
        console.log('1. Remove all users from the match (but keep them interested)');
        console.log('2. Reset notification flags');
        console.log('3. Then you can trigger the notification\n');

        const confirm = prompt('Type YES to continue (this will remove everyone from the match):');

        if (confirm !== 'YES') {
            console.log('❌ Cancelled');
            return;
        }

        // Step 1: Remove all participants from match
        console.log('Removing participants from match...');
        const { error: removeError } = await supabase
            .from('match_participants')
            .delete()
            .eq('match_id', matchId);

        if (removeError) {
            console.error('❌ Error removing participants:', removeError);
            return;
        }

        console.log('✅ Removed all participants from match\n');

        // Step 2: Reset notification flags
        console.log('Resetting notification flags...');
        const { error: resetError } = await supabase
            .from('matches')
            .update({
                notified_at_4: null,
                notified_at_8: null
            })
            .eq('id', matchId);

        if (resetError) {
            console.error('❌ Error resetting flags:', resetError);
            return;
        }

        console.log('✅ Reset notification flags\n');

        // Step 3: Verify setup
        const { data: match } = await supabase
            .from('matches')
            .select('id, notified_at_4, notified_at_8')
            .eq('id', matchId)
            .single();

        const { data: participants } = await supabase
            .from('match_participants')
            .select('profile_id')
            .eq('match_id', matchId);

        const { data: interested } = await supabase
            .from('preferences')
            .select('profile_id, profiles(name, onesignal_player_id)')
            .eq('circle_id', '7da14b8e-0417-4dfc-8084-25f412a4873d')
            .eq('activity_id', '23dc4e03-2a5d-48b1-ae56-7f605a1af87f')
            .eq('selected', true);

        console.log('═══════════════════════════════════════');
        console.log('✅ SETUP COMPLETE!');
        console.log('═══════════════════════════════════════');
        console.log('Match ID:', match.id);
        console.log('Interested users:', interested.length);
        console.log('Users in match:', participants?.length || 0);
        console.log('Notified at 4:', match.notified_at_4 || 'not yet');
        console.log('Notified at 8:', match.notified_at_8 || 'not yet');
        console.log('');

        // Count eligible users
        const eligible = interested.filter(i => i.profiles.onesignal_player_id);
        console.log('Eligible for notifications:', eligible.length);
        eligible.forEach(user => {
            console.log('  ✅', user.profiles.name);
        });
        console.log('');

        console.log('═══════════════════════════════════════');
        console.log('🧪 NOW TEST:');
        console.log('═══════════════════════════════════════');
        console.log('Run this command to trigger the notification:\n');
        console.log('await supabase.functions.invoke(\'send-critical-mass-notification\', {');
        console.log('  body: { matchId: \'' + matchId + '\', threshold: 4 }');
        console.log('});\n');
        console.log('Expected result:');
        console.log('- ' + eligible.length + ' user(s) should receive push notifications');
        console.log('- Check browser notifications (🔔)');
        console.log('- Click notification → should open match chat\n');

    } catch (error) {
        console.error('❌ Error:', error);
    }
}

setupTest();
