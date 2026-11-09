create or replace function public.get_auth_users_info()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_res jsonb;
begin
  select jsonb_agg(jsonb_build_object(
    'id', id,
    'email', email,
    'created_at', created_at
  )) from auth.users into v_res;
  return v_res;
end;
$$;

grant execute on function public.get_auth_users_info() to anon, authenticated;
