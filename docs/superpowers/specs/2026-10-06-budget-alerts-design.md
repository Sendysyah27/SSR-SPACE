# Spec: Budget Alerts (real-time trigger)

Tanggal: 2026-10-06. Status: disetujui user (pendekatan A trigger-only).

## 1. Tujuan

Anggota workspace tahu saat budget kategori melewati ambang — instan,
tanpa membuka layar Budget. Fakta bulanan, kedaluwarsa otomatis.

## 2. Keputusan yang dikunci

- Pemicu: trigger Postgres AFTER INSERT (bukan cron).
- Ambang: custom per budget (`warn_pct`, default 80); breach = 100% (tetap).
- Audiens: semua anggota (bukan hanya bendahara).
- Tanpa read-state: baris alert adalah fakta `(org, bulan, kategori, level)`.

## 3. Backend (`supabase/migration_16_budget_alerts.sql`, user jalankan manual)

- `alter table budgets add column warn_pct int not null default 80`
  + check 1–100.
- Tabel `budget_alerts`: id uuid pk default gen_random_uuid(),
  org_id uuid not null, month text not null (YYYY-MM),
  category text not null (grup lapis-atas, null → 'Lainnya'),
  level text not null check (level in ('warn','breach')),
  spent numeric not null, limit numeric not null,
  created_at timestamptz default now(),
  unique (org_id, month, category, level).
- Fungsi `check_budget_alert()` SECURITY DEFINER, AFTER INSERT ON
  transactions FOR EACH ROW WHEN (NEW.type = 'out'):
  1. Ambil bulan = substring(NEW.date, 1, 7), top = split_part kategori
     (' > ', 1) atau 'Lainnya' bila null/kosong.
  2. Cari budget (org, bulan, kategori=top); bila tak ada → RETURN NEW.
  3. Sum spent `out` bulan itu kategori top (termasuk NEW).
  4. warn_pct dari budget (default 80): bila spent ≥ limit*warn_pct/100
     dan baris warn belum ada → insert.
  5. Bila spent ≥ limit dan baris breach belum ada → insert.
  6. EXCEPTION WHEN OTHERS → RETURN NEW (alert tak boleh blokir catat).
- RLS `budget_alerts`: SELECT untuk member org saja
  (exists org_members, tanpa subquery rekursif); tanpa INSERT/UPDATE/DELETE.
- Tanpa backfill: bulan lama tetap senyap (jujur di changelog).

## 4. Client (tanpa dep/FCM baru)

- Poll: MainShell resume + saat buka tab Budget → select alerts
  (active_org, bulan berjalan) → banner di Budget + badge di hub Profil
  (pola badge aktivitas Space).
- Dialog edit budget: field "Peringatan %" (angka 1–100, default 80),
  ikut alur PIN yang sudah ada.
- Strings baru `ba_warn` ("{cat} sudah {p}% dari budget {m}"),
  `ba_breach` ("{cat} melewati budget {m}"), `ba_warn_label` — ID+EN.

## 5. Test

- `supabase/test/rls_test.sql` T21+: insert out crossing warn → 1 baris warn;
  insert lagi → tetap 1; crossing 100 → baris breach; warn_pct custom
  dihormati; transfer/in/null-budget tak hasilkan baris; client INSERT
  langsung ke budget_alerts ditolak; lintas-org tak terbaca.
- `test/` Dart: pure helper label banner bila ada (stub tr).

## 6. Rollout

1. Merge kode + `migration_16` (CI: analyze, test incl. RLS, APK).
2. User jalankan `migration_16_budget_alerts.sql` di Dashboard.
3. Bump version + changelog (aturan Skema A).

## 7. Bukan scope

Digest/pace harian, notifikasi push saat app tertutup, read-state per user,
alert untuk pemasukan/transfer, backfill historis.
