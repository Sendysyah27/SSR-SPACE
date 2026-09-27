# P2: Tagihan rutin auto-generate (recurring bills)

## Problem

Pengeluaran berulang (kos, langganan, cicilan) harus dicatat manual tiap
bulan. User lupa, laporan bulanan jadi bolong dan budget terlihat longgar
padahal tagihan pasti datang.

## Pola Ollo

Ollo memakai jadwal pola cron-ish per item: nominal, periode (mingguan atau
bulanan), tanggal jangkar, batas akhir opsional. Item yang jatuh tempo
muncul sebagai saran sekali ketuk, bukan insert diam-diam.

## Adaptasi SSR

Ikuti pola saran, bukan insert otomatis. Layar daftar tagihan rutin di hub
Data, tiap baris menampilkan jatuh tempo berikut. Saat jatuh tempo lewat,
muncul kartu saran di Beranda: ketuk Catat untuk insert, ketuk Lewati
untuk tunda ke periode berikut. Insert memakai `TxInputSheet` yang sudah
ada (prefill nominal, kategori, dompet) agar validasi tetap satu pintu.

## Data dan prefs

Tanpa migration. Simpan di prefs `recurring_bills` sebagai list JSON kecil
(maks 30 item): id, label, amount, category, walletId, period
(`weekly`/`monthly`), anchorDay, nextDue (ISO tanggal), active.
Insert hasil tetap baris `transactions` normal via service yang ada.

## Edge cases

Nominal kurs non-IDR disimpan sebagai minor IDR hasil konversi saat catat,
konsisten dengan input manual. Dompet yang dihapus membuat item nonaktif
dengan pesan jelas, bukan insert yatim. Ganti bulan pendek (Februari):
jangkar tanggal 29-31 dijepit ke hari terakhir bulan. Item nonaktif tidak
memunculkan saran.

## Daftar test

Jatuh tempo mingguan dan bulanan dari tanggal jangkar. Jepit akhir bulan
Februari tahun kabisat dan non-kabisat. Lewati memajukan nextDue satu
periode tanpa insert. Dompet hilang menonaktifkan item. Cap 30 item.

## Dampak Supabase dan RLS

Tanpa migration. Tidak ada tabel baru, tidak ada policy baru. Insert
transaksi memakai jalur dan RLS yang sudah ada.
