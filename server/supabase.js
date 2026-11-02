// server/supabase.js
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    console.error('ERROR: NEXT_PUBLIC_SUPABASE_URL or NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY not set in .env!');
}

/**
 * Returns a Supabase client scoped to the caller's JWT token (if provided),
 * ensuring PostgreSQL Row Level Security (RLS) is strictly enforced per user.
 */
export function getSupabase(req) {
    const authHeader = req?.headers?.authorization;
    const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

    if (token) {
        return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
            global: {
                headers: {
                    Authorization: `Bearer ${token}`
                }
            },
            auth: {
                persistSession: false,
                autoRefreshToken: false
            }
        });
    }

    // Default unauthenticated / public client
    return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: {
            persistSession: false
        }
    });
}

export { SUPABASE_URL, SUPABASE_ANON_KEY };
