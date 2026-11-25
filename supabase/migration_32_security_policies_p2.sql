-- ========== migration_32_security_policies_p2.sql ==========
-- SSR SPACE migration 32: lanjutan patch RLS P2 (audit 2026-11-25).
-- Jalankan di Supabase Dashboard -> SQL Editor (sekali; idempotent)
-- SETELAH migration_31.
--
-- Menutup 3 temuan P2:
-- [P2] budgets: policy FOR ALL member -> semua anggota bisa menulis
--      anggaran, padahal mode "bendahara" mengunci tulis ke owner/admin.
--      Fix: SELECT tetap member; tulis via can_write_space(org_id).
-- [P2] subscriptions: FOR ALL member -> klien bisa mengarang baris
--      langganan. Fix: read-only anggota; tulis hanya service_role
--      (edge function) yang bypass RLS.
-- [P2] dataset AI (koreksi, alias merchant, umpan balik): cek hanya
--      user_id -> user bisa menempelkan data ke org_id yang bukan
--      tempatnya menjadi anggota. Fix: syarat user_id + anggota org.

-- Helper anti-rekursi untuk policy P2 (satu-satunya pembaca org_members).
create or replace function public.is_org_member(p_org_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from org_members m
    where m.org_id = p_org_id
      and m.user_id = auth.uid()
  );
$$;

revoke execute on function public.is_org_member(uuid) from public, anon;
grant execute on function public.is_org_member(uuid) to authenticated;

-- [P2] budgets: baca member, tulis ikut mode ruang.
drop policy if exists "member budgets" on budgets;
drop policy if exists "member read budgets" on budgets;
create policy "member read budgets" on budgets
  for select using (public.is_org_member(org_id));

drop policy if exists "space write budgets" on budgets;
create policy "space write budgets" on budgets
  for insert with check (public.can_write_space(org_id));

drop policy if exists "space update budgets" on budgets;
create policy "space update budgets" on budgets
  for update using (public.can_write_space(org_id))
  with check (public.can_write_space(org_id));

drop policy if exists "space delete budgets" on budgets;
create policy "space delete budgets" on budgets
  for delete using (public.can_write_space(org_id));

-- [P2] subscriptions: read-only anggota; tulis hanya service_role.
drop policy if exists "member subscriptions" on subscriptions;
drop policy if exists "member read subscriptions" on subscriptions;
create policy "member read subscriptions" on subscriptions
  for select using (public.is_org_member(org_id));

-- [P2] ai_correction_events: riwayat koreksi milik user DI org tempat ia anggota.
do $$
begin
  if to_regclass('public.ai_correction_events') is not null then
    drop policy if exists ai_correction_events_select_own on ai_correction_events;
    create policy ai_correction_events_select_own on ai_correction_events
      for select
      to authenticated
      using (user_id = auth.uid() and public.is_org_member(org_id));

    drop policy if exists ai_correction_events_insert_own on ai_correction_events;
    create policy ai_correction_events_insert_own on ai_correction_events
      for insert
      to authenticated
      with check (user_id = auth.uid() and public.is_org_member(org_id));
  end if;
end $$;

-- [P2] user_merchant_aliases: alias milik user DI org tempat ia anggota.
do $$
begin
  if to_regclass('public.user_merchant_aliases') is not null then
    drop policy if exists user_merchant_aliases_select_own on user_merchant_aliases;
    create policy user_merchant_aliases_select_own on user_merchant_aliases
      for select
      to authenticated
      using (user_id = auth.uid() and public.is_org_member(org_id));

    drop policy if exists user_merchant_aliases_insert_own on user_merchant_aliases;
    create policy user_merchant_aliases_insert_own on user_merchant_aliases
      for insert
      to authenticated
      with check (user_id = auth.uid() and public.is_org_member(org_id));

    drop policy if exists user_merchant_aliases_update_own on user_merchant_aliases;
    create policy user_merchant_aliases_update_own on user_merchant_aliases
      for update
      to authenticated
      using (user_id = auth.uid() and public.is_org_member(org_id))
      with check (user_id = auth.uid() and public.is_org_member(org_id));
  end if;
end $$;

-- [P2] ai_assistant_feedback: umpan balik milik user DI org tempat ia anggota.
do $$
begin
  if to_regclass('public.ai_assistant_feedback') is not null then
    drop policy if exists ai_assistant_feedback_select_own on ai_assistant_feedback;
    create policy ai_assistant_feedback_select_own on ai_assistant_feedback
      for select
      to authenticated
      using (user_id = auth.uid() and public.is_org_member(org_id));

    drop policy if exists ai_assistant_feedback_insert_own on ai_assistant_feedback;
    create policy ai_assistant_feedback_insert_own on ai_assistant_feedback
      for insert
      to authenticated
      with check (user_id = auth.uid() and public.is_org_member(org_id));

    drop policy if exists ai_assistant_feedback_update_own on ai_assistant_feedback;
    create policy ai_assistant_feedback_update_own on ai_assistant_feedback
      for update
      to authenticated
      using (user_id = auth.uid() and public.is_org_member(org_id))
      with check (user_id = auth.uid() and public.is_org_member(org_id));
  end if;
end $$;