-- SSR SPACE migration 10: invite workspace (token hash, sekali pakai)
-- Jalankan di Supabase Dashboard → SQL Editor SETELAH migration_09.

create table if not exists org_invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizations(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'admin')),
  token_hash text not null unique,
  created_by uuid not null,
  expires_at timestamptz not null default (now() + interval '7 days'),
  max_uses int not null default 1,
  used_count int not null default 0,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);

alter table org_invites enable row level security;

-- SELECT: hanya admin/org. is_org_admin = SECURITY DEFINER (migration_08),
-- jangan subquery org_members di sini (aturan anti-recursion AGENTS.md).
drop policy if exists "admin read org_invites" on org_invites;
create policy "admin read org_invites" on org_invites
  for select using (public.is_org_admin(org_id));

drop policy if exists "admin create org_invites" on org_invites;
create policy "admin create org_invites" on org_invites
  for insert with check (
    public.is_org_admin(org_id) and created_by = auth.uid()
  );

drop policy if exists "admin update org_invites" on org_invites;
create policy "admin update org_invites" on org_invites
  for update using (public.is_org_admin(org_id));

-- Join HANYA lewat RPC. sha256 bawaan Postgres (PG11+), tanpa pgcrypto.
create or replace function public.join_org_by_invite(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  inv record;
  v_hash text;
  v_org uuid;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_hash := encode(sha256(convert_to(trim(both from p_token), 'UTF8')), 'hex');

  select * into inv
  from org_invites
  where token_hash = v_hash
  limit 1;

  if not found or inv.revoked then
    raise exception 'INVITE_INVALID';
  end if;
  if inv.expires_at < now() then
    raise exception 'INVITE_EXPIRED';
  end if;
  if inv.used_count >= inv.max_uses then
    raise exception 'INVITE_EXHAUSTED';
  end if;

  -- idempotent: sudah member → sukses tanpa tambah used_count
  select org_id into v_org
  from org_members
  where org_id = inv.org_id and user_id = v_uid;
  if found then
    return v_org;
  end if;

  insert into org_members(org_id, user_id, role)
  values (inv.org_id, v_uid, inv.role);

  update org_invites
  set used_count = used_count + 1
  where id = inv.id;

  return inv.org_id;
end $$;

grant execute on function public.join_org_by_invite(text) to authenticated;
