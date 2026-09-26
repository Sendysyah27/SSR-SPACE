import 'package:ssr_space/services/app_settings.dart';

/// Tabel string ID/EN. Copy Indonesia = teks yang sudah tayang
/// (byte-identik); ganti teks UI hanya lewat sini.
const _t = <String, Map<String, String>>{
  // Umum
  'retry': {'id': 'Coba lagi', 'en': 'Retry'},
  'reload': {'id': 'Muat ulang', 'en': 'Reload'},
  'cancel': {'id': 'Batal', 'en': 'Cancel'},
  'save': {'id': 'Simpan', 'en': 'Save'},
  'back': {'id': 'Kembali', 'en': 'Back'},
  'conn_error': {'id': 'Periksa koneksi.', 'en': 'Check your connection.'},
  // Jenis transaksi
  'tx_in': {'id': 'Masuk', 'en': 'Income'},
  'tx_out': {'id': 'Keluar', 'en': 'Expense'},
  'tx_transfer': {'id': 'Transfer', 'en': 'Transfer'},
  // Navigasi
  'nav_beranda': {'id': 'Beranda', 'en': 'Home'},
  'nav_transaksi': {'id': 'Transaksi', 'en': 'Transactions'},
  'nav_budget': {'id': 'Budget', 'en': 'Budget'},
  'nav_laporan': {'id': 'Laporan', 'en': 'Reports'},
  'nav_lainnya': {'id': 'Lainnya', 'en': 'More'},
  'nav_dompet': {'id': 'Dompet', 'en': 'Wallets'},
  'act_catat': {'id': 'Catat', 'en': 'Record'},
  // Beranda
  'beranda_recent': {'id': 'Transaksi terbaru', 'en': 'Recent transactions'},
  'beranda_empty_t': {
    'id': 'Belum ada transaksi bulan ini',
    'en': 'No transactions this month yet',
  },
  'beranda_empty_s': {
    'id': 'Catat pemasukan atau pengeluaran untuk mengisi buku kas.',
    'en': 'Record income or expenses to fill your ledger.',
  },
  'beranda_empty_a': {'id': 'Catat transaksi', 'en': 'Record transaction'},
  'beranda_surplus': {'id': 'SURPLUS', 'en': 'SURPLUS'},
  'beranda_defisit': {'id': 'DEFISIT', 'en': 'DEFICIT'},
  'beranda_loading': {'id': 'Memuat ringkasan...', 'en': 'Loading summary...'},
  'beranda_err': {
    'id': 'Gagal memuat beranda. Periksa koneksi.',
    'en': 'Failed to load home. Check your connection.',
  },
  'beranda_tx_line': {
    'id': '{n} transaksi {m}',
    'en': '{n} transactions · {m}',
  },
  'beranda_diff': {'id': 'Selisih {m}', 'en': 'Net {m}'},
  'beranda_vs_out': {'id': '{p}% dari pengeluaran', 'en': '{p}% of expenses'},
  // Transaksi
  'tx_err_load': {
    'id': 'Gagal memuat transaksi. Periksa koneksi.',
    'en': 'Failed to load transactions. Check your connection.',
  },
  'tx_err_amount': {
    'id': 'Isi nominal dengan angka yang benar.',
    'en': 'Enter a valid amount.',
  },
  'tx_updated': {'id': 'Transaksi diperbarui', 'en': 'Transaction updated'},
  'tx_err_42501': {
    'id': 'Tidak punya akses ke workspace ini.',
    'en': 'No access to this workspace.',
  },
  'tx_err_23503': {
    'id': 'Dompet tidak valid. Muat ulang lalu pilih lagi.',
    'en': 'Invalid wallet. Reload and choose again.',
  },
  'tx_err_23514': {
    'id': 'Data tidak lolos validasi server.',
    'en': 'Data failed server validation.',
  },
  'tx_err_23505': {
    'id': 'Transaksi duplikat sudah tercatat.',
    'en': 'Duplicate transaction already recorded.',
  },
  'tx_err_pgrst': {
    'id': 'Gagal {a}: respons server tidak valid.',
    'en': 'Failed to {a}: invalid server response.',
  },
  'tx_err_code': {
    'id': 'Gagal {a} ({c}). Coba lagi.',
    'en': 'Failed to {a} ({c}). Try again.',
  },
  'tx_err_generic': {
    'id': 'Gagal {a}. Coba lagi.',
    'en': 'Failed to {a}. Try again.',
  },
  'tx_act_save': {'id': 'menyimpan', 'en': 'save'},
  'tx_act_del': {'id': 'menghapus', 'en': 'delete'},
  'tx_del_title': {'id': 'Hapus transaksi', 'en': 'Delete transaction'},
  'tx_del_body': {
    'id': 'Hapus transaksi ini? Tidak bisa dibatalkan.',
    'en': 'Delete this transaction? This cannot be undone.',
  },
  'tx_delete': {'id': 'Hapus', 'en': 'Delete'},
  'tx_deleted': {'id': 'Transaksi dihapus', 'en': 'Transaction deleted'},
  'tx_no_org_t': {'id': 'Belum ada workspace', 'en': 'No workspace yet'},
  'tx_no_org_s': {
    'id': 'Pilih atau buat workspace dulu di menu Lainnya.',
    'en': 'Choose or create a workspace under More first.',
  },
  'tx_editing': {'id': 'Mengubah {c}', 'en': 'Editing {c}'},
  'tx_editing_tx': {'id': 'transaksi', 'en': 'transaction'},
  'tx_form_edit': {'id': 'Mengubah transaksi', 'en': 'Editing transaction'},
  'tx_form_add': {'id': 'Catat transaksi', 'en': 'Record transaction'},
  'tx_history': {'id': 'Riwayat {m}', 'en': 'History {m}'},
  'tx_empty_t': {
    'id': 'Belum ada transaksi bulan ini',
    'en': 'No transactions this month yet',
  },
  'tx_empty_s': {
    'id': 'Catat pemasukan atau pengeluaran lewat form di atas.',
    'en': 'Record income or expenses using the form above.',
  },
  'tx_empty_a': {'id': 'Isi form catat', 'en': 'Fill the form'},
  'tx_cancel_edit': {'id': 'Batalkan edit', 'en': 'Cancel editing'},
  'tx_f_nominal': {'id': 'Nominal', 'en': 'Amount'},
  'tx_f_cat': {'id': 'Kategori (misal Makan)', 'en': 'Category (e.g. Food)'},
  'tx_f_note': {'id': 'Catatan', 'en': 'Note'},
  'tx_f_wallet': {'id': 'Dompet', 'en': 'Wallet'},
  'tx_f_towallet': {'id': 'Dompet tujuan', 'en': 'Destination wallet'},
  'tx_save_edit': {'id': 'Simpan perubahan', 'en': 'Save changes'},
  'tx_save_add': {'id': 'Simpan transaksi', 'en': 'Save transaction'},
  'txv_amount': {
    'id': 'Nominal harus lebih dari 0',
    'en': 'Amount must be greater than 0',
  },
  'txv_wallet': {'id': 'Pilih dompet', 'en': 'Choose a wallet'},
  'txv_towallet': {
    'id': 'Pilih dompet tujuan',
    'en': 'Choose the destination wallet',
  },
  'txv_same': {
    'id': 'Dompet tujuan sama dengan asal',
    'en': 'Destination is the same as source',
  },
  // Dompet
  'w_err_name': {
    'id': 'Isi nama dompet dulu.',
    'en': 'Enter a wallet name first.',
  },
  'w_added': {'id': 'Dompet ditambahkan.', 'en': 'Wallet added.'},
  'w_err_save': {
    'id': 'Gagal menyimpan. Periksa koneksi.',
    'en': 'Failed to save. Check your connection.',
  },
  'w_noorg_t': {
    'id': 'Pilih atau buat workspace dulu.',
    'en': 'Choose or create a workspace first.',
  },
  'w_noorg_s': {
    'id': 'Dompet selalu menempel pada satu workspace.',
    'en': 'Wallets always belong to one workspace.',
  },
  'w_total': {'id': 'Total aset', 'en': 'Total assets'},
  'w_empty_t': {'id': 'Belum ada dompet.', 'en': 'No wallets yet.'},
  'w_empty_s': {
    'id': 'Tambah dompet pertama lewat form di bawah.',
    'en': 'Add your first wallet using the form below.',
  },
  'w_empty_a': {'id': 'Isi dompet', 'en': 'Fill wallet'},
  'w_new': {'id': 'Dompet baru', 'en': 'New wallet'},
  'w_f_name': {
    'id': 'Nama dompet (Kas, Dana, Bank)',
    'en': 'Wallet name (Cash, Dana, Bank)',
  },
  'w_f_type': {'id': 'Jenis', 'en': 'Type'},
  'w_cash': {'id': 'Tunai', 'en': 'Cash'},
  'w_ewallet': {'id': 'E-wallet', 'en': 'E-wallet'},
  'w_bank': {'id': 'Bank', 'en': 'Bank'},
  'w_save': {'id': 'Simpan dompet', 'en': 'Save wallet'},
  'w_notloaded': {'id': 'Belum termuat', 'en': 'Not loaded'},
  'w_err_recursion': {
    'id': 'Gagal memuat dompet: RLS recursion. Jalankan migration_08 di Supabase.',
    'en':
        'Failed to load wallets: RLS recursion. Run migration_08 in Supabase.',
  },
  'w_err_perm': {
    'id': 'Gagal memuat dompet: izin RLS. Cek membership workspace.',
    'en': 'Failed to load wallets: RLS permission. Check workspace membership.',
  },
  'w_err_load': {
    'id': 'Gagal memuat dompet. Periksa koneksi.',
    'en': 'Failed to load wallets. Check your connection.',
  },
  'wd_err': {
    'id': 'Gagal memuat riwayat. Periksa koneksi.',
    'en': 'Failed to load history. Check your connection.',
  },
  'wd_loading': {
    'id': 'Memuat riwayat dompet...',
    'en': 'Loading wallet history...',
  },
  'wd_empty_t': {
    'id': 'Belum ada transaksi di dompet ini.',
    'en': 'No transactions in this wallet yet.',
  },
  'wd_empty_s': {
    'id': 'Catat atau tunggu pelacakan otomatis mengisinya.',
    'en': 'Record some or wait for auto-tracking to fill it.',
  },
  'wd_count': {
    'id': '{n} transaksi membentuk saldo ini',
    'en': '{n} transactions make up this balance',
  },
  // Bulan panjang
  'm01': {'id': 'Januari', 'en': 'January'},
  'm02': {'id': 'Februari', 'en': 'February'},
  'm03': {'id': 'Maret', 'en': 'March'},
  'm04': {'id': 'April', 'en': 'April'},
  'm05': {'id': 'Mei', 'en': 'May'},
  'm06': {'id': 'Juni', 'en': 'June'},
  'm07': {'id': 'Juli', 'en': 'July'},
  'm08': {'id': 'Agustus', 'en': 'August'},
  'm09': {'id': 'September', 'en': 'September'},
  'm10': {'id': 'Oktober', 'en': 'October'},
  'm11': {'id': 'November', 'en': 'November'},
  'm12': {'id': 'Desember', 'en': 'December'},
  // Bulan pendek
  's01': {'id': 'Jan', 'en': 'Jan'},
  's02': {'id': 'Feb', 'en': 'Feb'},
  's03': {'id': 'Mar', 'en': 'Mar'},
  's04': {'id': 'Apr', 'en': 'Apr'},
  's05': {'id': 'Mei', 'en': 'May'},
  's06': {'id': 'Jun', 'en': 'Jun'},
  's07': {'id': 'Jul', 'en': 'Jul'},
  's08': {'id': 'Agu', 'en': 'Aug'},
  's09': {'id': 'Sep', 'en': 'Sep'},
  's10': {'id': 'Okt', 'en': 'Oct'},
  's11': {'id': 'Nov', 'en': 'Nov'},
  's12': {'id': 'Des', 'en': 'Dec'},
  // Budget
  'b_err_load': {
    'id': 'Gagal memuat budget. Periksa koneksi.',
    'en': 'Failed to load budgets. Check your connection.',
  },
  'b_err_cat': {
    'id': 'Isi nama kategori dulu.',
    'en': 'Enter a category name first.',
  },
  'b_err_limit': {
    'id': 'Batas harus angka lebih dari 0.',
    'en': 'Limit must be greater than 0.',
  },
  'b_saved': {'id': 'Budget disimpan.', 'en': 'Budget saved.'},
  'b_updated': {'id': 'Budget diperbarui.', 'en': 'Budget updated.'},
  'b_err_save': {
    'id': 'Gagal menyimpan. Periksa koneksi.',
    'en': 'Failed to save. Check your connection.',
  },
  'b_edit_title': {'id': 'Ubah budget {c}', 'en': 'Edit {c} budget'},
  'b_f_limit': {'id': 'Batas (Rp)', 'en': 'Limit'},
  'b_pin_title': {'id': 'Konfirmasi PIN', 'en': 'Confirm PIN'},
  'b_pin_body': {
    'id': 'Masukkan PIN keamanan untuk menyimpan perubahan.',
    'en': 'Enter your security PIN to save changes.',
  },
  'b_pin_wrong': {'id': 'PIN salah. Coba lagi.', 'en': 'Wrong PIN. Try again.'},
  'b_empty_t': {
    'id': 'Belum ada budget bulan ini.',
    'en': 'No budgets this month yet.',
  },
  'b_empty_s': {
    'id': 'Pasang batas pertama lewat form di bawah.',
    'en': 'Set your first limit using the form below.',
  },
  'b_empty_a': {'id': 'Isi budget', 'en': 'Fill budget'},
  'b_over': {'id': 'Lebih batas', 'en': 'Over limit'},
  'b_form_title': {'id': 'Batas baru', 'en': 'New limit'},
  'b_f_cat': {'id': 'Kategori (misal Makan)', 'en': 'Category (e.g. Food)'},
  'b_save': {'id': 'Simpan budget', 'en': 'Save budget'},
  // Laporan
  'r_err_load': {
    'id': 'Gagal memuat laporan. Periksa koneksi.',
    'en': 'Failed to load reports. Check your connection.',
  },
  'r_export_ok': {
    'id': 'File {l} siap dibagikan.',
    'en': '{l} file ready to share.',
  },
  'r_export_fail': {
    'id': 'Gagal membuat file. Coba lagi.',
    'en': 'Failed to create file. Try again.',
  },
  'r_empty_t': {
    'id': 'Belum ada transaksi untuk bulan ini.',
    'en': 'No transactions this month yet.',
  },
  'r_empty_s': {
    'id': 'Pilih bulan lain atau catat transaksi dulu.',
    'en': 'Pick another month or record a transaction first.',
  },
  'r_tx_title': {'id': 'Transaksi', 'en': 'Transactions'},
  'r_flow_all': {'id': 'Semua', 'en': 'All'},
  'r_center': {'id': 'masuk', 'en': 'in'},
  'r_hints': {
    'id': 'Kemungkinan transfer ({n})',
    'en': 'Likely transfers ({n})',
  },
  'r_noflow': {
    'id': 'Tidak ada transaksi jenis ini bulan ini.',
    'en': 'No transactions of this type this month.',
  },
  'r_dl': {'id': 'Unduh {l}', 'en': 'Download {l}'},
  // Lainnya
  'o_logout_t': {'id': 'Keluar dari akun?', 'en': 'Log out of your account?'},
  'o_logout': {'id': 'Keluar', 'en': 'Log out'},
  'o_backup_ok': {
    'id': 'File cadangan siap dibagikan.',
    'en': 'Backup file ready to share.',
  },
  'o_backup_fail': {
    'id': 'Gagal membuat cadangan. Coba lagi.',
    'en': 'Failed to create backup. Try again.',
  },
  'o_sec_workspace': {'id': 'Workspace', 'en': 'Workspace'},
  'o_switch': {'id': 'Ganti workspace', 'en': 'Switch workspace'},
  'o_invite': {'id': 'Undang anggota', 'en': 'Invite members'},
  'o_invite_s': {
    'id': 'Bagikan kode untuk gabung workspace',
    'en': 'Share a code to join the workspace',
  },
  'o_wallets': {'id': 'Dompet', 'en': 'Wallets'},
  'o_sec_tracking': {'id': 'Pelacakan', 'en': 'Tracking'},
  'o_tracking': {'id': 'Pelacakan otomatis', 'en': 'Auto-tracking'},
  'o_tracking_s': {
    'id': 'Notifikasi bank jadi transaksi',
    'en': 'Bank notifications become transactions',
  },
  'o_sec_data': {'id': 'Data', 'en': 'Data'},
  'o_backup': {'id': 'Cadangkan data', 'en': 'Back up data'},
  'o_backup_s': {
    'id': 'Ekspor seluruh workspace ke CSV',
    'en': 'Export the whole workspace to CSV',
  },
  'o_cats': {'id': 'Kategori', 'en': 'Categories'},
  'o_cats_s': {
    'id': 'Atur daftar kategori transaksi',
    'en': 'Manage transaction categories',
  },
  'c_add_hint': {'id': 'Kategori baru', 'en': 'New category'},
  'c_add': {'id': 'Tambah', 'en': 'Add'},
  'c_saved': {'id': 'Daftar kategori disimpan.', 'en': 'Category list saved.'},
  'c_min_one': {'id': 'Minimal 1 kategori.', 'en': 'At least 1 category.'},
  'c_dupe': {
    'id': 'Kategori itu sudah ada.',
    'en': 'That category already exists.',
  },
  'c_reset': {'id': 'Kembalikan bawaan', 'en': 'Reset to defaults'},
  'o_sec_display': {'id': 'Tampilan', 'en': 'Display'},
  'o_mask': {'id': 'Samarkan nominal', 'en': 'Mask amounts'},
  'o_mask_s': {
    'id': 'Sembunyikan saldo & nominal transaksi',
    'en': 'Hide balances & transaction amounts',
  },
  'o_settings_s': {
    'id': 'Bahasa, kurs, huruf, PIN',
    'en': 'Language, currency, font, PIN',
  },
  'o_sec_account': {'id': 'Akun', 'en': 'Account'},
  'o_billing': {'id': 'Billing', 'en': 'Billing'},
  'o_plan': {'id': 'Paket {p}', 'en': '{p} plan'},
  'o_pro': {'id': 'Pro', 'en': 'Pro'},
  'o_free': {'id': 'Gratis', 'en': 'Free'},
  // Kuota
  'q_ws': {
    'id': 'Paket Gratis maks {n} workspace.',
    'en': 'Free plan allows {n} workspaces max.',
  },
  'q_members': {
    'id': 'Paket Gratis maks {n} anggota per workspace.',
    'en': 'Free plan allows {n} members per workspace max.',
  },
  'q_pdf': {
    'id': 'Export PDF khusus paket Pro.',
    'en': 'PDF export is a Pro feature.',
  },
  'q_auto': {
    'id': 'Batas auto-track Gratis ({n}/bln). Naik ke Pro.',
    'en': 'Free auto-track limit ({n}/mo). Upgrade to Pro.',
  },
  'q_pro': {
    'id': 'Naik ke Pro untuk batas lebih longgar.',
    'en': 'Upgrade to Pro for higher limits.',
  },
  // Pengaturan
  'st_title': {'id': 'Pengaturan', 'en': 'Settings'},
  'st_lang': {'id': 'Bahasa', 'en': 'Language'},
  'st_currency': {'id': 'Mata uang tampilan', 'en': 'Display currency'},
  'st_fx_refresh': {'id': 'Perbarui kurs', 'en': 'Refresh rates'},
  'st_fx_ok': {'id': 'Kurs diperbarui.', 'en': 'Rates updated.'},
  'st_fx_fail': {
    'id': 'Gagal perbarui kurs. Pakai cache.',
    'en': 'Failed to refresh rates. Using cache.',
  },
  'st_fx_cache': {'id': 'Kurs per {d}', 'en': 'Rates as of {d}'},
  'st_fx_none': {
    'id': 'Belum ada kurs. IDR dipakai.',
    'en': 'No rates yet. Using IDR.',
  },
  'st_font': {'id': 'Ukuran huruf', 'en': 'Font size'},
  'st_pin': {'id': 'PIN keamanan', 'en': 'Security PIN'},
  'st_pin_send': {'id': 'Kirim kode ke email', 'en': 'Send code to email'},
  'st_pin_sent': {
    'id': 'Kode dikirim ke {e}. Cek inbox.',
    'en': 'Code sent to {e}. Check your inbox.',
  },
  'st_pin_code': {'id': 'Kode 6 digit', 'en': '6-digit code'},
  'st_pin_verify': {'id': 'Verifikasi', 'en': 'Verify'},
  'st_pin_new': {'id': 'PIN baru (6 digit)', 'en': 'New PIN (6 digits)'},
  'st_pin_new2': {'id': 'Ulangi PIN baru', 'en': 'Repeat new PIN'},
  'st_pin_save': {'id': 'Simpan PIN', 'en': 'Save PIN'},
  'st_pin_changed': {'id': 'PIN diganti.', 'en': 'PIN changed.'},
  'st_pin_mismatch': {'id': 'PIN tidak sama.', 'en': 'PINs do not match.'},
  'st_pin_short': {
    'id': 'PIN minimal 4 digit.',
    'en': 'PIN must be at least 4 digits.',
  },
  'st_pin_badcode': {
    'id': 'Kode salah. Coba lagi.',
    'en': 'Wrong code. Try again.',
  },
  'st_pin_noemail': {
    'id': 'Email user tidak ditemukan.',
    'en': 'User email not found.',
  },
  // Auth & sesi
  'sp_tagline': {
    'id': 'Simple. Secure. Reliable.\nYour Finance Space.',
    'en': 'Simple. Secure. Reliable.\nYour Finance Space.',
  },
  'sp_loading': {
    'id': 'Menyiapkan buku kas...',
    'en': 'Preparing your ledger...',
  },
  'sp_err': {
    'id': 'Gagal menyiapkan buku kas. Periksa koneksi lalu coba lagi.',
    'en': 'Failed to prepare your ledger. Check your connection and try again.',
  },
  'au_title': {'id': 'SSR SPACE', 'en': 'SSR SPACE'},
  'au_sub': {
    'id': 'Masuk untuk lanjut catat harian.',
    'en': 'Sign in to continue your daily log.',
  },
  'au_email': {'id': 'Email', 'en': 'Email'},
  'au_pass': {'id': 'Password', 'en': 'Password'},
  'au_login': {'id': 'Masuk', 'en': 'Sign in'},
  'au_register': {'id': 'Daftar', 'en': 'Sign up'},
  'au_to_register': {
    'id': 'Belum punya akun? Daftar',
    'en': "Don't have an account? Sign up",
  },
  'au_to_login': {
    'id': 'Sudah punya akun? Masuk',
    'en': 'Already have an account? Sign in',
  },
  'au_resend': {'id': 'Kirim ulang verifikasi', 'en': 'Resend verification'},
  'au_err_server': {
    'id': 'Tidak bisa menghubungi server ({h}). Cek internet / matikan VPN-adblock, lalu Coba Lagi.',
    'en': 'Cannot reach the server ({h}). Check internet / disable VPN-adblock, then Try Again.',
  },
  'au_err_net': {
    'id': 'Jaringan bermasalah. Cek internet lalu Coba Lagi.',
    'en': 'Network trouble. Check internet then Try Again.',
  },
  'au_err_unconfirmed': {
    'id': 'Email belum verifikasi. Cek inbox lalu klik link, atau kirim ulang di bawah.',
    'en': 'Email not verified. Check your inbox and click the link, or resend below.',
  },
  'au_err_empty': {
    'id': 'Masuk gagal, sesi kosong. Kalau baru daftar, verifikasi email dulu.',
    'en': 'Sign-in failed, empty session. If you just registered, verify your email first.',
  },
  'au_created': {
    'id': 'Akun dibuat. Cek email, klik link verifikasi, lalu Masuk.',
    'en': 'Account created. Check your email, click the verification link, then Sign in.',
  },
  'au_resent': {
    'id': 'Link verifikasi dikirim ulang. Cek inbox/spam.',
    'en': 'Verification link resent. Check inbox/spam.',
  },
  'au_try_again': {'id': 'Coba Lagi', 'en': 'Try Again'},
  'lk_lockout': {
    'id': 'Terlalu banyak salah. Tunggu 60 detik lalu coba lagi.',
    'en': 'Too many attempts. Wait 60 seconds then try again.',
  },
  'lk_wrong': {'id': 'PIN salah. Coba lagi.', 'en': 'Wrong PIN. Try again.'},
  'lk_title': {'id': 'Terkunci', 'en': 'Locked'},
  'lk_sub': {
    'id': 'Masukkan PIN untuk buka sesi',
    'en': 'Enter your PIN to unlock',
  },
  'lk_open': {'id': 'Buka', 'en': 'Unlock'},
  'ob_name_err': {'id': 'Nama wajib diisi.', 'en': 'Name is required.'},
  'ob_pin_err': {
    'id': 'PIN minimal 4 digit.',
    'en': 'PIN must be at least 4 digits.',
  },
  'ob_pin2_err': {'id': 'PIN tidak sama.', 'en': 'PINs do not match.'},
  'ob_welcome': {
    'id': 'Selamat datang di SSR SPACE',
    'en': 'Welcome to SSR SPACE',
  },
  'ob_sub': {
    'id': 'Isi profil lalu buat PIN untuk mulai mencatat.',
    'en': 'Fill your profile then create a PIN to start recording.',
  },
  'ob_profile': {'id': 'Profil', 'en': 'Profile'},
  'ob_name': {'id': 'Nama', 'en': 'Name'},
  'ob_pin': {'id': 'PIN keamanan (6 digit)', 'en': 'Security PIN (6 digits)'},
  'ob_start': {'id': 'Mulai', 'en': 'Start'},
  // Intro
  'in_brand_sub': {
    'id': 'Buku kas harian yang tenang, rapi, dan bisa dipercaya.',
    'en': 'A calm, tidy, trustworthy daily ledger.',
  },
  'in_values_t': {
    'id': 'Semua urusan uang, satu ruang',
    'en': 'All money matters, one space',
  },
  'in_values_s': {
    'id': 'Tiga hal yang bikin catatan harian terasa ringan.',
    'en': 'Three things that make daily logging feel light.',
  },
  'in_auto_t': {
    'id': 'Catatan otomatis dari notifikasi',
    'en': 'Automatic notes from notifications',
  },
  'in_auto_s': {
    'id': 'Notifikasi bank dan e-wallet terbaca jadi transaksi. Kamu tinggal cek, bukan ketik ulang.',
    'en': 'Bank and e-wallet notifications turn into transactions. You just review, not retype.',
  },
  'in_wallets_t': {'id': 'Dompet multi', 'en': 'Multiple wallets'},
  'in_wallets_s': {
    'id': 'Kas, bank, dan e-wallet. Tiap dompet punya saldo sendiri, semuanya rapi dalam satu buku kas.',
    'en': 'Cash, banks, and e-wallets. Each wallet has its own balance, all tidy in one ledger.',
  },
  'in_org_t': {'id': 'Workspace bersama', 'en': 'Shared workspace'},
  'in_org_s': {
    'id': 'Satu buku kas bisa dipakai bareng pasangan atau tim, lewat undangan aman.',
    'en': 'One ledger can be shared with a partner or team via secure invites.',
  },
  'in_mind_t': {
    'id': 'Kelola keuangan dengan sadar',
    'en': 'Manage money mindfully',
  },
  'in_mind_s1': {
    'id': 'SSR SPACE mencatat, kamu yang memutuskan.',
    'en': 'SSR SPACE records, you decide.',
  },
  'in_mind_s2': {
    'id': 'Aplikasi ini membantu kamu melihat ke mana uangmu pergi. Setiap angka berasal dari catatanmu sendiri, jadi keputusan tetap di tanganmu. Data yang jujur hari ini jadi laporan yang akurat bulan depan.',
    'en': 'This app helps you see where your money goes. Every figure comes from your own records, so decisions stay yours. Honest data today becomes accurate reports next month.',
  },
  'in_terms_t': {'id': 'Syarat & persetujuan', 'en': 'Terms & consent'},
  'in_terms_s': {
    'id': 'Baca sekali, setujui untuk mulai mencatat.',
    'en': 'Read once, agree to start recording.',
  },
  'in_agree': {'id': 'Saya paham dan setuju', 'en': 'I understand and agree'},
  'in_go': {'id': 'Setuju & mulai', 'en': 'Agree & start'},
  'in_next': {'id': 'Lanjut', 'en': 'Next'},
  'in_save_fail': {
    'id': 'Gagal menyimpan persetujuan. Coba lagi.',
    'en': 'Failed to save consent. Try again.',
  },
  'in_term_1': {
    'id': 'SSR SPACE alat pencatat. Tanggung jawab keputusan keuangan tetap di tanganmu.',
    'en': 'SSR SPACE is a recording tool. Financial decisions remain your responsibility.',
  },
  'in_term_2': {
    'id': 'Data disimpan aman di cloud dan hanya bisa diakses dalam workspace-mu.',
    'en': 'Data is stored securely in the cloud and only accessible within your workspace.',
  },
  'in_term_3': {
    'id': 'Pelacakan otomatis butuh izin akses notifikasi. Kamu bisa mematikannya kapan saja.',
    'en':
        'Auto-tracking needs notification access. You can turn it off anytime.',
  },
  'in_term_4': {
    'id': 'PIN dan password adalah tanggung jawabmu. Jangan dibagikan ke siapa pun.',
    'en': 'Your PIN and password are your responsibility. Never share them.',
  },
  'in_term_5': {
    'id': 'Aplikasi ini bukan nasihat keuangan atau kebijakan investasi.',
    'en': 'This app is not financial advice or investment policy.',
  },
  'tx_nocode': {'id': 'Tanpa kode', 'en': 'No code'},
  // PDF
  'pdf_title': {'id': 'Laporan Keuangan', 'en': 'Financial Report'},
  'pdf_made': {'id': 'Dibuat {d}', 'en': 'Generated {d}'},
  'pdf_page': {'id': 'Halaman {p} dari {t}', 'en': 'Page {p} of {t}'},
  'pdf_txs': {'id': 'Transaksi ({n})', 'en': 'Transactions ({n})'},
  'pdf_empty': {
    'id': 'Belum ada transaksi bulan ini.',
    'en': 'No transactions this month.',
  },
  'pdf_cats': {'id': 'Keluar per kategori', 'en': 'Expenses by category'},
  'pdf_diff': {'id': 'Selisih', 'en': 'Net'},
  // Billing
  'bl_err_load': {
    'id': 'Gagal memuat paket. Periksa koneksi.',
    'en': 'Failed to load plan. Check your connection.',
  },
  'bl_req_ok': {
    'id': 'Permintaan Pro tercatat. Aktivasi menyusul setelah pembayaran terkonfirmasi.',
    'en':
        'Pro request recorded. Activation follows after payment confirmation.',
  },
  'bl_req_fail': {
    'id': 'Gagal mengirim permintaan. Coba lagi nanti.',
    'en': 'Failed to send request. Try again later.',
  },
  'bl_loading': {'id': 'Memuat paket...', 'en': 'Loading plan...'},
  'bl_active': {'id': 'Paket aktif: {p}', 'en': 'Active plan: {p}'},
  'bl_free': {'id': 'Gratis', 'en': 'Free'},
  'bl_pro': {'id': 'Pro', 'en': 'Pro'},
  'bl_active_chip': {'id': 'Paket aktif', 'en': 'Active plan'},
  'bl_upgrade_chip': {'id': 'Upgrade', 'en': 'Upgrade'},
  'bl_f_free1': {'id': 'Catat transaksi', 'en': 'Record transactions'},
  'bl_f_free2': {'id': '{n} workspace', 'en': '{n} workspaces'},
  'bl_f_pro1': {'id': 'Workspace banyak', 'en': 'Many workspaces'},
  'bl_f_pro2': {'id': 'Export laporan', 'en': 'Report export'},
  'bl_f_pro3': {'id': 'Tanpa batas', 'en': 'No limits'},
  'bl_sent': {'id': 'Permintaan terkirim', 'en': 'Request sent'},
  'bl_failed': {'id': 'Gagal', 'en': 'Failed'},
  'bl_cta': {'id': 'Naik ke Pro', 'en': 'Upgrade to Pro'},
  // Undang anggota
  'iv_err_create': {
    'id': 'Gagal membuat undangan. Coba lagi.',
    'en': 'Failed to create invite. Try again.',
  },
  'iv_code': {'id': 'Kode undangan', 'en': 'Invite code'},
  'iv_copied': {'id': 'Kode disalin.', 'en': 'Code copied.'},
  'iv_copy': {'id': 'Salin', 'en': 'Copy'},
  'iv_share': {'id': 'Bagikan', 'en': 'Share'},
  'iv_done': {'id': 'Selesai', 'en': 'Done'},
  'iv_revoke_t': {'id': 'Cabut undangan?', 'en': 'Revoke invite?'},
  'iv_revoke_b': {
    'id': 'Kode yang sudah dicabut tidak bisa dipakai lagi.',
    'en': 'A revoked code cannot be used anymore.',
  },
  'iv_revoke': {'id': 'Cabut', 'en': 'Revoke'},
  'iv_revoke_fail': {
    'id': 'Gagal mencabut. Coba lagi.',
    'en': 'Failed to revoke. Try again.',
  },
  'iv_noorg_t': {'id': 'Belum ada workspace.', 'en': 'No workspace yet.'},
  'iv_noorg_s': {
    'id': 'Pilih atau buat workspace dulu untuk mengundang.',
    'en': 'Choose or create a workspace first to invite.',
  },
  'iv_notadmin_t': {
    'id': 'Hanya admin workspace yang bisa mengundang anggota.',
    'en': 'Only workspace admins can invite members.',
  },
  'iv_notadmin_s': {
    'id': 'Minta owner atau admin membuat kode undangan.',
    'en': 'Ask an owner or admin to create an invite code.',
  },
  'iv_role': {'id': 'Peran anggota', 'en': 'Member role'},
  'iv_member': {'id': 'Anggota', 'en': 'Member'},
  'iv_admin': {'id': 'Admin', 'en': 'Admin'},
  'iv_create': {'id': 'Buat undangan', 'en': 'Create invite'},
  'iv_st_active': {'id': 'Aktif', 'en': 'Active'},
  'iv_st_used': {'id': 'Habis', 'en': 'Used up'},
  'iv_st_revoked': {'id': 'Dicabut', 'en': 'Revoked'},
  'iv_st_expired': {'id': 'Kedaluwarsa', 'en': 'Expired'},
  'iv_expired': {
    'id': 'Kode undangan kedaluwarsa.',
    'en': 'Invite code expired.',
  },
  'iv_exhausted': {
    'id': 'Kode undangan sudah habis.',
    'en': 'Invite code is used up.',
  },
  'iv_invalid': {
    'id': 'Kode undangan tidak valid.',
    'en': 'Invalid invite code.',
  },
  'iv_needlogin': {
    'id': 'Masuk dulu ke aplikasi.',
    'en': 'Sign in to the app first.',
  },
  'iv_joinfail': {
    'id': 'Gagal bergabung. Coba lagi.',
    'en': 'Failed to join. Try again.',
  },
  'iv_adminonly': {
    'id': 'Hanya admin workspace yang bisa mengundang.',
    'en': 'Only workspace admins can invite.',
  },
  // Pilih workspace
  'org_err_load': {
    'id': 'Gagal memuat workspace. Periksa koneksi lalu coba lagi.',
    'en': 'Failed to load workspaces. Check your connection and try again.',
  },
  'org_err_name': {
    'id': 'Nama workspace wajib diisi.',
    'en': 'Workspace name is required.',
  },
  'org_err_create': {
    'id': 'Gagal membuat workspace. Periksa nama dan koneksi.',
    'en': 'Failed to create workspace. Check the name and connection.',
  },
  'org_err_code': {
    'id': 'Tempel kode undangan dulu.',
    'en': 'Paste an invite code first.',
  },
  'org_joined': {
    'id': 'Berhasil bergabung ke workspace.',
    'en': 'Joined the workspace.',
  },
  'org_err_join': {
    'id': 'Gagal bergabung. Periksa koneksi.',
    'en': 'Failed to join. Check your connection.',
  },
  'org_loading': {'id': 'Memuat workspace...', 'en': 'Loading workspaces...'},
  'org_title': {'id': 'Pilih workspace', 'en': 'Choose workspace'},
  'org_pick': {
    'id': 'Pilih ruang catat atau buat baru.',
    'en': 'Pick a ledger or create a new one.',
  },
  'org_empty_t': {'id': 'Belum ada workspace.', 'en': 'No workspaces yet.'},
  'org_empty_s': {
    'id': 'Buat workspace pertama di bawah untuk mulai mencatat.',
    'en': 'Create your first workspace below to start recording.',
  },
  'org_empty_a': {'id': 'Buat workspace', 'en': 'Create workspace'},
  'org_owner': {'id': 'Pemilik', 'en': 'Owner'},
  'org_member': {'id': 'Anggota', 'en': 'Member'},
  'org_new': {'id': 'Buat workspace baru', 'en': 'Create new workspace'},
  'org_f_name': {'id': 'Nama workspace', 'en': 'Workspace name'},
  'org_create': {'id': 'Buat', 'en': 'Create'},
  'org_f_code': {'id': 'Kode undangan', 'en': 'Invite code'},
  'org_join': {'id': 'Gabung', 'en': 'Join'},
  // Pelacakan otomatis
  'nt_title': {'id': 'Pelacakan otomatis', 'en': 'Auto-tracking'},
  'nt_sub': {
    'id': 'Mati = tidak ada yang dicatat',
    'en': 'Off = nothing is recorded',
  },
  'nt_card_status': {'id': 'Status pelacakan', 'en': 'Tracking status'},
  'nt_on': {'id': 'Menyala', 'en': 'On'},
  'nt_off': {'id': 'Mati', 'en': 'Off'},
  'nt_active': {'id': 'Aktif', 'en': 'Active'},
  'nt_bg': {'id': 'Pemantauan latar', 'en': 'Background monitoring'},
  'nt_bg_on': {
    'id': 'Transaksi tetap tercatat walau app ditutup',
    'en': 'Transactions keep recording even with the app closed',
  },
  'nt_bg_off': {
    'id': 'Buka app agar pelacakan berjalan',
    'en': 'Open the app to keep tracking running',
  },
  'nt_perm': {'id': 'Izin baca notifikasi', 'en': 'Notification access'},
  'nt_notready': {'id': 'Belum siap', 'en': 'Not ready'},
  'nt_notactive': {'id': 'Belum aktif', 'en': 'Not active'},
  'nt_recheck': {'id': 'Cek lagi', 'en': 'Check again'},
  'nt_enable': {'id': 'Aktifkan', 'en': 'Enable'},
  'nt_svc': {'id': 'Service listener', 'en': 'Listener service'},
  'nt_reconnect': {'id': 'Sambung', 'en': 'Reconnect'},
  'nt_conn': {'id': 'Terhubung', 'en': 'Connected'},
  'nt_disconn': {'id': 'Terputus', 'en': 'Disconnected'},
  'nt_banks': {'id': 'Bank & dompet', 'en': 'Banks & wallets'},
  'nt_wallet_unset': {'id': 'belum cocok', 'en': 'not matched'},
  'nt_wallet': {'id': 'Dompet: {w}', 'en': 'Wallet: {w}'},
  'nt_cat': {'id': 'Kategori: {c}', 'en': 'Category: {c}'},
  'nt_nowallet': {
    'id': 'Belum ada dompet. Buat dulu di menu Lainnya, lalu Dompet, lalu petakan di sini.',
    'en': 'No wallets yet. Create one under More, then Wallets, then map it here.',
  },
  'nt_scan_hint': {
    'id': 'Pindai notifikasi yang masih ada di panel HP.',
    'en': 'Scan notifications still present in the phone shade.',
  },
  'nt_scanning': {'id': 'Memindai...', 'en': 'Scanning...'},
  'nt_scan': {
    'id': 'Pindai notifikasi aktif sekarang',
    'en': 'Scan active notifications now',
  },
  'nt_recent_none': {
    'id': 'Belum ada notifikasi keuangan tertangkap sesi ini.',
    'en': 'No financial notifications caught this session yet.',
  },
  'nt_save': {'id': 'Simpan', 'en': 'Save'},
  'nt_saving': {'id': 'Simpan...', 'en': 'Saving...'},
  'nt_in': {'id': 'Masuk (pemasukan)', 'en': 'Income'},
  'nt_out': {'id': 'Keluar (pengeluaran)', 'en': 'Expense'},
  'nt_type_t': {
    'id': 'Jenis transaksi untuk {a}',
    'en': 'Transaction type for {a}',
  },
  'bt_wallet': {'id': 'Masuk ke dompet', 'en': 'Into wallet'},
  'bt_auto': {'id': 'Otomatis / ikut nama', 'en': 'Automatic / match name'},
  'bt_cat': {'id': 'Kategori', 'en': 'Category'},
  // Status service pelacakan
  'svc_scan_unavail': {
    'id': 'Service listener tidak nyambung. Izin aktif tapi service mati.',
    'en': 'Listener service not connected. Permission is on but the service is dead.',
  },
  'svc_rebind': {
    'id': 'Gagal sambung ulang service listener',
    'en': 'Failed to rebind the listener service',
  },
  'svc_apilevel': {
    'id': 'Perangkat terlalu lama untuk sambung ulang otomatis',
    'en': 'Device too old for automatic rebind',
  },
  'svc_scanfail': {'id': 'Gagal memindai: {m}', 'en': 'Scan failed: {m}'},
  'svc_noperm': {
    'id': 'Izin baca notifikasi belum aktif',
    'en': 'Notification access is not enabled',
  },
  'svc_disconnected': {
    'id': 'Izin aktif, service terputus. Pindai untuk sambung ulang.',
    'en': 'Permission on, service disconnected. Scan to reconnect.',
  },
  'svc_connected': {'id': 'Service terhubung', 'en': 'Service connected'},
  'svc_rate': {
    'id': 'Dibatasi, terlalu banyak. Coba lagi.',
    'en': 'Rate limited, too many. Try again.',
  },
  'svc_dup': {'id': 'Sudah pernah dicatat', 'en': 'Already recorded'},
  'svc_savefail': {'id': 'Gagal simpan: {c}', 'en': 'Save failed: {c}'},
  'svc_notandroid': {'id': 'Bukan Android', 'en': 'Not Android'},
  'svc_scan_active_none': {
    'id': 'Tidak ada notifikasi aktif di shade',
    'en': 'No active notifications in the shade',
  },
  'svc_scan_found': {
    'id': 'Memindai {n} notifikasi aktif',
    'en': 'Scanning {n} active notifications',
  },
  'svc_scan_fail': {
    'id': 'Gagal memindai notifikasi aktif',
    'en': 'Failed to scan active notifications',
  },
  'st_notwatched': {'id': 'Bukan app terpantau', 'en': 'Not a watched app'},
  'st_masteroff': {
    'id': 'Master pelacakan mati',
    'en': 'Tracking master is off',
  },
  'st_toggleoff': {'id': 'Toggle {a} mati', 'en': '{a} toggle is off'},
  'st_nologin': {
    'id': 'Belum masuk di aplikasi',
    'en': 'Not signed in to the app',
  },
  'st_noorg': {'id': 'Workspace belum dipilih', 'en': 'No workspace selected'},
  'st_unread': {
    'id': 'Nominal atau jenis tidak terbaca',
    'en': 'Amount or type unreadable',
  },
  'st_saved_nowallet': {
    'id': 'Tersimpan (dompet belum cocok)',
    'en': 'Saved (wallet not matched)',
  },
  'st_saved': {'id': 'Tersimpan', 'en': 'Saved'},
  'nt_auto_from': {'id': 'Otomatis dari {a}', 'en': 'Auto from {a}'},
  'fg_notandroid': {'id': 'Bukan Android', 'en': 'Not Android'},
  'fg_off': {'id': 'Pelacakan mati', 'en': 'Tracking off'},
  'fg_nologin': {'id': 'Belum masuk', 'en': 'Not signed in'},
  'nt_lastseen': {'id': 'Terakhir terlihat', 'en': 'Last seen'},
  'nt_skipped': {'id': 'Melewati filter', 'en': 'Skipped by filters'},
  'iv_remaining': {'id': 'sisa pemakaian {n}', 'en': '{n} uses left'},
  'iv_unrevoke': {'id': 'Cabut undangan', 'en': 'Revoke invite'},
  'mt_show': {'id': 'Tampilkan nominal', 'en': 'Show amounts'},
  'mp_prev': {'id': 'Bulan lalu', 'en': 'Previous month'},
  'mp_next': {'id': 'Bulan depan', 'en': 'Next month'},
  'tx_auto': {'id': 'Otomatis', 'en': 'Auto'},
  'cat_other': {'id': 'Lainnya', 'en': 'Other'},
  'iv_err_load': {
    'id': 'Gagal memuat undangan. Periksa koneksi.',
    'en': 'Failed to load invites. Check your connection.',
  },
  'iv_share_once': {
    'id': 'Bagikan kode ini sekali. Kode tidak bisa dilihat lagi setelah dialog ditutup.',
    'en': 'Share this code once. It cannot be viewed again after the dialog closes.',
  },
  'iv_share_hint': {
    'id': 'Bagikan kode agar anggota lain bisa masuk ke buku kas ini.',
    'en': 'Share the code so other members can join this ledger.',
  },
  'iv_list_empty': {
    'id':
        'Belum ada undangan aktif. Buat kode di atas untuk mengundang anggota.',
    'en': 'No active invites. Create a code above to invite members.',
  },
  'iv_share_text': {
    'id': 'Gabung workspace di SSR SPACE dengan kode: {c}',
    'en': 'Join the SSR SPACE workspace with code: {c}',
  },
  'r_share_csv': {
    'id': 'Laporan SSR SPACE (CSV)',
    'en': 'SSR SPACE report (CSV)',
  },
  'r_share_pdf': {
    'id': 'Laporan SSR SPACE (PDF)',
    'en': 'SSR SPACE report (PDF)',
  },
  // Koreksi instan
  'fg_correct': {
    'id': '{s} • ketuk untuk lengkapi',
    'en': '{s} • tap to complete',
  },
  'ic_title': {'id': 'Koreksi instan', 'en': 'Instant correction'},
  'ic_popup': {'id': 'Popup koreksi instan', 'en': 'Instant correction popup'},
  'ic_popup_s': {
    'id': 'Ringkasan 30 detik setelah auto-catat',
    'en': '30-second summary after auto-save',
  },
  'ic_perm': {
    'id': 'Izin tampil di atas aplikasi',
    'en': 'Display over apps permission',
  },
  'ic_perm_grant': {'id': 'Beri izin', 'en': 'Grant permission'},
  'ic_perm_ok': {'id': 'Izin overlay aktif', 'en': 'Overlay permission active'},
  'ic_overlay_t': {'id': 'Transaksi tercatat', 'en': 'Transaction saved'},
  'ic_lengkapi': {'id': 'Lengkapi', 'en': 'Complete'},
  'ic_tutup': {'id': 'Tutup', 'en': 'Close'},
  'ic_sheet_t': {'id': 'Lengkapi catatan', 'en': 'Complete entry'},
  'ic_note_hint': {
    'id': 'Catatan singkat (opsional)',
    'en': 'Short note (optional)',
  },
  'ic_skip': {'id': 'Lewati', 'en': 'Skip'},
  'ic_saved': {'id': 'Koreksi tersimpan.', 'en': 'Correction saved.'},
};

String tr(String key) => _t[key]?[localeCode.value] ?? _t[key]?['id'] ?? key;
