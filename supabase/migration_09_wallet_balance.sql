-- migration_09: view saldo per dompet (Sprint A2)
-- Jalankan di Supabase Dashboard → SQL Editor SEBELUM pakai APK baru.

create or replace view public.wallet_balance
with (security_invoker = true) as
select
  w.org_id,
  w.id as wallet_id,
  coalesce(sum(case
    when t.type = 'in'       and t.wallet_id = w.id    then  t.amount
    when t.type = 'out'      and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.wallet_id = w.id    then -t.amount
    when t.type = 'transfer' and t.to_wallet_id = w.id then  t.amount
    else 0 end), 0)::numeric as balance
from public.wallets w
left join public.transactions t
  on t.org_id = w.org_id
 and (t.wallet_id = w.id or t.to_wallet_id = w.id)
group by w.org_id, w.id;

grant select on public.wallet_balance to authenticated;
