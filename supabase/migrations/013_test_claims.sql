-- Check if there are locks or blocking queries
do $$
begin
  -- Try deleting from claims with a 2 second statement timeout
  set local statement_timeout = '3s';
  delete from public.claims where 1=0;
end $$;
