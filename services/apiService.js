// services/apiService.js
// Client-side API service connecting the frontend UI to the XCX BBC Microservice

const API_BASE_URL = window.XCX_API_BASE_URL || 'http://localhost:3001/api';

class ApiService {
    constructor() {
        this.baseUrl = API_BASE_URL;
    }

    getToken() {
        return localStorage.getItem('xcx_auth_token');
    }

    setToken(token) {
        if (token) {
            localStorage.setItem('xcx_auth_token', token);
        } else {
            localStorage.removeItem('xcx_auth_token');
        }
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const token = this.getToken();

        const headers = {
            'Content-Type': 'application/json',
            ...(options.headers || {})
        };

        if (token) {
            headers['Authorization'] = `Bearer ${token}`;
        }

        try {
            const res = await fetch(url, { ...options, headers });
            const data = await res.json().catch(() => ({}));

            if (!res.ok) {
                const errorMsg = data.error || `HTTP ${res.status}: ${res.statusText}`;
                if (res.status === 401) {
                    this.setToken(null);
                    window.dispatchEvent(new CustomEvent('xcx:unauthorized', { detail: { error: errorMsg } }));
                }
                throw new Error(errorMsg);
            }

            return data;
        } catch (err) {
            console.error(`API Error [${endpoint}]:`, err);
            throw err;
        }
    }

    // Health
    async checkHealth() {
        return this.request('/health');
    }

    // Auth
    async login(email, password) {
        const res = await this.request('/auth/login', {
            method: 'POST',
            body: JSON.stringify({ email, password })
        });
        if (res.access_token) {
            this.setToken(res.access_token);
        }
        return res;
    }

    async logout() {
        try {
            await this.request('/auth/logout', { method: 'POST' });
        } finally {
            this.setToken(null);
        }
    }

    async getUser() {
        return this.request('/auth/user');
    }

    // Overview & Views
    async getOverview() {
        return this.request('/overview');
    }

    // Branches
    async getBranches() {
        return this.request('/branches');
    }

    async createBranch(branchData) {
        return this.request('/branches', {
            method: 'POST',
            body: JSON.stringify(branchData)
        });
    }

    async updateBranch(id, branchData) {
        return this.request(`/branches/${id}`, {
            method: 'PUT',
            body: JSON.stringify(branchData)
        });
    }

    async deleteBranch(id) {
        return this.request(`/branches/${id}`, {
            method: 'DELETE'
        });
    }

    // Accounts
    async getAccounts() {
        return this.request('/accounts');
    }

    async createAccount(accData) {
        return this.request('/accounts', {
            method: 'POST',
            body: JSON.stringify(accData)
        });
    }

    async updateAccount(id, accData) {
        return this.request(`/accounts/${id}`, {
            method: 'PUT',
            body: JSON.stringify(accData)
        });
    }

    async archiveAccount(id) {
        return this.request(`/accounts/${id}/archive`, {
            method: 'POST'
        });
    }

    async restoreAccount(id) {
        return this.request(`/accounts/${id}/restore`, {
            method: 'POST'
        });
    }

    async deleteAccount(id) {
        return this.request(`/accounts/${id}`, {
            method: 'DELETE'
        });
    }

    // Updates & Claims
    async getUpdates() {
        return this.request('/updates');
    }

    async createUpdate(updateData) {
        return this.request('/updates', {
            method: 'POST',
            body: JSON.stringify(updateData)
        });
    }

    async bulkClaim(updateId, accountIds, amount) {
        return this.request(`/updates/${updateId}/bulk-claim`, {
            method: 'POST',
            body: JSON.stringify({ account_ids: accountIds, amount })
        });
    }

    async setClaimStatus(claimId, status, amount, claimedAt) {
        return this.request(`/claims/${claimId}/status`, {
            method: 'POST',
            body: JSON.stringify({ status, amount, claimed_at: claimedAt })
        });
    }

    // Sources & Topups
    async getSources() {
        return this.request('/sources');
    }

    async createSource(data) {
        return this.request('/sources', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    async getTopups() {
        return this.request('/topups');
    }

    async createTopup(data) {
        return this.request('/topups', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    // VC Transactions
    async getVcTransactions() {
        return this.request('/vc');
    }

    async createVcTransaction(data) {
        return this.request('/vc', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    }

    // Activity Logs
    async getLogs() {
        return this.request('/logs');
    }

    // Backup Export
    async exportBackup() {
        return this.request('/backup/export');
    }
}

// Attach globally for browser usage
window.xcxApi = new ApiService();
