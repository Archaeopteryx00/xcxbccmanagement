// services/appBridge.js
// Seamless synchronization bridge between XCX BBC Management UI and the Microservice

(function () {
    console.log('[XCX Bridge] Initializing Microservice bridge...');

    let isMicroserviceOnline = false;
    let currentUser = null;

    // -------------------------------------------------------------------------
    // UI Helpers: Status Badge & Login Modal
    // -------------------------------------------------------------------------
    function injectStatusUI() {
        const headerRight = document.querySelector('header .flex.items-center.gap-2\\.5') ||
            document.querySelector('header div:last-child');

        if (headerRight && !document.getElementById('service-status-container')) {
            const container = document.createElement('div');
            container.id = 'service-status-container';
            container.className = 'flex items-center gap-2';
            container.innerHTML = `
                <div id="service-status-badge" class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium bg-neutral-100 text-neutral-600 border border-neutral-200">
                    <span id="service-status-dot" class="w-1.5 h-1.5 rounded-full bg-neutral-400 mr-1.5"></span>
                    <span id="service-status-text">Checking Service...</span>
                </div>
                <button id="auth-status-btn" onclick="window.xcxBridge.handleAuthClick()" class="px-2 py-0.5 rounded text-[10px] font-semibold bg-neutral-900 text-white hover:bg-neutral-800 transition-all">
                    Login
                </button>
            `;
            headerRight.prepend(container);
        }

        injectLoginModal();
    }

    function injectLoginModal() {
        if (document.getElementById('xcx-login-modal')) return;

        const modal = document.createElement('div');
        modal.id = 'xcx-login-modal';
        modal.className = 'fixed inset-0 bg-neutral-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 hidden';
        modal.innerHTML = `
            <div class="bg-white rounded-xl shadow-xl border border-neutral-200 w-full max-w-sm p-6 relative">
                <button onclick="window.xcxBridge.closeLoginModal()" class="absolute top-4 right-4 text-neutral-400 hover:text-neutral-700">
                    ✕
                </button>
                <div class="mb-4">
                    <div class="w-8 h-8 rounded-lg bg-neutral-900 text-white flex items-center justify-center font-bold text-sm mb-2">X</div>
                    <h3 class="text-base font-bold text-neutral-900">Login ke Supabase</h3>
                    <p class="text-xs text-neutral-500">Masuk untuk menyinkronkan data langsung ke Supabase Staging.</p>
                </div>
                <form id="xcx-login-form" onsubmit="window.xcxBridge.submitLogin(event)" class="space-y-3.5">
                    <div>
                        <label class="block text-[11px] font-semibold text-neutral-700 mb-1">Email</label>
                        <input type="email" id="login-email" required placeholder="admin@xcx.com" class="w-full px-3 py-2 text-xs border border-neutral-300 rounded-lg focus:outline-none focus:border-neutral-900">
                    </div>
                    <div>
                        <label class="block text-[11px] font-semibold text-neutral-700 mb-1">Password</label>
                        <input type="password" id="login-password" required placeholder="••••••••" class="w-full px-3 py-2 text-xs border border-neutral-300 rounded-lg focus:outline-none focus:border-neutral-900">
                    </div>
                    <div id="login-error-msg" class="text-[11px] text-rose-600 hidden font-medium"></div>
                    <button type="submit" id="login-submit-btn" class="w-full py-2 bg-neutral-900 hover:bg-neutral-800 text-white font-semibold text-xs rounded-lg transition-all shadow-sm">
                        Masuk
                    </button>
                </form>
            </div>
        `;
        document.body.appendChild(modal);
    }

    function updateBadge(status, text) {
        const badge = document.getElementById('service-status-badge');
        const dot = document.getElementById('service-status-dot');
        const label = document.getElementById('service-status-text');
        const authBtn = document.getElementById('auth-status-btn');

        if (!badge || !dot || !label) return;

        if (status === 'online') {
            badge.className = 'inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium bg-emerald-50 text-emerald-800 border border-emerald-200';
            dot.className = 'w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5 animate-pulse';
            label.textContent = text || 'Microservice Connected';
        } else if (status === 'offline') {
            badge.className = 'inline-flex items-center px-2 py-0.5 rounded text-[10px] font-medium bg-amber-50 text-amber-800 border border-amber-200';
            dot.className = 'w-1.5 h-1.5 rounded-full bg-amber-500 mr-1.5';
            label.textContent = text || 'Offline (LocalStorage)';
        }

        if (authBtn) {
            authBtn.textContent = currentUser ? 'Logout' : 'Login';
            if (currentUser) {
                authBtn.title = `Logged in as ${currentUser.email}`;
            }
        }
    }

    // -------------------------------------------------------------------------
    // Sync Logic: Fetch from Supabase via Microservice
    // -------------------------------------------------------------------------
    async function syncDataFromMicroservice() {
        if (!window.xcxApi) return;
        try {
            console.log('[XCX Bridge] Synchronizing data from microservice views & tables...');
            const [overview, accounts, branches, updatesData, sources, topups, vc] = await Promise.all([
                window.xcxApi.getOverview(),
                window.xcxApi.getAccounts(),
                window.xcxApi.getBranches(),
                window.xcxApi.getUpdates(),
                window.xcxApi.getSources().catch(() => []),
                window.xcxApi.getTopups().catch(() => []),
                window.xcxApi.getVcTransactions().catch(() => [])
            ]);

            // Update appData with live database data
            if (window.appData) {
                window.appData.branches = branches || [];
                window.appData.accounts = accounts || [];
                window.appData.updates = updatesData.updates || [];
                window.appData.claims = updatesData.claims || [];
                window.appData.account_sources = sources || [];
                window.appData.account_topups = topups || [];
                window.appData.vc_transactions = vc || [];

                // Store database view calculations directly
                window.appData._dbOverview = overview;
            }

            console.log('[XCX Bridge] Sync complete. Refreshing active view...');
            if (typeof window.refreshCurrentTab === 'function') {
                window.refreshCurrentTab();
            } else if (typeof window.renderDashboard === 'function') {
                window.renderDashboard();
            }
            if (typeof window.toast === 'function') {
                window.toast('Tersinkronisasi dengan Supabase Staging', 'success');
            }
        } catch (err) {
            console.error('[XCX Bridge] Sync error:', err);
        }
    }

    // -------------------------------------------------------------------------
    // Lifecycle Initialization
    // -------------------------------------------------------------------------
    async function checkService() {
        injectStatusUI();

        if (!window.xcxApi) {
            console.warn('[XCX Bridge] xcxApi not loaded.');
            updateBadge('offline');
            return;
        }

        try {
            await window.xcxApi.checkHealth();
            isMicroserviceOnline = true;
            console.log('[XCX Bridge] Microservice is online.');

            // Check Auth status
            const token = window.xcxApi.getToken();
            if (token) {
                try {
                    const { user } = await window.xcxApi.getUser();
                    currentUser = user;
                    updateBadge('online', `Supabase (${user.email.split('@')[0]})`);
                    await syncDataFromMicroservice();
                } catch (e) {
                    currentUser = null;
                    updateBadge('online', 'Connected (Login Needed)');
                }
            } else {
                updateBadge('online', 'Connected (Login Needed)');
            }
        } catch (err) {
            isMicroserviceOnline = false;
            console.warn('[XCX Bridge] Microservice unreachable, using LocalStorage fallback.');
            updateBadge('offline');
        }
    }

    // -------------------------------------------------------------------------
    // Public Bridge API
    // -------------------------------------------------------------------------
    window.xcxBridge = {
        isOnline: () => isMicroserviceOnline,
        getUser: () => currentUser,
        sync: syncDataFromMicroservice,

        handleAuthClick: () => {
            if (currentUser) {
                if (confirm(`Logout dari akun ${currentUser.email}?`)) {
                    window.xcxApi.logout().then(() => {
                        currentUser = null;
                        updateBadge('online', 'Connected (Login Needed)');
                        if (typeof window.toast === 'function') window.toast('Berhasil logout.');
                    });
                }
            } else {
                window.xcxBridge.openLoginModal();
            }
        },

        openLoginModal: () => {
            const m = document.getElementById('xcx-login-modal');
            if (m) m.classList.remove('hidden');
        },

        closeLoginModal: () => {
            const m = document.getElementById('xcx-login-modal');
            if (m) m.classList.add('hidden');
        },

        submitLogin: async (e) => {
            e.preventDefault();
            const email = document.getElementById('login-email').value;
            const password = document.getElementById('login-password').value;
            const errorDiv = document.getElementById('login-error-msg');
            const submitBtn = document.getElementById('login-submit-btn');

            errorDiv.classList.add('hidden');
            submitBtn.disabled = true;
            submitBtn.textContent = 'Memverifikasi...';

            try {
                const res = await window.xcxApi.login(email, password);
                currentUser = res.user;
                window.xcxBridge.closeLoginModal();
                updateBadge('online', `Supabase (${res.user.email.split('@')[0]})`);
                if (typeof window.toast === 'function') window.toast('Login berhasil! Mengambil data Supabase...');
                await syncDataFromMicroservice();
            } catch (err) {
                errorDiv.textContent = err.message || 'Login gagal. Periksa email & password.';
                errorDiv.classList.remove('hidden');
            } finally {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Masuk';
            }
        }
    };

    window.addEventListener('DOMContentLoaded', () => {
        setTimeout(checkService, 200);
    });

    window.addEventListener('xcx:unauthorized', () => {
        currentUser = null;
        updateBadge('online', 'Connected (Login Needed)');
        window.xcxBridge.openLoginModal();
    });
})();
