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
    let isUploading = false;
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
                        // User explicitly signed in via form
                        await syncFromCloud(false);
                    } else if (event === 'SIGNED_OUT') {
                        currentUser = null;
                        updateCloudUI();
                        if (typeof window.toast === 'function') window.toast('Sesi berakhir. Kembali ke mode LocalStorage.', 'info');
                    }
                });

                // Sync when tab becomes visible again, throttled to at most once every 60s
                let lastSyncTime = 0;
                document.addEventListener('visibilitychange', () => {
                    const now = Date.now();
                    if (document.visibilityState === 'visible' && currentUser && !isSyncing && (now - lastSyncTime > 60000)) {
                        lastSyncTime = now;
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
    let initPromise = null;
    function init() {
        if (initPromise) return initPromise;
        initPromise = (async () => {
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
        })();
        return initPromise;
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

        if (isSyncing || isUploading) return;
        isSyncing = true;
        const syncBtn = document.getElementById('cloud-sync-btn');
        if (syncBtn) {
            syncBtn.classList.add('opacity-50', 'pointer-events-none');
            const span = syncBtn.querySelector('span');
            const icon = syncBtn.querySelector('i, svg');
            if (span) span.textContent = 'Syncing...';
            if (icon) icon.classList.add('animate-spin');
        }

        if (isManual && typeof window.showLoading === 'function') {
            window.showLoading('Sinkronisasi Cloud', 'Menghubungkan ke Supabase Cloud...', 25);
        }

        try {
            console.log('[SupabaseManager] Syncing from Supabase Cloud...');

            if (isManual && typeof window.updateLoading === 'function') {
                window.updateLoading('Sinkronisasi Cloud', 'Mengambil data dari server Cloud...', 50);
            }

            // Step 1: Try ultra-fast single RPC call (export_all returns all tables in <100ms)
            let cloudData = null;
            try {
                const { data: expData, error: expErr } = await Promise.race([
                    client.rpc('export_all'),
                    new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout export_all 10s')), 10000))
                ]);
                if (!expErr && expData && Array.isArray(expData.accounts)) {
                    cloudData = expData;
                    console.log('[SupabaseManager] Fast sync via export_all OK:', {
                        branches: expData.branches?.length,
                        accounts: expData.accounts?.length,
                        claims: expData.claims?.length
                    });
                }
            } catch (rpcErr) {
                console.warn('[SupabaseManager] export_all RPC bypassed/failed:', rpcErr.message);
            }

            // Step 2: Fallback to parallel select if export_all was not used
            if (!cloudData) {
                console.log('[SupabaseManager] Running parallel table fetch fallback...');
                const fetchPromise = Promise.all([
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
                const timeoutPromise = new Promise((_, reject) =>
                    setTimeout(() => reject(new Error('Koneksi sinkronisasi timeout 10 detik')), 10000)
                );

                const [branchesRes, accountsRes, updatesRes, claimsRes, sourcesRes, topupsRes, vcRes, logsRes, settingsRes] =
                    await Promise.race([fetchPromise, timeoutPromise]);

                if (branchesRes.error) throw branchesRes.error;
                if (accountsRes.error) throw accountsRes.error;

                cloudData = {
                    branches: branchesRes.data || [],
                    accounts: accountsRes.data || [],
                    updates: updatesRes.data || [],
                    claims: claimsRes.data || [],
                    account_sources: sourcesRes.data || [],
                    account_topups: topupsRes.data || [],
                    vc_transactions: vcRes.data || [],
                    activity_logs: logsRes.data || [],
                    settings: settingsRes.data || []
                };
            }

            // If Cloud is empty but local has data, offer initial migration upload
            if ((!cloudData.accounts || cloudData.accounts.length === 0) && window.appData?.accounts?.length > 0) {
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
                window.updateLoading('Sinkronisasi Cloud', 'Memperbarui tampilan...', 90);
            }

            if (window.appData) {
                window.appData.branches = cloudData.branches || [];
                window.appData.accounts = cloudData.accounts || [];
                window.appData.updates = cloudData.updates || [];
                window.appData.claims = (cloudData.claims || []).map(c => ({
                    ...c,
                    dm_claimed: Number(c.reward_amount_claimed ?? c.dm_claimed ?? 0)
                }));
                window.appData.account_sources = (cloudData.account_sources || []).map(s => ({
                    ...s,
                    nominal: Number(s.nominal || 0),
                    bonus_amount: Number(s.bonus_amount || 0),
                    total_received: Number(s.total_received || 0)
                }));
                window.appData.account_topups = (cloudData.account_topups || []).map(t => ({
                    ...t,
                    nominal: Number(t.nominal || 0),
                    bonus_amount: Number(t.bonus_amount || 0),
                    total_received: Number(t.total_received || 0)
                }));
                window.appData.vc_transactions = (cloudData.vc_transactions || []).map(v => ({
                    ...v,
                    date: v.transaction_date || v.date,
                    vc_earned: Number(v.vc_earned || 0),
                    vc_spent: Number(v.vc_spent || 0)
                }));

                if (cloudData.activity_logs) {
                    window.appData.logs = cloudData.activity_logs.map(l => ({
                        log_id: l.log_id,
                        action: l.action,
                        entity_type: l.entity_type,
                        entity_id: l.entity_id,
                        old_value: typeof l.old_value === 'string' ? l.old_value : (l.old_value ? JSON.stringify(l.old_value) : ''),
                        new_value: typeof l.new_value === 'string' ? l.new_value : (l.new_value ? JSON.stringify(l.new_value) : ''),
                        created_at: l.created_at
                    }));
                }

                if (!window.appData.settings || typeof window.appData.settings !== 'object') {
                    window.appData.settings = {};
                }
                if (Array.isArray(cloudData.settings) && cloudData.settings.length > 0) {
                    cloudData.settings.forEach(s => {
                        if (s.key && s.value !== undefined) {
                            window.appData.settings[s.key] = s.value;
                        }
                    });
                }

                // Ensure currentSelectedUpdateId is synced if available
                if (window.appData.updates && window.appData.updates.length > 0) {
                    if (!window.currentSelectedUpdateId || !window.appData.updates.some(u => u.update_id === window.currentSelectedUpdateId)) {
                        window.currentSelectedUpdateId = window.appData.updates[0].update_id;
                    }
                }

                // Re-normalize if helper exists
                if (typeof window.normalizeAppData === 'function') {
                    window.appData = window.normalizeAppData(window.appData);
                }

                console.log(`[SupabaseManager] Synced data applied: ${window.appData.accounts.length} accounts, ${window.appData.claims.length} claims, ${window.appData.branches.length} branches.`);
            }

            // Save fresh data to local cache
            if (typeof window.saveData === 'function') window.saveData();
            if (typeof window.refreshCurrentTab === 'function') window.refreshCurrentTab();
            if (window.lucide && typeof window.lucide.createIcons === 'function') window.lucide.createIcons();

            if (typeof window.toast === 'function') {
                window.toast(`Data tersinkronisasi: ${window.appData?.accounts?.length || 0} akun dari Cloud`, 'success');
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
                const icon = syncBtn.querySelector('i, svg');
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
        if (isUploading) return { success: false, error: 'Operasi upload/restore sedang berjalan.' };
        isUploading = true;

        try {
            console.log('[SupabaseManager] Starting full data upload/restore to Supabase Cloud...');
            const app = customData || window.appData || {};

            // ---- Server-side atomic restore via fast set-based RPC ----
            if (typeof window.showLoading === 'function') {
                window.showLoading('Memulihkan ke Cloud', 'Menyimpan database ke server Cloud...', 30);
            }
            console.log('[SupabaseManager] Calling restore_full_backup RPC...');
            
            // Allow up to 30 seconds for server-side transactional restore
            let rpcData = null;
            let rpcErr = null;
            try {
                const rpcResult = await Promise.race([
                    client.rpc('restore_full_backup', { payload: app }),
                    new Promise((_, reject) =>
                        setTimeout(() => reject(new Error('Koneksi timeout setelah 30 detik.')), 30000)
                    )
                ]);
                rpcData = rpcResult.data;
                rpcErr  = rpcResult.error;
            } catch (err) {
                rpcErr = { message: err.message || String(err) };
            }

            if (rpcErr) {
                console.error('[SupabaseManager] RPC error:', rpcErr);
                throw new Error('Gagal restore ke Cloud: ' + (rpcErr.message || 'Unknown error'));
            }

            if (rpcData && rpcData.success === false) {
                console.error('[SupabaseManager] RPC returned failure:', rpcData.error, rpcData.detail);
                throw new Error('Restore gagal di server: ' + (rpcData.error || 'Terjadi kesalahan'));
            }

            console.log('[SupabaseManager] RPC restore OK:', JSON.stringify(rpcData?.counts));
            if (typeof window.updateLoading === 'function') {
                window.updateLoading('Selesai!', 'Menyinkronkan data dari Cloud...', 95);
            }
            isUploading = false;
            await syncFromCloud(false);
            console.log('[SupabaseManager] uploadFullData complete.');
            return { success: true };
        } catch (err) {
            console.error('[SupabaseManager] uploadFullData error:', err);
            return { success: false, error: err.message || String(err) };
        } finally {
            isUploading = false;
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

    function onAccountsBulkUpdated(accounts) {
        const client = getClient();
        if (!client || !currentUser || !Array.isArray(accounts) || accounts.length === 0) return;
        const rows = accounts.map(acc => ({
            account_id: acc.account_id,
            branch_id: acc.branch_id,
            server_code: acc.server_code,
            level: Number(acc.level || 1),
            status: acc.status || 'Pre-farm',
            status_before_archive: acc.status_before_archive || null,
            archived_at: acc.archived_at ? new Date(acc.archived_at).toISOString() : null,
            auto_level_result: acc.auto_level_result || 'Untested',
            notes: acc.notes || null
        }));
        client.from('accounts').upsert(rows).then(({ error }) => {
            if (error) console.error('[Supabase Cloud Mutation Error: Bulk Accounts]', error);
            else console.log(`[SupabaseManager] Cloud bulk updated: ${rows.length} accounts`);
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
        onAccountsBulkUpdated,
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
