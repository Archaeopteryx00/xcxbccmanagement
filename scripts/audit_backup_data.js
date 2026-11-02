// scripts/audit_backup_data.js
import fs from 'fs';

const data = JSON.parse(fs.readFileSync('backup/xcx_bbc_backup_2026-11-01T13-43-55-466Z.json', 'utf8'));

console.log('--- BACKUP DATA AUDIT ---');
console.log('Branches:', data.branches.length);
console.log('Accounts:', data.accounts.length);
console.log('Updates:', data.updates.length);
console.log('Claims:', data.claims.length);
console.log('Account Sources:', data.account_sources.length);
console.log('Account Topups:', data.account_topups.length);
console.log('VC Transactions:', data.vc_transactions.length);
console.log('Logs:', data.logs.length);

// Check claim statuses and rewards
let totalDmClaimed = 0;
let claimedCount = 0;
let pendingCount = 0;
for (const c of data.claims) {
    if (c.claim_status === 'Claimed') {
        claimedCount++;
        totalDmClaimed += Number(c.dm_claimed || 0);
    } else {
        pendingCount++;
    }
}
console.log('\nClaims analysis:');
console.log('- Claimed count:', claimedCount, 'Total DM from claims:', totalDmClaimed);
console.log('- Pending count:', pendingCount);

let totalSourcesReceived = data.account_sources.reduce((sum, s) => sum + Number(s.total_received || s.nominal || 0), 0);
let totalTopupsReceived = data.account_topups.reduce((sum, t) => sum + Number(t.total_received || t.nominal || 0), 0);

console.log('Sources DM total:', totalSourcesReceived);
console.log('Topups DM total:', totalTopupsReceived);
console.log('Total Actual DM (claims + sources + topups):', totalDmClaimed + totalSourcesReceived + totalTopupsReceived);

let vcEarned = data.vc_transactions.reduce((sum, v) => sum + Number(v.vc_earned || 0), 0);
let vcSpent = data.vc_transactions.reduce((sum, v) => sum + Number(v.vc_spent || 0), 0);
console.log('VC earned:', vcEarned, 'VC spent:', vcSpent, 'VC balance:', vcEarned - vcSpent);

console.log('\nUpdates detail:', JSON.stringify(data.updates, null, 2));
console.log('\nVC transactions detail:', JSON.stringify(data.vc_transactions, null, 2));
