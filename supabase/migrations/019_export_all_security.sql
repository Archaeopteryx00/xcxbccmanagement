-- ============================================================================
-- Migration: 019_export_all_security.sql
-- Description: Make export_all security definer for fast single-call sync
-- ============================================================================

create or replace function public.export_all()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_owner_id uuid := auth.uid();
    v_result jsonb;
begin
    if v_owner_id is null then
        return jsonb_build_object('error', 'Not authenticated');
    end if;

    v_result := jsonb_build_object(
        'exported_at', now(),
        'owner_id', v_owner_id,
        'schema_version', 3,
        'branches', (
            select coalesce(jsonb_agg(row_to_json(b)), '[]'::jsonb)
            from public.branches b where b.owner_id = v_owner_id
        ),
        'accounts', (
            select coalesce(jsonb_agg(row_to_json(a)), '[]'::jsonb)
            from public.accounts a where a.owner_id = v_owner_id
        ),
        'updates', (
            select coalesce(jsonb_agg(row_to_json(u)), '[]'::jsonb)
            from public.updates u where u.owner_id = v_owner_id
        ),
        'claims', (
            select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb)
            from public.claims c where c.owner_id = v_owner_id
        ),
        'account_sources', (
            select coalesce(jsonb_agg(row_to_json(s)), '[]'::jsonb)
            from public.account_sources s where s.owner_id = v_owner_id
        ),
        'account_topups', (
            select coalesce(jsonb_agg(row_to_json(t)), '[]'::jsonb)
            from public.account_topups t where t.owner_id = v_owner_id
        ),
        'vc_transactions', (
            select coalesce(jsonb_agg(row_to_json(v)), '[]'::jsonb)
            from public.vc_transactions v where v.owner_id = v_owner_id
        ),
        'settings', (
            select coalesce(jsonb_agg(row_to_json(st)), '[]'::jsonb)
            from public.settings st where st.owner_id = v_owner_id
        ),
        'activity_logs', (
            select coalesce(jsonb_agg(row_to_json(al)), '[]'::jsonb)
            from public.activity_logs al where al.owner_id = v_owner_id
        )
    );

    return v_result;
end;
$$;

grant execute on function public.export_all() to authenticated;
