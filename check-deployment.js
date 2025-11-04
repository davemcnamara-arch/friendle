// QUICK DEPLOYMENT CHECK
// Run this in your browser console on Friendle to verify everything is deployed

console.log('🔍 Checking Critical Mass Notification deployment...\n');

async function checkDeployment() {
    try {
        // CHECK 1: Database columns exist?
        console.log('1️⃣ Checking database columns...');

        const { data: testMatch, error: matchError } = await supabase
            .from('matches')
            .select('id, notified_at_4, notified_at_8')
            .limit(1)
            .single();

        if (matchError && matchError.code !== 'PGRST116') {
            if (matchError.message.includes('notified_at_4') || matchError.message.includes('notified_at_8')) {
                console.log('❌ Database migration NOT run - columns missing');
                console.log('   → Run: supabase/migrations/20251104_critical_mass_notifications.sql\n');
            } else {
                console.log('⚠️  No matches exist yet (this is ok)\n');
            }
        } else {
            console.log('✅ Database columns exist on matches table\n');
        }

        const { data: testProfile, error: profileError } = await supabase
            .from('profiles')
            .select('id, notify_at_4, notify_at_8')
            .limit(1)
            .single();

        if (profileError) {
            if (profileError.message.includes('notify_at_4') || profileError.message.includes('notify_at_8')) {
                console.log('❌ Database migration NOT run - profile columns missing');
                console.log('   → Run: supabase/migrations/20251104_critical_mass_notifications.sql\n');
                return;
            }
        } else {
            console.log('✅ Database columns exist on profiles table');
            console.log('   notify_at_4:', testProfile.notify_at_4);
            console.log('   notify_at_8:', testProfile.notify_at_8);
            console.log('');
        }

        // CHECK 2: Edge Function exists and is callable?
        console.log('2️⃣ Checking Edge Function...');

        const { data, error } = await supabase.functions.invoke('send-critical-mass-notification', {
            body: {
                matchId: 'test-check-only',
                threshold: 4
            }
        });

        if (error) {
            if (error.message.includes('not found') || error.message.includes('404')) {
                console.log('❌ Edge Function NOT deployed');
                console.log('   → Deploy: npx supabase functions deploy send-critical-mass-notification\n');
            } else if (error.message.includes('Match not found')) {
                console.log('✅ Edge Function is deployed and callable');
                console.log('   (Got expected "Match not found" error for test ID)\n');
            } else {
                console.log('⚠️  Edge Function exists but returned error:', error.message);
                console.log('   (This might be ok - it means the function is deployed)\n');
            }
        } else {
            console.log('✅ Edge Function is deployed and responding\n');
        }

        // CHECK 3: Frontend code updated?
        console.log('3️⃣ Checking frontend code...');

        if (typeof checkCriticalMassThresholds === 'function') {
            console.log('✅ Frontend function checkCriticalMassThresholds() exists\n');
        } else {
            console.log('❌ Frontend code NOT updated');
            console.log('   → Function checkCriticalMassThresholds() not found');
            console.log('   → Deploy latest index.html\n');
        }

        // CHECK 4: Settings UI exists?
        console.log('4️⃣ Checking Settings UI...');

        const toggle4 = document.getElementById('notify-at-4-toggle');
        const toggle8 = document.getElementById('notify-at-8-toggle');

        if (toggle4 && toggle8) {
            console.log('✅ Settings toggles exist in UI');
            console.log('   notify_at_4 toggle:', toggle4.checked);
            console.log('   notify_at_8 toggle:', toggle8.checked);
            console.log('');
        } else {
            console.log('❌ Settings UI NOT updated');
            console.log('   → Toggles not found in Settings page');
            console.log('   → Deploy latest index.html\n');
        }

        // SUMMARY
        console.log('═══════════════════════════════════════');
        console.log('📊 DEPLOYMENT STATUS SUMMARY');
        console.log('═══════════════════════════════════════');
        console.log('Database Migration:', matchError && matchError.message.includes('notified') ? '❌ NOT RUN' : '✅ COMPLETE');
        console.log('Edge Function:', error && error.message.includes('not found') ? '❌ NOT DEPLOYED' : '✅ DEPLOYED');
        console.log('Frontend Code:', typeof checkCriticalMassThresholds === 'function' ? '✅ DEPLOYED' : '❌ NOT DEPLOYED');
        console.log('Settings UI:', (toggle4 && toggle8) ? '✅ DEPLOYED' : '❌ NOT DEPLOYED');
        console.log('═══════════════════════════════════════\n');

        // NEXT STEPS
        const needsDeployment =
            (matchError && matchError.message.includes('notified')) ||
            (error && error.message.includes('not found')) ||
            (typeof checkCriticalMassThresholds !== 'function') ||
            (!toggle4 || !toggle8);

        if (needsDeployment) {
            console.log('📝 NEXT STEPS:');
            console.log('1. Run database migration (if needed)');
            console.log('2. Deploy Edge Function (if needed)');
            console.log('3. Deploy frontend (if needed)');
            console.log('4. Then run test: await testThreshold4()\n');
        } else {
            console.log('🎉 EVERYTHING IS DEPLOYED!');
            console.log('Ready to test! Run: await testThreshold4()\n');
        }

    } catch (err) {
        console.error('❌ Error checking deployment:', err);
    }
}

checkDeployment();
