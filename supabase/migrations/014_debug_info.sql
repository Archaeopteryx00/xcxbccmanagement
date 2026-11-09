create or replace function public.get_system_debug_info()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_res jsonb;
begin
  select jsonb_build_object(
    'branches_count', (select count(*) from public.branches),
    'accounts_count', (select count(*) from public.accounts),
    'updates_count', (select count(*) from public.updates),
    'claims_count', (select count(*) from public.claims),
    'sources_count', (select count(*) from public.account_sources),
    'topups_count', (select count(*) from public.account_topups),
    'vc_count', (select count(*) from public.vc_transactions),
    'owners_in_branches', (select jsonb_agg(distinct owner_id) from public.branches),
    'owners_in_accounts', (select jsonb_agg(distinct owner_id) from public.accounts),
    'branches_samples', (select jsonb_agg(jsonb_build_object('id', branch_id, 'owner', owner_id, 'name', branch_name)) from public.branches limit 5)
  ) into v_res;
  return v_res;
end;
$$;

grant execute on function public.get_system_debug_info() to anon, authenticated;
