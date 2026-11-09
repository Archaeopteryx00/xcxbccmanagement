create or replace function public.check_active_locks()
returns jsonb
language plpgsql
security definer
as $$
declare
  v_res jsonb;
begin
  select jsonb_agg(jsonb_build_object(
    'pid', pid,
    'state', state,
    'query', query,
    'wait_event_type', wait_event_type,
    'wait_event', wait_event,
    'duration', now() - query_start
  ))
  from pg_stat_activity
  where pid <> pg_backend_pid()
    and state is not null
  into v_res;
  return v_res;
end;
$$;

grant execute on function public.check_active_locks() to anon, authenticated;
