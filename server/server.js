// server/server.js
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { getSupabase } from './supabase.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// ----------------------------------------------------------------------------
// Health Check
// ----------------------------------------------------------------------------
app.get('/api/health', (req, res) => {
    res.json({
        status: 'ok',
        service: 'XCX BBC Management Microservice',
        timestamp: new Date().toISOString()
    });
});

// ----------------------------------------------------------------------------
// Auth Endpoints
// ----------------------------------------------------------------------------
app.post('/api/auth/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        const sb = getSupabase(req);
        const { data, error } = await sb.auth.signInWithPassword({ email, password });
        if (error) {
            return res.status(401).json({ error: error.message });
        }

        res.json({
            access_token: data.session.access_token,
            expires_at: data.session.expires_at,
            user: {
                id: data.user.id,
                email: data.user.email
            }
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/auth/logout', async (req, res) => {
    try {
        const sb = getSupabase(req);
        await sb.auth.signOut();
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/auth/user', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data: { user }, error } = await sb.auth.getUser();
        if (error || !user) {
            return res.status(401).json({ error: 'Unauthorized or token expired' });
        }
        res.json({ user });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Overview & Analytical Views (Single Source of Truth)
// ----------------------------------------------------------------------------
app.get('/api/overview', async (req, res) => {
    try {
        const sb = getSupabase(req);

        const [globalRes, branchPerfRes, patchRes, monthlyRes] = await Promise.all([
            sb.from('v_global_totals').select('*').single(),
            sb.from('v_branch_performance').select('*'),
            sb.from('v_patch_summary').select('*'),
            sb.from('v_monthly_totals').select('*')
        ]);

        if (globalRes.error) throw globalRes.error;

        res.json({
            global_totals: globalRes.data,
            branch_performance: branchPerfRes.data || [],
            patch_summary: patchRes.data || [],
            monthly_totals: monthlyRes.data || []
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Branches Endpoints
// ----------------------------------------------------------------------------
app.get('/api/branches', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb
            .from('branches')
            .select('*')
            .order('created_at', { ascending: true });

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/branches', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { branch_id, branch_name, email_login, status, notes } = req.body;
        const id = branch_id || `b_${Date.now()}`;

        const { data, error } = await sb
            .from('branches')
            .insert({
                branch_id: id,
                branch_name,
                email_login,
                status: status || 'Active',
                notes
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.put('/api/branches/:id', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { branch_name, email_login, status, notes } = req.body;

        const { data, error } = await sb
            .from('branches')
            .update({ branch_name, email_login, status, notes })
            .eq('branch_id', req.params.id)
            .select()
            .single();

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.delete('/api/branches/:id', async (req, res) => {
    try {
        const sb = getSupabase(req);
        // Call RPC delete_branch which safely blocks if accounts exist
        const { error } = await sb.rpc('delete_branch', { p_branch_id: req.params.id });
        if (error) throw error;
        res.json({ success: true, branch_id: req.params.id });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Accounts Endpoints
// ----------------------------------------------------------------------------
app.get('/api/accounts', async (req, res) => {
    try {
        const sb = getSupabase(req);
        // Read directly from view v_account_totals for calculated balances!
        const { data, error } = await sb
            .from('v_account_totals')
            .select('*')
            .order('account_id', { ascending: true });

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/accounts', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { account_id, branch_id, server_code, level, status, auto_level_result, notes } = req.body;
        const id = account_id || `acc_${Date.now()}`;

        const { data, error } = await sb
            .from('accounts')
            .insert({
                account_id: id,
                branch_id,
                server_code,
                level: Number(level) || 1,
                status: status || 'Pre-farm',
                auto_level_result: auto_level_result || 'Untested',
                notes
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.put('/api/accounts/:id', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { branch_id, server_code, level, status, auto_level_result, notes } = req.body;

        const { data, error } = await sb
            .from('accounts')
            .update({
                branch_id,
                server_code,
                level: Number(level) || 1,
                status,
                auto_level_result,
                notes
            })
            .eq('account_id', req.params.id)
            .select()
            .single();

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.post('/api/accounts/:id/archive', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.rpc('archive_account', { p_account_id: req.params.id });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.post('/api/accounts/:id/restore', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.rpc('restore_account', { p_account_id: req.params.id });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.delete('/api/accounts/:id', async (req, res) => {
    try {
        const sb = getSupabase(req);
        // Single atomic transaction with negative VC balance protection & log
        const { data, error } = await sb.rpc('delete_account', { p_account_id: req.params.id });
        if (error) throw error;
        res.json({ success: true, snapshot: data });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Updates & Claims Endpoints
// ----------------------------------------------------------------------------
app.get('/api/updates', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const [updatesRes, claimsRes] = await Promise.all([
            sb.from('updates').select('*').order('created_at', { ascending: false }),
            sb.from('claims').select('*, accounts(server_code, branch_id, status)')
        ]);

        if (updatesRes.error) throw updatesRes.error;
        if (claimsRes.error) throw claimsRes.error;

        res.json({
            updates: updatesRes.data,
            claims: claimsRes.data
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/updates', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { update_id, update_name, start_date, end_date, reward_type, reward_amount, eligibility_rule, notes } = req.body;
        const id = update_id || `up_${Date.now()}`;

        // Uses RPC create_update to populate claims ONCE for active accounts
        const { data, error } = await sb.rpc('create_update', {
            p_update_id: id,
            p_update_name: update_name,
            p_start_date: start_date || null,
            p_end_date: end_date || null,
            p_reward_type: reward_type || 'DM',
            p_reward_amount: Number(reward_amount) || 0,
            p_eligibility_rule: eligibility_rule || 'all_active',
            p_notes: notes || null
        });

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.post('/api/updates/:id/bulk-claim', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { account_ids, amount } = req.body;

        // Uses RPC bulk_claim (idempotent, skips archived/not eligible, patch default)
        const { data, error } = await sb.rpc('bulk_claim', {
            p_update_id: req.params.id,
            p_account_ids: account_ids || [],
            p_amount: amount !== undefined ? Number(amount) : null
        });

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.post('/api/claims/:id/status', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { status, amount, claimed_at } = req.body;

        const { data, error } = await sb.rpc('set_claim_status', {
            p_claim_id: req.params.id,
            p_status: status,
            p_amount: amount !== undefined ? Number(amount) : null,
            p_claimed_at: claimed_at || null
        });

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Sources & Topups Endpoints
// ----------------------------------------------------------------------------
app.get('/api/sources', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.from('account_sources').select('*').order('created_at', { ascending: false });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/sources', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { account_id, source_type, nominal, bonus_amount, received_at, notes } = req.body;
        const total = (Number(nominal) || 0) + (Number(bonus_amount) || 0);

        const { data, error } = await sb
            .from('account_sources')
            .insert({
                source_id: `src_${Date.now()}`,
                account_id,
                source_type: source_type || 'Farming Task',
                nominal: Number(nominal) || 0,
                bonus_amount: Number(bonus_amount) || 0,
                total_received: total,
                received_at: received_at || null,
                notes
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

app.get('/api/topups', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.from('account_topups').select('*').order('created_at', { ascending: false });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/topups', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { account_id, nominal, bonus_status, bonus_amount, topup_date, bonus_claim_date, notes } = req.body;
        const total = (Number(nominal) || 0) + (Number(bonus_amount) || 0);

        const { data, error } = await sb
            .from('account_topups')
            .insert({
                topup_id: `tp_${Date.now()}`,
                account_id,
                nominal: Number(nominal) || 0,
                bonus_status: bonus_status || 'None',
                bonus_amount: Number(bonus_amount) || 0,
                total_received: total,
                topup_date: topup_date || null,
                bonus_claim_date: bonus_claim_date || null,
                notes
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// VC Transactions Endpoints
// ----------------------------------------------------------------------------
app.get('/api/vc', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.from('vc_transactions').select('*').order('transaction_date', { ascending: false });
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/vc', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { account_id, source, vc_earned, vc_spent, transaction_date, description } = req.body;

        const { data, error } = await sb
            .from('vc_transactions')
            .insert({
                transaction_id: `vctx_${Date.now()}`,
                account_id: account_id || null, // null = global VC
                source: source || 'Manual Entry',
                vc_earned: Number(vc_earned) || 0,
                vc_spent: Number(vc_spent) || 0,
                transaction_date: transaction_date || new Date().toISOString().split('T')[0],
                description
            })
            .select()
            .single();

        if (error) throw error;
        res.status(201).json(data);
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Activity Logs Endpoints (Append-Only)
// ----------------------------------------------------------------------------
app.get('/api/logs', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb
            .from('activity_logs')
            .select('*')
            .order('created_at', { ascending: false })
            .limit(100);

        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Backup & Export Endpoint (Full JSON)
// ----------------------------------------------------------------------------
app.get('/api/backup/export', async (req, res) => {
    try {
        const sb = getSupabase(req);
        const { data, error } = await sb.rpc('export_all');
        if (error) throw error;
        res.json(data);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ----------------------------------------------------------------------------
// Start Server
// ----------------------------------------------------------------------------
app.listen(PORT, () => {
    console.log(`=======================================================`);
    console.log(`XCX BBC Management Microservice is running on port ${PORT}`);
    console.log(`API URL: http://localhost:${PORT}/api`);
    console.log(`Health check: http://localhost:${PORT}/api/health`);
    console.log(`=======================================================`);
});
