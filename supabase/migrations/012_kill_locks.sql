-- Check and terminate any hanging / idle in transaction queries
select pg_terminate_backend(pid)
from pg_stat_activity
where state in ('idle in transaction', 'active')
  and pid <> pg_backend_pid()
  and query not like '%pg_stat_activity%';

