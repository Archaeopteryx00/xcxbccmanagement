// services/supabaseManager.js
// Supabase Cloud Integration & Real-time Multi-Device Sync for XCX BBC Management

(function () {
    const SUPABASE_CONFIG = {
        url: 'https://iwwebxwbsbplvzkfwjbc.supabase.co',
        anonKey: 'sb_publishable_-40mHHycTwpLPQOA2eOSrQ_UqCJsw6P'
    };

    let sbClient = null;
    let currentUser = null;
    let isSyncing = false;
    let activeAuthTab = 'login';
    let sdkLoadingPromise = null;

    // -------------------------------------------------------------------------
    // 1. Dynamic SDK Loader & Lazy Client Factory
    // -------------------------------------------------------------------------

function ensureSdkLoaded() {
        if (window.supabase && typeof window.supabase.createClient === 'function') {
            return Promise.resolve(true);
        }
        if (sdkLoadingPromise) return sdkLoadingPromise;

        sdkLoadingPromise = new Promise((resolve) => {
            console.log('[SupabaseManager] Loading Supabase SDK dynamically...');

            // Step 1: Try local bundle first (zero internet/ISP blocking dependency)
            const scriptLocal = document.createElement('script');
            scriptLocal.src = 'services/supabase.js';

            scriptLocal.onload = () => {
                if (window.supabase && typeof window.supabase.createClient === 'function') {
                    console.log('[SupabaseManager] SDK loaded from local bundle (services/supabase.js)');
                    resolve(true);
                } else {
                    tryUnpkg(resolve);
                }
            };

            scriptLocal.onerror = () => {
                console.warn('[SupabaseManager] Local bundle not found, falling back to unpkg CDN...');
                tryUnpkg(resolve);
            };

            document.head.appendChild(scriptLocal);
        });

        return sdkLoadingPromise;
    }

    function tryUnpkg(resolve) {
        const scriptCdn = document.createElement('script');
        scriptCdn.src = 'https://unpkg.com/@supabase/supabase-js@2';
        scriptCdn.onload = () => {
            if (window.supabase && typeof window.supabase.createClient === 'function') {
                console.log('[SupabaseManager] SDK loaded from unpkg CDN');
                resolve(true);
            } else {
                console.error('[SupabaseManager] Failed to export window.supabase from unpkg');
                resolve(false);
            }
        };
        scriptCdn.onerror = (err) => {
            console.error('[SupabaseManager] CDN load failed:', err);
            resolve(false);
        };
        document.head.appendChild(scriptCdn);
    }

    function getClient() {
        if (sbClient) return sbClient;
        if (window.supabase && typeof window.supabase.createClient === 'function') {
            try {
                sbClient = window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey, {
                    auth: {
                        persistSession: true,
                        autoRefreshToken: true,
                        detectSessionInUrl: true
                    }
                });

                sbClient.auth.onAuthStateChange(async (event, session) => {
                    console.log(`[SupabaseManager] Auth event: ${event}`);
                    currentUser = session?.user || null;
                    updateCloudUI();

                    if (event === 'SIGNED_IN' && session) {
                        await syncFromCloud(false);
                    } else if (event === 'SIGNED_OUT') {
                        currentUser = null;
                        updateCloudUI();
                        if (typeof window.toast === 'function') window.toast('Sesi berakhir. Kembali ke mode LocalStorage.', 'info');
                    }
                });

                return sbClient;
            } catch (err) {
                console.error('[SupabaseManager] createClient error:', err);
            }
        }
        return null;
    }

    // -------------------------------------------------------------------------
    // 2. Initialization & Session Restoration
    // -------------------------------------------------------------------------
    async function init() {
        console.log('[SupabaseManager] Initializing client...');
        let client = getClient();

        if (!client) {
            console.log('[SupabaseManager] SDK not detected yet, loading dynamically...');
            const loaded = await ensureSdkLoaded();
            if (loaded) {
                client = getClient();
            }
        }

        if (client) {
            try {
                const { data: { session }, error } = await client.auth.getSession();
                if (error) console.warn('[SupabaseManager] getSession error:', error);
                currentUser = session?.user || null;
                updateCloudUI();

                if (currentUser) {
                    console.log(`[SupabaseManager] Restored active session for: ${currentUser.email}`);
                    await syncFromCloud(false);
                }
            } catch (err) {
                console.error('[SupabaseManager] Session restore error:', err);
                updateCloudUI();
            }
        } else {
            console.warn('[SupabaseManager] Running in offline LocalStorage mode.');
            updateCloudUI();
        }
    }

    // -------------------------------------------------------------------------
    // 3. UI Status & Modals
    // -------------------------------------------------------------------------
    function updateCloudUI() {
        const badge = document.getElementById('cloud-status-badge');
        const dot = document.getElementById('cloud-status-dot');
        const text = document.getElementById('cloud-status-text');
        const syncBtn = document.getElementById('cloud-sync-btn');
        const authBtn = document.getElementById('cloud-auth-btn');

        if (!badge || !dot || !text) return;

        if (currentUser) {
            badge.className = 'inline-flex items-center px-2 py-1 rounded-md text-[10px] font-medium bg-emerald-50 text-emerald-800 border border-emerald-200';
            dot.className = 'w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse';
            const emailPrefix = currentUser.email ? currentUser.email.split('@')[0] : 'Operator';
            text.textContent = `Cloud (${emailPrefix})`;
            badge.title = `Terkoneksi ke Supabase Cloud (${currentUser.email})`;

            if (syncBtn) syncBtn.classList.remove('hidden');
            if (authBtn) {
                authBtn.textContent = 'Logout';
                authBtn.title = `Logout dari ${currentUser.email}`;
                authBtn.onclick = handleLogout;
            }
        } else {
            badge.className = 'inline-flex items-center px-2 py-1 rounded-md text-[10px] font-medium bg-neutral-100 text-neutral-600 border border-neutral-200';
            dot.className = 'w-1.5 h-1.5 rounded-full bg-amber-500 mr-1.5';
            text.textContent = 'LocalStorage Mode';
            badge.title = 'Data saat ini hanya tersimpan di browser perangkat ini';

            if (syncBtn) syncBtn.classList.add('hidden');
            if (authBtn) {
                authBtn.textContent = 'Login Cloud';
                authBtn.title = 'Masuk untuk sinkronisasi multi-perangkat';
                authBtn.onclick = openAuthModal;
            }
        }

        if (window.lucide && typeof lucide.createIcons === 'function') {
            lucide.createIcons();
        }
    }

    function openAuthModal() {
        setAuthTab('login');
        const errDiv = document.getElementById('auth-error-msg');
        if (errDiv) errDiv.classList.add('hidden');
        const modal = document.getElementById('modal-auth');
        if (modal) modal.classList.remove('hidden');

        // Ensure SDK is ready in background
        if (!getClient()) {
            ensureSdkLoaded().then(() => getClient());
        }
    }

    function closeAuthModal() {
        const modal = document.getElementById('modal-auth');
        if (modal) modal.classList.add('hidden');
    }

    function setAuthTab(tab) {
        activeAuthTab = tab;
        const tabLogin = document.getElementById('auth-tab-login');
        const tabReg = document.getElementById('auth-tab-register');
        const submitBtn = document.getElementById('auth-submit-btn');
        const infoMsg = document.getElementById('auth-info-msg');
        const errDiv = document.getElementById('auth-error-msg');
        if (errDiv) errDiv.classList.add('hidden');

        if (tab === 'login') {
            if (tabLogin) tabLogin.className = 'flex-1 py-2.5 text-center text-neutral-900 border-b-2 border-neutral-900 transition-all font-semibold';
            if (tabReg) tabReg.className = 'flex-1 py-2.5 text-center text-neutral-500 hover:text-neutral-900 border-b-2 border-transparent transition-all font-medium';
            if (submitBtn) submitBtn.textContent = 'Masuk ke Cloud';
            if (infoMsg) infoMsg.textContent = 'Masuk dengan akun yang sama di perangkat mana pun agar data selalu tersinkronisasi.';
        } else {
            if (tabLogin) tabLogin.className = 'flex-1 py-2.5 text-center text-neutral-500 hover:text-neutral-900 border-b-2 border-transparent transition-all font-medium';
            if (tabReg) tabReg.className = 'flex-1 py-2.5 text-center text-neutral-900 border-b-2 border-neutral-900 transition-all font-semibold';
            if (submitBtn) submitBtn.textContent = 'Daftar Akun Operator';
            if (infoMsg) infoMsg.textContent = 'Pendaftaran akun operator baru untuk akses database cloud Supabase.';
        }
    }

    async function handleAuthSubmit(e) {
        e.preventDefault();
        const errDiv = document.getElementById('auth-error-msg');
        const submitBtn = document.getElementById('auth-submit-btn');

        if (errDiv) errDiv.classList.add('hidden');
        if (submitBtn) {
            submitBtn.disabled = true;
            submitBtn.textContent = 'Menghubungkan...';
        }

        let client = getClient();
        if (!client) {
            if (submitBtn) submitBtn.textContent = 'Memuat SDK Supabase...';
            await ensureSdkLoaded();
            client = getClient();
        }

        if (!client) {
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.textContent = activeAuthTab === 'login' ? 'Masuk ke Cloud' : 'Daftar Akun Operator';
            }
            if (errDiv) {
                errDiv.className = 'p-2.5 bg-rose-50 rounded-lg border border-rose-200 text-[11px] text-rose-700 font-medium';
                errDiv.textContent = 'Gagal memuat SDK Supabase. Pastikan file services/supabase.js tersedia atau tidak ada ekstensi pemblokir skrip.';
                errDiv.classList.remove('hidden');
            }
            return;
        }

        const email = document.getElementById('auth-email').value.trim();
        const password = document.getElementById('auth-password').value;

        try {
            if (activeAuthTab === 'login') {
                const { data, error } = await client.auth.signInWithPassword({ email, password });
                if (error) throw error;
                currentUser = data.user;
                closeAuthModal();
                updateCloudUI();
                if (typeof window.toast === 'function') {
                    window.toast(`Berhasil masuk sebagai ${email}. Menyinkronkan data cloud...`, 'success');
                }
                await syncFromCloud(false);
            } else {
                const { data, error } = await client.auth.signUp({ email, password });
                if (error) throw error;

                if (data.session) {
                    currentUser = data.user;
                    closeAuthModal();
                    updateCloudUI();
                    if (typeof window.toast === 'function') {
                        window.toast(`Akun berhasil dibuat! Menginisialisasi cloud...`, 'success');
                    }
                    await syncFromCloud(false);
                } else {
                    if (errDiv) {
                        errDiv.className = 'p-3 bg-emerald-50 rounded-lg border border-emerald-200 text-xs text-emerald-800 font-medium';
                        errDiv.innerHTML = `Pendaftaran berhasil! Tautan konfirmasi telah dikirimkan ke <strong>${esc(email)}</strong>. Silakan periksa inbox/spam dan klik tautan konfirmasi sebelum login.`;
                        errDiv.classList.remove('hidden');
                    }
                }
            }
        } catch (err) {
            console.error('[Supabase Auth Error]', err);
            if (errDiv) {
                errDiv.className = 'p-2.5 bg-rose-50 rounded-lg border border-rose-200 text-[11px] text-rose-700 font-medium';
                errDiv.textContent = err.message || 'Gagal autentikasi ke Supabase.';
                errDiv.classList.remove('hidden');
            }
        } finally {
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.textContent = activeAuthTab === 'login' ? 'Masuk ke Cloud' : 'Daftar Akun Operator';
            }
        }
    }

    async function handleLogout() {
        if (!confirm(`Logout dari akun Supabase (${currentUser?.email})? Data offline lokal tetap tersimpan.`)) return;
        const client = getClient();
        try {
            if (client) await client.auth.signOut();
        } catch (err) {
            console.warn('[SupabaseManager] Logout error:', err);
        } finally {
            currentUser = null;
            updateCloudUI();
            if (typeof window.toast === 'function') window.toast('Berhasil logout dari Supabase Cloud.');
        }
    }

    // -------------------------------------------------------------------------
    // 4. Two-Way Synchronization (Cloud <-> Local)
    // -------------------------------------------------------------------------
    async function syncFromCloud(isManual = false) {
        const client = getClient();
        if (!client || !currentUser) {
            if (isManual) openAuthModal();
            return;
        }

        if (isSyncing) return;
        isSyncing = true;
        const syncBtn = document.getElementById('cloud-sync-btn');
        if (syncBtn) {
            syncBtn.classList.add('opacity-50', 'pointer-events-none');
            const span = syncBtn.querySelector('span');
            if (span) span.textContent = 'Syncing...';
        }

        try {
            console.log('[SupabaseManager] Syncing from Supabase Cloud...');

            // Check if cloud has accounts
            const { count: accountCount, error: countErr } = await client
                .from('accounts')
                .select('*', { count: 'exact', head: true });

            if (countErr) throw countErr;

            // If Cloud is empty but local has data, offer initial migration upload!
            if ((accountCount === 0 || accountCount === null) && window.appData?.accounts?.length > 0) {
                console.log('[SupabaseManager] Cloud database is empty. Prompting for initial upload...');
                const accEl = document.getElementById('cloud-migration-acc-count');
                const branchEl = document.getElementById('cloud-migration-branch-count');
                if (accEl) accEl.textContent = window.appData.accounts.length;
                if (branchEl) branchEl.textContent = window.appData.branches.length;
                const modalMig = document.getElementById('modal-cloud-migration');
                if (modalMig) modalMig.classList.remove('hidden');
                return;
            }

            // Cloud has data: fetch all tables in parallel
            const [branchesRes, accountsRes, updatesRes, claimsRes, sourcesRes, topupsRes, vcRes, logsRes, settingsRes] = await Promise.all([
                client.from('branches').select('*').order('created_at', { ascending: true }),
                client.from('accounts').select('*').order('created_at', { ascending: true }),
                client.from('updates').select('*').order('created_at', { ascending: true }),
                client.from('claims').select('*'),
                client.from('account_sources').select('*'),
                client.from('account_topups').select('*'),
                client.from('vc_transactions').select('*'),
                client.from('activity_logs').select('*').order('created_at', { ascending: true }),
                client.from('settings').select('*')
            ]);

            if (branchesRes.error) throw branchesRes.error;
            if (accountsRes.error) throw accountsRes.error;

            if (window.appData) {
                window.appData.branches = branchesRes.data || [];
                window.appData.accounts = accountsRes.data || [];
                window.appData.updates = updatesRes.data || [];
                window.appData.claims = (claimsRes.data || []).map(c => ({
                    ...c,
                    dm_claimed: Number(c.reward_amount_claimed ?? c.dm_claimed ?? 0)
                }));
                window.appData.account_sources = (sourcesRes.data || []).map(s => ({
                    ...s,
                    nominal: Number(s.nominal || 0),
                    bonus_amount: Number(s.bonus_amount || 0),
                    total_received: Number(s.total_received || 0)
                }));
                window.appData.account_topups = (topupsRes.data || []).map(t => ({
                    ...t,
                    nominal: Number(t.nominal || 0),
                    bonus_amount: Number(t.bonus_amount || 0),
                    total_received: Number(t.total_received || 0)
                }));
                window.appData.vc_transactions = (vcRes.data || []).map(v => ({
                    ...v,
                    date: v.transaction_date || v.date,
                    vc_earned: Number(v.vc_earned || 0),
                    vc_spent: Number(v.vc_spent || 0)
                }));

                if (logsRes.data) {
                    window.appData.logs = logsRes.data.map(l => ({
                        log_id: l.log_id,
                        action: l.action,
                        entity_type: l.entity_type,
                        entity_id: l.entity_id,
                        old_value: typeof l.old_value === 'string' ? l.old_value : (l.old_value ? JSON.stringify(l.old_value) : ''),
                        new_value: typeof l.new_value === 'string' ? l.new_value : (l.new_value ? JSON.stringify(l.new_value) : ''),
                        created_at: l.created_at
                    }));
                }

                if (settingsRes.data && settingsRes.data.length > 0) {
                    settingsRes.data.forEach(s => {
                        if (s.key && s.value !== undefined) {
                            window.appData.settings[s.key] = s.value;
                        }
                    });
                }
            }

            // Save fresh data to local cache
            if (typeof window.saveData === 'function') window.saveData();
            if (typeof window.refreshCurrentTab === 'function') window.refreshCurrentTab();

            if (typeof window.toast === 'function') {
                window.toast('Data berhasil disinkronkan dari Supabase Cloud', 'success');
            }
        } catch (err) {
            console.error('[SupabaseManager] Sync error:', err);
            if (typeof window.toast === 'function') {
                window.toast('Gagal sinkronisasi cloud: ' + (err.message || err), 'error');
            }
        } finally {
            isSyncing = false;
            if (syncBtn) {
                syncBtn.classList.remove('opacity-50', 'pointer-events-none');
                const span = syncBtn.querySelector('span');
                if (span) span.textContent = 'Sync';
            }
        }
    }

    // -------------------------------------------------------------------------
    // 5. Initial Migration Upload (Local -> Cloud)
    // -------------------------------------------------------------------------
    async function executeInitialUpload() {
        const client = getClient();
        if (!client || !currentUser) return;
        const btn = document.getElementById('cloud-migration-confirm-btn');
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = `<span class="animate-spin inline-block mr-1">↻</span><span>Mengunggah data ke Cloud...</span>`;
        }

        try {
            console.log('[SupabaseManager] Starting initial upload to Supabase Cloud...');
            const app = window.appData || {};

            // 1. Branches
            if (app.branches && app.branches.length > 0) {
                const branchRows = app.branches.map(b => ({
                    branch_id: b.branch_id,
                    branch_name: b.branch_name,
                    email_login: b.email_login || null,
                    status: b.status || 'Active',
                    notes: b.notes || null
                }));
                const { error: bErr } = await client.from('branches').upsert(branchRows);
                if (bErr) throw bErr;
            }

            // 2. Accounts
            if (app.accounts && app.accounts.length > 0) {
                const accRows = app.accounts.map(a => ({
                    account_id: a.account_id,
                    branch_id: a.branch_id,
                    server_code: a.server_code,
                    level: Number(a.level || 1),
                    status: a.status || 'Pre-farm',
                    status_before_archive: a.status_before_archive || null,
                    archived_at: a.archived_at ? new Date(a.archived_at).toISOString() : null,
                    auto_level_result: a.auto_level_result || 'Untested',
                    notes: a.notes || null
                }));
                const { error: aErr } = await client.from('accounts').upsert(accRows);
                if (aErr) throw aErr;
            }

            // 3. Updates
            if (app.updates && app.updates.length > 0) {
                const updateRows = app.updates.map(u => ({
                    update_id: u.update_id,
                    update_name: u.update_name,
                    start_date: u.start_date || null,
                    end_date: u.end_date || null,
                    status: u.status || 'Active',
                    reward_type: u.reward_type || 'DM',
                    reward_amount: Number(u.reward_amount || 0),
                    eligibility_rule: u.eligibility_rule || 'all_active',
                    notes: u.notes || null
                }));
                const { error: uErr } = await client.from('updates').upsert(updateRows);
                if (uErr) throw uErr;
            }

            // 4. Claims
            if (app.claims && app.claims.length > 0) {
                const claimRows = app.claims.map(c => {
                    const isClaimed = c.claim_status === 'Claimed';
                    return {
                        claim_id: c.claim_id,
                        update_id: c.update_id,
                        account_id: c.account_id,
                        branch_id_at_claim: c.branch_id_at_claim || null,
                        eligibility_status: c.eligibility_status === 'Not eligible' ? 'Not Eligible' : (c.eligibility_status || 'Eligible'),
                        claim_status: c.claim_status || 'Pending',
                        reward_type: c.reward_type || 'DM',
                        reward_amount_claimed: isClaimed ? Number(c.reward_amount_claimed || c.dm_claimed || 0) : 0,
                        claimed_at: isClaimed ? (c.claimed_at ? new Date(c.claimed_at).toISOString() : new Date().toISOString()) : null,
                        notes: c.notes || null
                    };
                });
                const { error: cErr } = await client.from('claims').upsert(claimRows);
                if (cErr) throw cErr;
            }

            // 5. Account Sources
            if (app.account_sources && app.account_sources.length > 0) {
                const srcRows = app.account_sources.map(s => ({
                    source_id: s.source_id,
                    account_id: s.account_id,
                    source_type: s.source_type || 'DM',
                    nominal: Number(s.nominal || 0),
                    bonus_amount: Number(s.bonus_amount || 0),
                    total_received: Number(s.total_received || 0),
                    received_at: s.received_at || null,
                    notes: s.notes || null
                }));
                const { error: sErr } = await client.from('account_sources').upsert(srcRows);
                if (sErr) throw sErr;
            }

            // 6. Account Topups
            if (app.account_topups && app.account_topups.length > 0) {
                const tpRows = app.account_topups.map(t => ({
                    topup_id: t.topup_id,
                    account_id: t.account_id,
                    nominal: Number(t.nominal || 0),
                    bonus_status: t.bonus_status || 'None',
                    bonus_amount: Number(t.bonus_amount || 0),
                    total_received: Number(t.total_received || 0),
                    topup_date: t.topup_date || null,
                    bonus_claim_date: t.bonus_claim_date || null,
                    notes: t.notes || null
                }));
                const { error: tErr } = await client.from('account_topups').upsert(tpRows);
                if (tErr) throw tErr;
            }

            // 7. VC Transactions
            if (app.vc_transactions && app.vc_transactions.length > 0) {
                const vcRows = app.vc_transactions.map(v => ({
                    transaction_id: v.transaction_id,
                    account_id: v.account_id || null,
                    source: v.source || 'Manual',
                    vc_earned: Number(v.vc_earned || 0),
                    vc_spent: Number(v.vc_spent || 0),
                    transaction_date: v.transaction_date || v.date || new Date().toISOString().split('T')[0],
                    description: v.description || null
                })).filter(v => (v.vc_earned > 0 || v.vc_spent > 0));

                if (vcRows.length > 0) {
                    const { error: vcErr } = await client.from('vc_transactions').upsert(vcRows);
                    if (vcErr) console.warn('[SupabaseManager] VC sync warning:', vcErr);
                }
            }

            const modalMig = document.getElementById('modal-cloud-migration');
            if (modalMig) modalMig.classList.add('hidden');

            if (typeof window.toast === 'function') {
                window.toast('Seluruh data berhasil diunggah ke Supabase Cloud!', 'success');
            }
            await syncFromCloud(false);
        } catch (err) {
            console.error('[SupabaseManager] Initial upload failed:', err);
            alert('Gagal mengunggah data ke Supabase Cloud: ' + (err.message || err));
        } finally {
            if (btn) {
                btn.disabled = false;
                btn.innerHTML = `<i data-lucide="upload-cloud" class="w-3.5 h-3.5 mr-1"></i><span>Unggah ke Cloud Sekarang</span>`;
                if (window.lucide && typeof lucide.createIcons === 'function') lucide.createIcons();
            }
        }
    }

    // -------------------------------------------------------------------------
    // 6. Cloud Mutation Event Handlers
    // -------------------------------------------------------------------------
    function onAccountSaved(acc, isNew) {
        const client = getClient();
        if (!client || !currentUser || !acc) return;
        const row = {
            account_id: acc.account_id,
            branch_id: acc.branch_id,
            server_code: acc.server_code,
            level: Number(acc.level || 1),
            status: acc.status || 'Pre-farm',
            status_before_archive: acc.status_before_archive || null,
            archived_at: acc.archived_at ? new Date(acc.archived_at).toISOString() : null,
            auto_level_result: acc.auto_level_result || 'Untested',
            notes: acc.notes || null
        };
        client.from('accounts').upsert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Account]', error);
        });
    }

    function onAccountDeleted(accountId) {
        const client = getClient();
        if (!client || !currentUser || !accountId) return;
        client.rpc('delete_account', { p_account_id: accountId }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Delete Account]', error);
        });
    }

    function onAccountArchived(accountId) {
        const client = getClient();
        if (!client || !currentUser || !accountId) return;
        client.rpc('archive_account', { p_account_id: accountId }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Archive Account]', error);
        });
    }

    function onAccountRestored(accountId) {
        const client = getClient();
        if (!client || !currentUser || !accountId) return;
        client.rpc('restore_account', { p_account_id: accountId }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Restore Account]', error);
        });
    }

    function onBranchSaved(branch, isNew) {
        const client = getClient();
        if (!client || !currentUser || !branch) return;
        const row = {
            branch_id: branch.branch_id,
            branch_name: branch.branch_name,
            email_login: branch.email_login || null,
            status: branch.status || 'Active',
            notes: branch.notes || null
        };
        client.from('branches').upsert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Branch]', error);
        });
    }

    function onBranchDeleted(branchId) {
        const client = getClient();
        if (!client || !currentUser || !branchId) return;
        client.rpc('delete_branch', { p_branch_id: branchId }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Delete Branch]', error);
        });
    }

    function onUpdateSaved(update, isNew) {
        const client = getClient();
        if (!client || !currentUser || !update) return;
        if (isNew) {
            client.rpc('create_update', {
                p_update_id: update.update_id,
                p_update_name: update.update_name,
                p_start_date: update.start_date || null,
                p_end_date: update.end_date || null,
                p_reward_type: update.reward_type || 'DM',
                p_reward_amount: Number(update.reward_amount || 0),
                p_eligibility_rule: update.eligibility_rule || 'all_active',
                p_notes: update.notes || null
            }).then(({ error }) => {
                if (error) console.error('[Supabase Cloud Mutation Error: Create Update]', error);
            });
        } else {
            client.from('updates').update({
                update_name: update.update_name,
                start_date: update.start_date || null,
                end_date: update.end_date || null,
                status: update.status || 'Active',
                notes: update.notes || null
            }).eq('update_id', update.update_id).then(({ error }) => {
                if (error) console.error('[Supabase Cloud Mutation Error: Update]', error);
            });
        }
    }

    function onUpdateDeleted(updateId) {
        const client = getClient();
        if (!client || !currentUser || !updateId) return;
        client.from('claims').delete().eq('update_id', updateId).then(() => {
            client.from('updates').delete().eq('update_id', updateId).then(({ error }) => {
                if (error) console.error('[Supabase Cloud Mutation Error: Delete Update]', error);
            });
        });
    }

    function onClaimStatusChanged(claimId, status, amount) {
        const client = getClient();
        if (!client || !currentUser || !claimId) return;
        client.rpc('set_claim_status', {
            p_claim_id: claimId,
            p_claim_status: status,
            p_reward_amount: Number(amount || 0),
            p_claimed_at: status === 'Claimed' ? new Date().toISOString() : null
        }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Set Claim Status]', error);
        });
    }

    function onBulkClaim(updateId, accountIds, amount) {
        const client = getClient();
        if (!client || !currentUser || !updateId) return;
        client.rpc('bulk_claim', {
            p_update_id: updateId,
            p_account_ids: accountIds,
            p_reward_amount: Number(amount || 0)
        }).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Bulk Claim]', error);
        });
    }

    function onSourceSaved(source) {
        const client = getClient();
        if (!client || !currentUser || !source) return;
        const row = {
            source_id: source.source_id,
            account_id: source.account_id,
            source_type: source.source_type || 'DM',
            nominal: Number(source.nominal || 0),
            bonus_amount: Number(source.bonus_amount || 0),
            total_received: Number(source.total_received || 0),
            received_at: source.received_at || null,
            notes: source.notes || null
        };
        client.from('account_sources').upsert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Account Source]', error);
        });
    }

    function onTopupSaved(topup) {
        const client = getClient();
        if (!client || !currentUser || !topup) return;
        const row = {
            topup_id: topup.topup_id,
            account_id: topup.account_id,
            nominal: Number(topup.nominal || 0),
            bonus_status: topup.bonus_status || 'None',
            bonus_amount: Number(topup.bonus_amount || 0),
            total_received: Number(topup.total_received || 0),
            topup_date: topup.topup_date || null,
            bonus_claim_date: topup.bonus_claim_date || null,
            notes: topup.notes || null
        };
        client.from('account_topups').upsert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Account Topup]', error);
        });
    }

    function onSettingsSaved(settings) {
        const client = getClient();
        if (!client || !currentUser || !settings) return;
        const rows = Object.entries(settings).map(([k, v]) => ({
            key: k,
            value: v
        }));
        client.from('settings').upsert(rows).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Settings]', error);
        });
    }

    function onVcTransactionSaved(tx) {
        const client = getClient();
        if (!client || !currentUser || !tx) return;
        const row = {
            transaction_id: tx.transaction_id,
            account_id: tx.account_id || null,
            source: tx.source || 'Manual',
            vc_earned: Number(tx.vc_earned || 0),
            vc_spent: Number(tx.vc_spent || 0),
            transaction_date: tx.transaction_date || tx.date || new Date().toISOString().split('T')[0],
            description: tx.description || null
        };
        client.from('vc_transactions').upsert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: VC Transaction]', error);
        });
    }

    function onVcTransactionDeleted(txId) {
        const client = getClient();
        if (!client || !currentUser || !txId) return;
        client.from('vc_transactions').delete().eq('transaction_id', txId).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Delete VC Transaction]', error);
        });
    }

    function onLogAdded(log) {
        const client = getClient();
        if (!client || !currentUser || !log) return;
        const row = {
            log_id: log.log_id,
            action: log.action,
            entity_type: log.entity_type,
            entity_id: String(log.entity_id),
            old_value: log.old_value ? (typeof log.old_value === 'object' ? log.old_value : JSON.parse(log.old_value || '{}')) : null,
            new_value: log.new_value ? (typeof log.new_value === 'object' ? log.new_value : JSON.parse(log.new_value || '{}')) : null
        };
        client.from('activity_logs').insert(row).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Log]', error);
        });
    }

    // Expose public API on window
    window.supabaseManager = {
        init,
        isLoggedIn: () => !!currentUser,
        getUser: () => currentUser,
        openAuthModal,
        closeAuthModal,
        setAuthTab,
        handleAuthSubmit,
        handleLogout,
        syncFromCloud,
        executeInitialUpload,
        // Mutation hooks
        onAccountSaved,
        onAccountDeleted,
        onAccountArchived,
        onAccountRestored,
        onBranchSaved,
        onBranchDeleted,
        onUpdateSaved,
        onUpdateDeleted,
        onClaimStatusChanged,
        onBulkClaim,
        onSourceSaved,
        onTopupSaved,
        onSettingsSaved,
        onVcTransactionSaved,
        onVcTransactionDeleted,
        onLogAdded
    };

    console.log('[SupabaseManager] Module loaded.');
})();
