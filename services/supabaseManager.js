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

                    if ((event === 'SIGNED_IN' || event === 'TOKEN_REFRESHED') && session) {
                        await syncFromCloud(false);
                    } else if (event === 'SIGNED_OUT') {
                        currentUser = null;
                        updateCloudUI();
                        if (typeof window.toast === 'function') window.toast('Sesi berakhir. Kembali ke mode LocalStorage.', 'info');
                    }
                });

                // Sync when tab becomes visible again (e.g. switching from laptop to phone)
                document.addEventListener('visibilitychange', () => {
                    if (document.visibilityState === 'visible' && currentUser && !isSyncing) {
                        console.log('[SupabaseManager] Tab visible — triggering background sync...');
                        syncFromCloud(false).catch(err => console.warn('[SupabaseManager] visibilitychange sync error:', err));
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
    // 3. UI Status & Mandated Login Gate
    // -------------------------------------------------------------------------
    function updateCloudUI() {
        const authScreen = document.getElementById('auth-screen');
        const appRoot = document.getElementById('app-root');
        const userAvatar = document.getElementById('user-avatar');
        const userEmailDisplay = document.getElementById('user-email-display');
        const userStatusLabel = document.getElementById('user-status-label');

        if (currentUser) {
            // Authenticated: hide login screen, show app
            if (authScreen) authScreen.classList.add('hidden');
            if (appRoot) appRoot.classList.remove('hidden');

            // Update sidebar user footer
            const email = currentUser.email || 'Operator';
            const initials = email.substring(0, 2).toUpperCase();
            if (userAvatar) userAvatar.textContent = initials;
            if (userEmailDisplay) userEmailDisplay.textContent = email;
            if (userStatusLabel) userStatusLabel.textContent = '✓ Terkoneksi ke Cloud';
        } else {
            // Not authenticated: show login gate, hide app
            if (authScreen) authScreen.classList.remove('hidden');
            if (appRoot) appRoot.classList.add('hidden');

            // Reset sidebar user footer
            if (userAvatar) userAvatar.textContent = '?';
            if (userEmailDisplay) userEmailDisplay.textContent = 'Belum login';
            if (userStatusLabel) userStatusLabel.textContent = 'Cloud Database';
        }

        if (window.lucide && typeof lucide.createIcons === 'function') {
            lucide.createIcons();
        }
    }

    async function signOut() {
        await handleLogout();
    }

    function openAuthModal() {
        setAuthTab('login');
        const authScreen = document.getElementById('auth-screen');
        if (authScreen) authScreen.classList.remove('hidden');
        const errDiv = document.getElementById('auth-error-msg');
        if (errDiv) errDiv.classList.add('hidden');

        // Ensure SDK is ready in background
        if (!getClient()) {
            ensureSdkLoaded().then(() => getClient());
        }
    }

    function closeAuthModal() {
        if (!currentUser) return; // Tidak boleh ditutup jika belum login!
        const authScreen = document.getElementById('auth-screen');
        if (authScreen) authScreen.classList.add('hidden');
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
            if (tabLogin) tabLogin.className = 'flex-1 py-2 text-center text-neutral-900 bg-white rounded-md font-bold shadow-sm transition-all';
            if (tabReg) tabReg.className = 'flex-1 py-2 text-center text-neutral-500 hover:text-neutral-900 font-medium transition-all';
            if (submitBtn) submitBtn.innerHTML = '<span>Masuk ke Cloud Database</span>';
            if (infoMsg) infoMsg.textContent = 'Aplikasi ini menggunakan database PostgreSQL di Cloud. Masuk untuk mengakses data akun, cabang, dan klaim Anda secara otomatis.';
        } else {
            if (tabLogin) tabLogin.className = 'flex-1 py-2 text-center text-neutral-500 hover:text-neutral-900 font-medium transition-all';
            if (tabReg) tabReg.className = 'flex-1 py-2 text-center text-neutral-900 bg-white rounded-md font-bold shadow-sm transition-all';
            if (submitBtn) submitBtn.innerHTML = '<span>Daftar Akun Operator</span>';
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
            submitBtn.innerHTML = '<span class="animate-spin inline-block mr-1">↻</span><span>Menghubungkan ke Cloud...</span>';
        }

        let client = getClient();
        if (!client) {
            await ensureSdkLoaded();
            client = getClient();
        }

        if (!client) {
            if (submitBtn) {
                submitBtn.disabled = false;
                submitBtn.innerHTML = '<span>Masuk ke Cloud Database</span>';
            }
            if (errDiv) {
                errDiv.className = 'p-3 bg-rose-50 rounded-xl border border-rose-200 text-[11px] text-rose-700 font-medium';
                errDiv.textContent = 'Gagal memuat SDK Supabase. Pastikan koneksi internet aktif atau layanan Supabase dapat diakses.';
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
                updateCloudUI();
                if (typeof window.toast === 'function') {
                    window.toast(`Berhasil masuk sebagai ${email}. Mengambil data dari Cloud...`, 'success');
                }
                await syncFromCloud(false);
            } else {
                const { data, error } = await client.auth.signUp({ email, password });
                if (error) throw error;

                if (data.session) {
                    currentUser = data.user;
                    updateCloudUI();
                    if (typeof window.toast === 'function') {
                        window.toast(`Akun berhasil dibuat! Terkoneksi ke Cloud...`, 'success');
                    }
                    await syncFromCloud(false);
                } else {
                    if (errDiv) {
                        errDiv.className = 'p-3 bg-emerald-50 rounded-xl border border-emerald-200 text-xs text-emerald-800 font-medium';
                        errDiv.innerHTML = `Pendaftaran berhasil! Tautan konfirmasi telah dikirimkan ke <strong>${esc(email)}</strong>. Silakan periksa inbox/spam dan klik tautan konfirmasi sebelum login.`;
                        errDiv.classList.remove('hidden');
                    }
                }
            }
        } catch (err) {
            console.error('[Supabase Auth Error]', err);
            if (errDiv) {
                errDiv.className = 'p-3 bg-rose-50 rounded-xl border border-rose-200 text-[11px] text-rose-700 font-medium';
                errDiv.textContent = err.message || 'Gagal autentikasi ke Supabase.';
                errDiv.classList.remove('hidden');
            }
        } finally {
            if (submitBtn) {
                submitBtn.disabled = false;
                if (activeAuthTab === 'login') {
                    submitBtn.innerHTML = '<span>Masuk ke Cloud Database</span>';
                } else {
                    submitBtn.innerHTML = '<span>Daftar Akun Operator</span>';
                }
            }
        }
    }

    async function handleLogout() {
        if (!confirm(`Logout dari akun Supabase Cloud (${currentUser?.email})?`)) return;
        const client = getClient();
        try {
            if (client) await client.auth.signOut();
        } catch (err) {
            console.warn('[SupabaseManager] Logout error:', err);
        } finally {
            currentUser = null;
            if (window.appData) {
                window.appData.branches = [];
                window.appData.accounts = [];
                window.appData.updates = [];
                window.appData.claims = [];
                window.appData.account_sources = [];
                window.appData.account_topups = [];
                window.appData.vc_transactions = [];
                window.appData.logs = [];
            }
            updateCloudUI();
            if (typeof window.toast === 'function') window.toast('Berhasil logout dari sistem Cloud.');
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
            const icon = syncBtn.querySelector('i');
            if (span) span.textContent = 'Syncing...';
            if (icon) icon.classList.add('animate-spin');
        }

        if (isManual && typeof window.showLoading === 'function') {
            window.showLoading('Sinkronisasi Cloud', 'Menghubungkan ke Supabase Cloud...', 25);
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
                if (typeof window.hideLoading === 'function') window.hideLoading();
                console.log('[SupabaseManager] Cloud database is empty. Prompting for initial upload...');
                const accEl = document.getElementById('cloud-migration-acc-count');
                const branchEl = document.getElementById('cloud-migration-branch-count');
                if (accEl) accEl.textContent = window.appData.accounts.length;
                if (branchEl) branchEl.textContent = window.appData.branches.length;
                const modalMig = document.getElementById('modal-cloud-migration');
                if (modalMig) modalMig.classList.remove('hidden');
                return;
            }

            if (isManual && typeof window.updateLoading === 'function') {
                window.updateLoading('Sinkronisasi Cloud', 'Mengambil data cabang, akun, dan klaim...', 60);
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

            if (isManual && typeof window.updateLoading === 'function') {
                window.updateLoading('Sinkronisasi Cloud', 'Memperbarui data dan ringkasan keuangan...', 90);
            }

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
            if (typeof window.hideLoading === 'function') {
                window.hideLoading();
            }
            if (syncBtn) {
                syncBtn.classList.remove('opacity-50', 'pointer-events-none');
                const span = syncBtn.querySelector('span');
                const icon = syncBtn.querySelector('i');
                if (span) span.textContent = 'Sync';
                if (icon) icon.classList.remove('animate-spin');
            }
        }
    }

    // -------------------------------------------------------------------------
    // 5. Full Data Upload & Backup Restoration to Cloud
    // -------------------------------------------------------------------------

    // Helper: normalize update status from legacy values
    function normalizeUpdateStatus(s) {
        const map = { 'Open': 'Active', 'open': 'Active', 'active': 'Active', 'closed': 'Closed', 'archived': 'Archived', 'draft': 'Draft' };
        return map[s] || (['Active','Closed','Archived','Draft'].includes(s) ? s : 'Active');
    }

    // Helper: normalize branch status from legacy values
    function normalizeBranchStatus(s) {
        return ['Active','Inactive','Archived'].includes(s) ? s : 'Active';
    }

    // Helper: safe ISO date string (accepts 'YYYY-MM-DD' or full ISO)
    function toISODate(val) {
        if (!val) return null;
        try {
            const d = new Date(val);
            if (isNaN(d.getTime())) return null;
            return d.toISOString();
        } catch { return null; }
    }

    async function uploadFullData(customData = null) {
        const client = getClient();
        if (!client || !currentUser) {
            return { success: false, error: 'Belum terautentikasi ke Supabase Cloud.' };
        }

        try {
            console.log('[SupabaseManager] Starting full data upload/restore to Supabase Cloud...');
            const app = customData || window.appData || {};

            // ---- Try server-side RPC first (atomic, constraint-safe) ----
            if (typeof window.showLoading === 'function') {
                window.showLoading('Memulihkan ke Cloud', 'Mengirim data ke server...', 20);
            }
            console.log('[SupabaseManager] Calling restore_full_backup RPC...');
            // Wrap RPC in a 45-second timeout so it doesn't hang silently
            let rpcData, rpcErr;
            try {
                const rpcResult = await Promise.race([
                    client.rpc('restore_full_backup', { payload: app }),
                    new Promise((_, reject) =>
                        setTimeout(() => reject(new Error('RPC timeout setelah 45 detik')), 45000)
                    )
                ]);
                rpcData = rpcResult.data;
                rpcErr  = rpcResult.error;
            } catch (timeoutErr) {
                rpcErr = { message: timeoutErr.message };
            }

            if (rpcErr) {
                console.warn('[SupabaseManager] RPC failed, falling back to client upsert:', rpcErr.message);
                if (typeof window.updateLoading === 'function') {
                    window.updateLoading('Mengunggah ke Cloud', 'Fallback: menyimpan data cabang... (1/8)', 10);
                }
                // fall through to client-side upsert below
            } else if (rpcData && rpcData.success === false) {
                console.warn('[SupabaseManager] RPC returned error:', rpcData.error, rpcData.detail);
                throw new Error('Restore gagal di server: ' + rpcData.error);
            } else if (rpcData && rpcData.success === true) {
                console.log('[SupabaseManager] RPC restore OK:', JSON.stringify(rpcData.counts));
                if (typeof window.updateLoading === 'function') {
                    window.updateLoading('Selesai!', 'Menyinkronkan data dari Cloud...', 95);
                }
                await syncFromCloud(false);
                console.log('[SupabaseManager] uploadFullData complete (via RPC).');
                return { success: true };
            }

            // ---- Fallback: client-side delete-then-insert ----
            console.log('[SupabaseManager] Using client-side fallback upsert...');

            // ---- STEP 1: Branches ----
            if (typeof window.showLoading === 'function') {
                window.showLoading('Mengunggah ke Cloud', 'Menyimpan data cabang... (1/8)', 10);
            }
            if (app.branches && app.branches.length > 0) {
                const branchRows = app.branches.map(b => ({
                    branch_id: b.branch_id,
                    branch_name: b.branch_name,
                    email_login: b.email_login || null,
                    status: normalizeBranchStatus(b.status),
                    notes: b.notes || null
                }));
                console.log('[SupabaseManager] Upserting branches:', branchRows.length);
                const { error: bErr } = await client.from('branches').upsert(branchRows, { onConflict: 'branch_id' });
                if (bErr) throw new Error('Gagal upload branches: ' + bErr.message);
                console.log('[SupabaseManager] Branches OK');
            }

            // ---- STEP 2: Accounts ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan data akun... (2/8)', 25);
            }
            if (app.accounts && app.accounts.length > 0) {
                const validAccountStatuses = ['Pre-farm','Farming','Ready','Failed','Archived'];
                const accRows = app.accounts.map(a => {
                    const status = validAccountStatuses.includes(a.status) ? a.status : 'Pre-farm';
                    const isArchived = status === 'Archived';
                    return {
                        account_id: a.account_id,
                        branch_id: a.branch_id,
                        server_code: a.server_code,
                        level: Math.max(1, Number(a.level) || 1),
                        status,
                        // status_before_archive only valid when archived
                        status_before_archive: isArchived ? (a.status_before_archive || null) : null,
                        // archived_at must be set when archived
                        archived_at: isArchived ? (toISODate(a.archived_at) || new Date().toISOString()) : null,
                        auto_level_result: ['Untested','Success','Failed'].includes(a.auto_level_result)
                            ? a.auto_level_result : 'Untested',
                        notes: a.notes || null
                    };
                });
                console.log('[SupabaseManager] Upserting accounts:', accRows.length);
                const { error: aErr } = await client.from('accounts').upsert(accRows, { onConflict: 'account_id' });
                if (aErr) throw new Error('Gagal upload accounts: ' + aErr.message);
                console.log('[SupabaseManager] Accounts OK');
            }

            // ---- STEP 3: Updates ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan periode update... (3/8)', 38);
            }
            if (app.updates && app.updates.length > 0) {
                const updateRows = app.updates.map(u => ({
                    update_id: u.update_id,
                    update_name: u.update_name,
                    start_date: u.start_date || null,
                    end_date: u.end_date || null,
                    // Legacy backup may use 'Open' — normalize to 'Active'
                    status: normalizeUpdateStatus(u.status),
                    // Legacy backup may not have reward_type/reward_amount
                    reward_type: ['DM','VC'].includes(u.reward_type) ? u.reward_type : 'DM',
                    reward_amount: Math.max(0, Number(u.reward_amount) || 0),
                    eligibility_rule: ['all_active','ready_only'].includes(u.eligibility_rule)
                        ? u.eligibility_rule : 'all_active',
                    notes: u.notes || null
                }));
                console.log('[SupabaseManager] Upserting updates:', updateRows.length, updateRows.map(r => r.status));
                const { error: uErr } = await client.from('updates').upsert(updateRows, { onConflict: 'update_id' });
                if (uErr) throw new Error('Gagal upload updates: ' + uErr.message);
                console.log('[SupabaseManager] Updates OK');
            }

            // ---- STEP 4: Claims ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan data klaim... (4/8)', 50);
            }
            if (app.claims && app.claims.length > 0) {
                const validClaimStatuses = ['Pending','Claimed','Failed','Not Eligible'];
                const claimRows = app.claims.map(c => {
                    const claimStatus = validClaimStatuses.includes(c.claim_status) ? c.claim_status : 'Pending';
                    const isClaimed = claimStatus === 'Claimed';
                    // Normalize eligibility — legacy uses 'Not eligible' (lowercase e)
                    let eligStatus = c.eligibility_status || 'Eligible';
                    if (eligStatus === 'Not eligible') eligStatus = 'Not Eligible';
                    if (!['Eligible','Not Eligible'].includes(eligStatus)) eligStatus = 'Eligible';

                    return {
                        claim_id: c.claim_id,
                        update_id: c.update_id,
                        account_id: c.account_id,
                        branch_id_at_claim: c.branch_id_at_claim || null,
                        eligibility_status: eligStatus,
                        claim_status: claimStatus,
                        // Legacy backup uses 'dm_claimed' field, new uses 'reward_amount_claimed'
                        reward_type: ['DM','VC'].includes(c.reward_type) ? c.reward_type : 'DM',
                        reward_amount_claimed: isClaimed
                            ? Math.max(0, Number(c.reward_amount_claimed ?? c.dm_claimed ?? 0))
                            : 0,
                        // claimed_at must not be null when status is 'Claimed'
                        claimed_at: isClaimed
                            ? (toISODate(c.claimed_at) || new Date().toISOString())
                            : null,
                        notes: c.notes || null
                    };
                });
                console.log('[SupabaseManager] Upserting claims:', claimRows.length);
                const { error: cErr } = await client.from('claims').upsert(claimRows, { onConflict: 'claim_id' });
                if (cErr) throw new Error('Gagal upload claims: ' + cErr.message);
                console.log('[SupabaseManager] Claims OK');
            }

            // ---- STEP 5: Account Sources ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan sumber akun... (5/8)', 63);
            }
            if (app.account_sources && app.account_sources.length > 0) {
                const srcRows = app.account_sources.map(s => ({
                    source_id: s.source_id,
                    account_id: s.account_id,
                    source_type: s.source_type || 'DM',
                    nominal: Math.max(0, Number(s.nominal) || 0),
                    bonus_amount: Math.max(0, Number(s.bonus_amount) || 0),
                    total_received: Math.max(0, Number(s.total_received) || 0),
                    received_at: s.received_at || null,
                    bonus_status: s.bonus_status || 'Not Eligible',
                    multiplier: Math.max(1, Number(s.multiplier) || 1),
                    notes: s.notes || null
                }));
                console.log('[SupabaseManager] Upserting account_sources:', srcRows.length);
                const { error: sErr } = await client.from('account_sources').upsert(srcRows, { onConflict: 'source_id' });
                if (sErr) throw new Error('Gagal upload account sources: ' + sErr.message);
                console.log('[SupabaseManager] Account Sources OK');
            }

            // ---- STEP 6: Account Topups ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan top-up akun... (6/8)', 73);
            }
            if (app.account_topups && app.account_topups.length > 0) {
                const tpRows = app.account_topups.map(t => ({
                    topup_id: t.topup_id,
                    account_id: t.account_id,
                    nominal: Math.max(0, Number(t.nominal) || 0),
                    bonus_status: t.bonus_status || 'None',
                    bonus_amount: Math.max(0, Number(t.bonus_amount) || 0),
                    total_received: Math.max(0, Number(t.total_received) || 0),
                    topup_date: t.topup_date || null,
                    bonus_claim_date: t.bonus_claim_date || null,
                    notes: t.notes || null
                }));
                console.log('[SupabaseManager] Upserting account_topups:', tpRows.length);
                const { error: tErr } = await client.from('account_topups').upsert(tpRows, { onConflict: 'topup_id' });
                if (tErr) throw new Error('Gagal upload account topups: ' + tErr.message);
                console.log('[SupabaseManager] Account Topups OK');
            }

            // ---- STEP 7: VC Transactions ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan transaksi VC... (7/8)', 83);
            }
            if (app.vc_transactions && app.vc_transactions.length > 0) {
                const vcRows = app.vc_transactions.map(v => ({
                    transaction_id: v.transaction_id,
                    account_id: v.account_id || null,
                    source: v.source || 'Manual',
                    vc_earned: Math.max(0, Number(v.vc_earned) || 0),
                    vc_spent: Math.max(0, Number(v.vc_spent) || 0),
                    transaction_date: v.transaction_date || v.date || new Date().toISOString().split('T')[0],
                    description: v.description || v.notes || null
                })).filter(v => v.vc_earned > 0 || v.vc_spent > 0);

                if (vcRows.length > 0) {
                    console.log('[SupabaseManager] Upserting vc_transactions:', vcRows.length);
                    const { error: vcErr } = await client.from('vc_transactions').upsert(vcRows, { onConflict: 'transaction_id' });
                    if (vcErr) console.warn('[SupabaseManager] VC sync warning:', vcErr.message || vcErr);
                    else console.log('[SupabaseManager] VC Transactions OK');
                }
            }

            // ---- STEP 8: Settings ----
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Mengunggah ke Cloud', 'Menyimpan pengaturan... (8/8)', 93);
            }
            if (app.settings && typeof app.settings === 'object') {
                const settingRows = Object.entries(app.settings).map(([k, v]) => ({
                    key: k,
                    // DB stores value as text — serialize non-strings
                    value: typeof v === 'string' ? v : String(v)
                }));
                if (settingRows.length > 0) {
                    console.log('[SupabaseManager] Upserting settings:', settingRows.length);
                    const { error: setErr } = await client.from('settings').upsert(settingRows, { onConflict: 'key' });
                    if (setErr) console.warn('[SupabaseManager] Settings sync warning:', setErr.message || setErr);
                    else console.log('[SupabaseManager] Settings OK');
                }
            }

            const modalMig = document.getElementById('modal-cloud-migration');
            if (modalMig) modalMig.classList.add('hidden');

            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Selesai!', 'Menyinkronkan data dari Cloud...', 100);
            }
            console.log('[SupabaseManager] All tables uploaded. Starting syncFromCloud...');
            await syncFromCloud(false);
            console.log('[SupabaseManager] uploadFullData complete.');
            return { success: true };
        } catch (err) {
            console.error('[SupabaseManager] uploadFullData error:', err);
            return { success: false, error: err.message || String(err) };
        } finally {
            if (typeof window.hideLoading === 'function') {
                window.hideLoading();
            }
        }
    }

    async function executeInitialUpload() {
        const btn = document.getElementById('cloud-migration-confirm-btn');
        if (btn) {
            btn.disabled = true;
            btn.innerHTML = `<span class="animate-spin inline-block mr-1">↻</span><span>Mengunggah data ke Cloud...</span>`;
        }

        try {
            const res = await uploadFullData();
            if (res.success) {
                if (typeof window.toast === 'function') {
                    window.toast('Seluruh data berhasil diunggah ke Supabase Cloud!', 'success');
                }
            } else {
                alert('Gagal mengunggah data ke Supabase Cloud: ' + res.error);
            }
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
        uploadFullData,
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
        onLogAdded,
        signOut
    };

    // Auto-initialize Supabase session & cloud sync on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            init().catch(err => console.error('[SupabaseManager] Init failed:', err));
        });
    } else {
        init().catch(err => console.error('[SupabaseManager] Init failed:', err));
    }

    console.log('[SupabaseManager] Module loaded.');
})();
