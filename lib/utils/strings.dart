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
  'clear': {'id': 'Bersihkan', 'en': 'Clear'},
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
  'nav_profil': {'id': 'Profil', 'en': 'Profile'},
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
    'id': 'Catat pemasukan atau pengeluaran lewat tombol +.',
    'en': 'Record income or expenses with the + button.',
  },
  'tx_empty_a': {'id': 'Catat sekarang', 'en': 'Record now'},
  'tx_f_date': {'id': 'Tanggal', 'en': 'Date'},
  'tx_add_time': {'id': 'Tambah jam', 'en': 'Add time'},
  'tx_cancel_edit': {'id': 'Batalkan edit', 'en': 'Cancel editing'},
  'tx_f_nominal': {'id': 'Nominal', 'en': 'Amount'},
  'tx_f_cat': {'id': 'Kategori (misal Makan)', 'en': 'Category (e.g. Food)'},
  'tx_f_note': {'id': 'Catatan', 'en': 'Note'},
  'tx_f_wallet': {'id': 'Dompet', 'en': 'Wallet'},
  'tx_f_towallet': {'id': 'Dompet tujuan', 'en': 'Destination wallet'},
  'tx_towallet_help': {
    'id': 'Penerima, harus beda dari dompet asal',
    'en': 'Recipient, must differ from the source wallet',
  },
  'tx_date_hint': {
    'id': 'Default hari ini, ketuk tanggal untuk ubah',
    'en': 'Defaults to today, tap the date to change',
  },
  'tx_save_edit': {'id': 'Simpan perubahan', 'en': 'Save changes'},
  'tx_save_add': {'id': 'Simpan transaksi', 'en': 'Save transaction'},
  // Wizard catat 2 langkah + scan struk
  'wiz_type_cat': {'id': 'Jenis dan kategori', 'en': 'Type and category'},
  'wiz_need_cat': {'id': 'Pilih kategori dulu', 'en': 'Choose a category first'},
  'wiz_next': {'id': 'Lanjut', 'en': 'Continue'},
  'wiz_back': {'id': 'Kembali', 'en': 'Back'},
  'wiz_change': {'id': 'Ubah', 'en': 'Change'},
  'wiz_step1': {
    'id': 'Langkah 1 · Jenis dan kategori',
    'en': 'Step 1 · Type and category',
  },
  'wiz_step2': {
    'id': 'Langkah 2 · Isi detail',
    'en': 'Step 2 · Fill in the details',
  },
  'rcp_scan': {'id': 'Scan struk', 'en': 'Scan receipt'},
  'rcp_scan_hint': {
    'id': 'Foto struk belanja, hasilnya mengisi form.',
    'en': 'Photograph a shopping receipt, the result fills the form.',
  },
  'rcp_camera': {'id': 'Kamera', 'en': 'Camera'},
  'rcp_gallery': {'id': 'Galeri', 'en': 'Gallery'},
  'rcp_scanning': {'id': 'Membaca struk...', 'en': 'Reading receipt...'},
  'rcp_fail': {
    'id': 'Struk tak terbaca. Isi manual atau foto ulang.',
    'en': 'Receipt unreadable. Fill manually or retake the photo.',
  },
  'rcp_partial': {
    'id': 'Sebagian tak terbaca, periksa lagi sebelum simpan.',
    'en': 'Partially unreadable, check again before saving.',
  },
  'rcp_empty': {
    'id': 'Tak ada teks di foto ini.',
    'en': 'No text found in this photo.',
  },
  'rcp_raw_title': {
    'id': 'Teks OCR mentah (diagnosis)',
    'en': 'Raw OCR text (diagnostics)',
  },
  'rcp_raw_empty': {
    'id': '(kosong — kamera tak membaca teks apa pun)',
    'en': '(empty — no text was read)',
  },
  'rcp_raw_close': {'id': 'Tutup', 'en': 'Close'},
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
  'w_savings': {'id': 'Tabungan', 'en': 'Savings'},
  'w_investment': {'id': 'Investasi', 'en': 'Investment'},
  'comp_title': {'id': 'Komposisi aset', 'en': 'Asset mix'},
  'comp_sub': {'id': 'Posisi saldo per kelompok', 'en': 'Balance by group'},
  'comp_liquid': {'id': 'Likuid', 'en': 'Liquid'},
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
  // Kelompok hari
  'day_no_date': {'id': 'Tanpa tanggal', 'en': 'No date'},
  'day_count': {'id': '{n} transaksi', 'en': '{n} transactions'},
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
  'b_err_warn': {
    'id': 'Peringatan harus angka 1–100.',
    'en': 'Warning must be a number 1–100.',
  },
  'b_saved': {'id': 'Budget disimpan.', 'en': 'Budget saved.'},
  'b_updated': {'id': 'Budget diperbarui.', 'en': 'Budget updated.'},
  'b_err_save': {
    'id': 'Gagal menyimpan. Periksa koneksi.',
    'en': 'Failed to save. Check your connection.',
  },
  'b_edit_title': {'id': 'Ubah budget {c}', 'en': 'Edit {c} budget'},
  'b_f_limit': {'id': 'Batas (Rp)', 'en': 'Limit'},
  'b_f_warn': {'id': 'Peringatan (%)', 'en': 'Warning (%)'},
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
  'b_delete': {'id': 'Hapus', 'en': 'Delete'},
  'b_deleted': {'id': 'Budget dihapus.', 'en': 'Budget deleted.'},
  'b_del_title': {'id': 'Hapus budget {c}', 'en': 'Delete {c} budget'},
  'b_del_body': {
    'id': 'Hapus budget {c} bulan ini? Transaksi tetap ada.',
    'en': 'Delete the {c} budget for this month? Transactions stay.',
  },
  'b_over_alloc': {
    'id': 'Total limit melebihi pemasukan bulan ini.',
    'en': "Total limits exceed this month's income.",
  },
  // Budget alerts: banner + badge (trigger server Task 1)
  'ba_title': {'id': 'Peringatan budget', 'en': 'Budget alerts'},
  'ba_warn': {'id': 'Mendekati batas', 'en': 'Nearing the limit'},
  'ba_breach': {'id': 'Melewati batas', 'en': 'Over the limit'},
  // Tabungan (konvensi kategori, tanpa tabel baru)
  'sv_label': {'id': 'Tabungan', 'en': 'Savings'},
  'sv_of': {'id': 'dari', 'en': 'of'},
  'sv_done': {'id': 'Tercapai', 'en': 'Reached'},
  'sv_wallet_line': {
    'id': 'Ditabung {a} · {n} transaksi',
    'en': 'Saved {a} · {n} transactions',
  },
  'sv_only': {'id': 'Hanya tabungan', 'en': 'Only savings'},
  'sv_pace_need': {
    'id': 'Butuh {m}/hari agar tercapai',
    'en': 'Needs {m}/day to reach it',
  },
  'sv_pace_track': {
    'id': 'Di jalur, proyeksi {m}',
    'en': 'On track, projected {m}',
  },
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
  'r_filter_all': {'id': 'Semua dompet', 'en': 'All wallets'},
  'r_filter_wallet': {'id': 'Dompet', 'en': 'Wallet'},
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
  // Laporan: rekap kategori Top-8 + Others + susun section (P2)
  'r_recap': {'id': 'Rekap kategori', 'en': 'Category recap'},
  'r_others': {'id': 'Lainnya ({n})', 'en': 'Other ({n})'},
  'r_collapse': {'id': 'Sederhanakan', 'en': 'Show less'},
  'r_arrange': {'id': 'Susun', 'en': 'Arrange'},
  'r_arrange_done': {'id': 'Selesai', 'en': 'Done'},
  'r_arrange_hint': {
    'id': 'Ketuk panah untuk menyusun urutan seksi.',
    'en': 'Tap the arrows to arrange section order.',
  },
  'r_arrange_up': {'id': 'Naikkan seksi', 'en': 'Move section up'},
  'r_arrange_down': {'id': 'Turunkan seksi', 'en': 'Move section down'},
  // Tagihan rutin (P2 recurring-bills, saran bukan insert otomatis)
  'rb_title': {'id': 'Tagihan rutin', 'en': 'Recurring bills'},
  'rb_empty_t': {
    'id': 'Belum ada tagihan rutin',
    'en': 'No recurring bills yet',
  },
  'rb_empty_s': {
    'id': 'Tambahkan kos, langganan, atau cicilan agar tak lupa dicatat.',
    'en': 'Add rent, subscriptions, or installments so you never miss one.',
  },
  'rb_add': {'id': 'Tambah tagihan', 'en': 'Add bill'},
  'rb_label': {'id': 'Nama tagihan', 'en': 'Bill name'},
  'rb_amount': {'id': 'Nominal', 'en': 'Amount'},
  'rb_weekly': {'id': 'Mingguan', 'en': 'Weekly'},
  'rb_monthly': {'id': 'Bulanan', 'en': 'Monthly'},
  'rb_anchor': {'id': 'Tanggal tiap bulan', 'en': 'Day each month'},
  'rb_next': {'id': 'Jatuh tempo berikut', 'en': 'Next due'},
  'rb_due_t': {'id': 'Jatuh tempo', 'en': 'Due'},
  'rb_record': {'id': 'Catat', 'en': 'Record'},
  'rb_skip': {'id': 'Lewati', 'en': 'Skip'},
  'rb_wallet_gone': {
    'id': 'Dompet tagihan ini sudah dihapus. Aktifkan lagi setelah pilih dompet baru.',
    'en': 'This bill\'s wallet was deleted. Re-enable it after picking a new wallet.',
  },
  'rb_paid': {'id': 'Terbayar {n}x', 'en': 'Paid {n}x'},
  'rb_history': {'id': 'Riwayat bayar', 'en': 'Payment history'},
  'rb_history_empty': {
    'id': 'Belum ada pembayaran tercatat.',
    'en': 'No payments recorded yet.',
  },
  'rb_del_t': {'id': 'Hapus tagihan', 'en': 'Delete bill'},
  'rb_del_s': {
    'id': 'Hapus tagihan ini? Riwayat transaksi tetap ada.',
    'en': 'Delete this bill? Transaction history stays.',
  },
  // Pelacak langganan (Batch 11, pola lokal tanpa server)
  'sub_title': {'id': 'Langganan terdeteksi', 'en': 'Detected subscriptions'},
  'sub_sub': {
    'id': 'Pola bayar berulang dari riwayatmu.',
    'en': 'Recurring payment patterns from your history.',
  },
  'sub_empty_t': {
    'id': 'Belum ada pola langganan',
    'en': 'No subscription patterns yet',
  },
  'sub_empty_s': {
    'id': 'Butuh minimal 2 pembayaran sama (nama + nominal) berjarak sekitar sebulan.',
    'en': 'Needs at least 2 matching payments (name + amount) about a month apart.',
  },
  'sub_total': {'id': 'Total per bulan', 'en': 'Total per month'},
  'sub_count': {'id': '{n} langganan', 'en': '{n} subscriptions'},
  'sub_sure': {'id': 'Pasti', 'en': 'Certain'},
  'sub_maybe': {'id': 'Mungkin', 'en': 'Likely'},
  'sub_new': {'id': 'Baru', 'en': 'New'},
  'sub_auto': {'id': 'Otomatis', 'en': 'Auto'},
  'sub_every': {'id': 'tiap {n} hari', 'en': 'every {n} days'},
  'sub_last': {'id': 'Terakhir {d}', 'en': 'Last {d}'},
  'sub_make': {'id': 'Jadikan tagihan', 'en': 'Make a bill'},
  'sub_made': {
    'id': 'Tersimpan jadi tagihan rutin',
    'en': 'Saved as a recurring bill',
  },
  'sub_ignore': {'id': 'Abaikan', 'en': 'Ignore'},
  'sub_unignore': {'id': 'Batal abaikan', 'en': 'Unignore'},
  'sub_show_ignored': {
    'id': 'Tampilkan yang diabaikan ({n})',
    'en': 'Show ignored ({n})',
  },
  'sub_hide_ignored': {
    'id': 'Sembunyikan yang diabaikan',
    'en': 'Hide ignored',
  },
  'sub_full': {
    'id': 'Tagihan rutin penuh (30). Hapus yang tak dipakai dulu.',
    'en': 'Recurring bills are full (30). Delete an unused one first.',
  },
  // Patungan (Batch 12, simpan prefs lokal, lunas = status)
  'bs_title': {'id': 'Patungan', 'en': 'Bill splits'},
  'bs_sub': {
    'id': 'Bagi tagihan ke anggota workspace.',
    'en': 'Split bills with workspace members.',
  },
  'bs_empty_t': {'id': 'Belum ada patungan', 'en': 'No bill splits yet'},
  'bs_empty_s': {
    'id': 'Pilih transaksi lalu bagi rata atau custom ke anggota.',
    'en': 'Pick a transaction, then split it equally or custom.',
  },
  'bs_new': {'id': 'Patungan baru', 'en': 'New split'},
  'bs_pick_tx': {'id': 'Pilih transaksi', 'en': 'Pick a transaction'},
  'bs_tx_title': {'id': 'Judul', 'en': 'Title'},
  'bs_members': {'id': 'Peserta', 'en': 'Participants'},
  'bs_payer': {'id': 'Dibayar dulu oleh', 'en': 'Paid first by'},
  'bs_equal': {'id': 'Rata', 'en': 'Equal'},
  'bs_custom': {'id': 'Custom', 'en': 'Custom'},
  'bs_next': {'id': 'Lanjut', 'en': 'Next'},
  'bs_save': {'id': 'Simpan patungan', 'en': 'Save split'},
  'bs_need_two': {
    'id': 'Pilih minimal 2 peserta.',
    'en': 'Pick at least 2 participants.',
  },
  'bs_err_number': {
    'id': 'Isi semua porsi dengan angka.',
    'en': 'Fill every share with a number.',
  },
  'bs_err_mismatch': {
    'id': 'Jumlah porsi harus pas dengan total.',
    'en': 'Shares must add up to the total.',
  },
  'bs_paid': {'id': 'Lunas {n}/{m}', 'en': 'Settled {n}/{m}'},
  'bs_done': {'id': 'Lunas semua', 'en': 'All settled'},
  'bs_owes': {
    'id': '{a} berutang {m} ke {b}',
    'en': '{a} owes {m} to {b}',
  },
  'bs_me': {'id': 'Saya', 'en': 'Me'},
  'bs_settle': {'id': 'Tandai lunas', 'en': 'Mark settled'},
  'bs_unsettle': {'id': 'Batalkan', 'en': 'Reopen'},
  'bs_del_t': {'id': 'Hapus patungan', 'en': 'Delete split'},
  'bs_del_s': {
    'id': 'Hapus patungan ini? Transaksi asli tetap ada.',
    'en': 'Delete this split? The original transaction stays.',
  },
  'bs_saved': {'id': 'Patungan tersimpan', 'en': 'Split saved'},
  'bs_full': {
    'id': 'Patungan penuh (30). Hapus yang tak dipakai dulu.',
    'en': 'Bill splits are full (30). Delete an unused one first.',
  },
  // Utang-piutang (Batch 13 revisi, simpan prefs lokal)
  'db_title': {'id': 'Utang & Piutang', 'en': 'Debts & Receivables'},
  'db_sub': {
    'id': 'Catat siapa berutang ke siapa.',
    'en': 'Track who owes whom.',
  },
  'db_empty_t': {'id': 'Belum ada catatan', 'en': 'No records yet'},
  'db_empty_s': {
    'id': 'Catat utangmu ke orang atau piutang orang ke kamu.',
    'en': 'Record what you owe others or what they owe you.',
  },
  'db_new': {'id': 'Catatan baru', 'en': 'New record'},
  'db_debt': {'id': 'Utang', 'en': 'Debt'},
  'db_receivable': {'id': 'Piutang', 'en': 'Receivable'},
  'db_debt_h': {
    'id': 'Kamu berutang — kamu yang membayar.',
    'en': 'You owe — you pay.',
  },
  'db_receivable_h': {
    'id': 'Orang berutang — kamu yang menerima.',
    'en': 'They owe — you receive.',
  },
  'db_name': {'id': 'Nama orang', 'en': 'Person name'},
  'db_note': {'id': 'Catatan (opsional)', 'en': 'Note (optional)'},
  'db_total_debt': {'id': 'Sisa utang', 'en': 'Debts owed'},
  'db_total_rec': {'id': 'Sisa piutang', 'en': 'Receivables'},
  'db_paid': {'id': 'Sudah bayar {m}', 'en': 'Paid {m}'},
  'db_rest': {'id': 'Sisa {m}', 'en': 'Left {m}'},
  'db_done': {'id': 'Lunas', 'en': 'Settled'},
  'db_pay': {'id': 'Bayar', 'en': 'Pay'},
  'db_pay_hint': {'id': 'Nominal ≤ sisa.', 'en': 'Amount ≤ remaining.'},
  'db_err_over': {'id': 'Melebihi sisa {m}.', 'en': 'Exceeds remaining {m}.'},
  'db_saved': {'id': 'Catatan tersimpan', 'en': 'Record saved'},
  'db_paid_ok': {'id': 'Pembayaran tercatat', 'en': 'Payment recorded'},
  'db_del_t': {'id': 'Hapus catatan', 'en': 'Delete record'},
  'db_del_s': {
    'id': 'Hapus catatan ini? Riwayat bayar ikut hilang.',
    'en': 'Delete this record? Payment history goes too.',
  },
  'db_empty_pay': {'id': 'Belum ada pembayaran.', 'en': 'No payments yet.'},
  'db_full': {
    'id': 'Catatan penuh (50). Hapus yang tak dipakai dulu.',
    'en': 'Records are full (50). Delete an unused one first.',
  },
  // Voice input (Batch 18, isi kolom ketik-cepat)
  'vc_mic': {'id': 'Isi dengan suara', 'en': 'Fill by voice'},
  'vc_listening': {
    'id': 'Mendengarkan... ketuk mic untuk berhenti.',
    'en': 'Listening... tap mic to stop.',
  },
  'vc_denied': {
    'id': 'Izin mic ditolak. Nyalakan di Pengaturan HP.',
    'en': 'Mic permission denied. Enable it in phone Settings.',
  },
  'vc_unsupported': {
    'id': 'Perangkat tak mendukung voice input.',
    'en': 'Voice input not supported on this device.',
  },
  'vc_error': {
    'id': 'Gagal mulai mic. Coba lagi.',
    'en': 'Failed to start mic. Try again.',
  },
  'vc_hear': {
    'id': 'Tak terdengar jelas. Coba lagi.',
    'en': 'Not heard clearly. Try again.',
  },
  'vc_offline': {
    'id': 'Butuh internet untuk voice input.',
    'en': 'Voice input needs internet.',
  },
  // Dashboard Beranda (Batch 16, kartu bisa disusun)
  'dash_title': {'id': 'Dashboard', 'en': 'Dashboard'},
  'dash_arrange': {'id': 'Susun', 'en': 'Arrange'},
  'dash_done': {'id': 'Selesai', 'en': 'Done'},
  'dash_show': {'id': 'Tampilkan kartu', 'en': 'Show card'},
  'dash_hide': {'id': 'Sembunyikan kartu', 'en': 'Hide card'},
  'dash_make_budget': {'id': 'Buat budget', 'en': 'Create budget'},
  'dash_budget': {'id': 'Status budget', 'en': 'Budget status'},
  'dash_feature': {'id': 'Fitur', 'en': 'Features'},
  'dash_debt': {'id': 'Utang ringkas', 'en': 'Debts at a glance'},
  // Subkategori + meta (P2 subcategory-picker)
  'sub_hint': {'id': 'Subkategori (opsional)', 'en': 'Subcategory (optional)'},
  'sub_add': {'id': 'Tambah subkategori', 'en': 'Add subcategory'},
  'rcp_origin_from': {'id': 'Dari struk', 'en': 'From receipt'},
  'rcp_kind_mini': {'id': 'Minimarket', 'en': 'Minimarket'},
  'rcp_kind_food': {'id': 'Kuliner', 'en': 'Dining'},
  'sub_color': {'id': 'Warna', 'en': 'Color'},
  'sub_icon': {'id': 'Ikon', 'en': 'Icon'},
  'sub_sep_err': {
    'id': 'Nama tak boleh mengandung tanda >.',
    'en': 'Name must not contain >.',
  },
  // Widget hari ini (P2 widget-qs-tile)
  'wg_open': {'id': 'Buka app untuk memuat', 'en': 'Open the app to load'},
  'wg_out_today': {
    'id': 'Keluar hari ini {m}',
    'en': 'Out today {m}',
  },
  'wg_budget_left': {
    'id': 'Sisa budget {m}',
    'en': 'Budget left {m}',
  },
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
  'o_clearcache_t': {'id': 'Hapus cache lokal', 'en': 'Clear local cache'},
  'o_clearcache_done': {
    'id': 'Cache lokal dibersihkan.',
    'en': 'Local cache cleared.',
  },
  'nt_saved_title': {'id': 'Transaksi tercatat', 'en': 'Transaction saved'},
  'td_title': {'id': 'Detail transaksi', 'en': 'Transaction details'},
  'td_wallet': {'id': 'Dompet', 'en': 'Wallet'},
  'td_towallet': {'id': 'Dompet tujuan', 'en': 'Destination wallet'},
  'td_view': {'id': 'Lihat di Transaksi', 'en': 'View in Transactions'},
  'td_close': {'id': 'Tutup', 'en': 'Close'},
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
  'st_pin_send': {
    'id': 'Kirim link verifikasi ke email',
    'en': 'Send verification link to email',
  },
  'st_pin_sent_link': {
    'id': 'Link dikirim ke {e}. Buka email lalu ketuk linknya — app terbuka otomatis.',
    'en': 'Link sent to {e}. Open your email and tap the link — the app opens automatically.',
  },
  'st_pin_wait': {
    'id': 'Menunggu ketuk link di email (berlaku 1 jam).',
    'en': 'Waiting for the email link tap (valid for 1 hour).',
  },
  'st_pin_resend': {'id': 'Kirim ulang link', 'en': 'Resend link'},
  'st_pin_new': {'id': 'PIN baru (6 digit)', 'en': 'New PIN (6 digits)'},
  'st_pin_new2': {'id': 'Ulangi PIN baru', 'en': 'Repeat new PIN'},
  'st_pin_save': {'id': 'Simpan PIN', 'en': 'Save PIN'},
  'st_pin_changed': {'id': 'PIN diganti.', 'en': 'PIN changed.'},
  'st_pin_mismatch': {'id': 'PIN tidak sama.', 'en': 'PINs do not match.'},
  'st_pin_short': {
    'id': 'PIN minimal 4 digit.',
    'en': 'PIN must be at least 4 digits.',
  },
  'st_pin_noemail': {
    'id': 'Email user tidak ditemukan.',
    'en': 'User email not found.',
  },
  'st_pin_old': {'id': 'PIN lama (6 digit)', 'en': 'Old PIN (6 digits)'},
  'st_pin_next': {'id': 'Lanjut', 'en': 'Continue'},
  'st_pin_forgot': {
    'id': 'Lupa PIN? Kirim link ke email',
    'en': 'Forgot PIN? Send link to email',
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
  'au_forgot': {'id': 'Lupa password?', 'en': 'Forgot password?'},
  'au_need_email': {
    'id': 'Isi email dulu, link reset dikirim ke sana.',
    'en': 'Enter your email first, the reset link goes there.',
  },
  'au_reset_sent': {
    'id': 'Link reset dikirim. Cek email, ketuk linknya, lalu buat password baru.',
    'en': 'Reset link sent. Check your email, tap the link, then make a new password.',
  },
  'au_google': {'id': 'Masuk dengan Google', 'en': 'Sign in with Google'},
  'lk_bio': {'id': 'Buka dengan sidik jari', 'en': 'Unlock with fingerprint'},
  'bio_t': {'id': 'Sidik jari', 'en': 'Fingerprint'},
  'bio_s': {
    'id': 'Buka kunci tanpa ketik PIN. PIN tetap bisa dipakai kapan saja.',
    'en': 'Unlock without typing PIN. PIN still works anytime.',
  },
  'bio_unsupported': {
    'id': 'HP ini tak punya sidik jari terdaftar.',
    'en': 'This phone has no enrolled fingerprint.',
  },
  'bio_failed': {
    'id': 'Sidik jari gagal ({c}). Coba PIN atau periksa pengaturan HP.',
    'en': 'Fingerprint failed ({c}). Try PIN or check phone settings.',
  },
  'np_title': {'id': 'Password baru', 'en': 'New password'},
  'np_sub': {
    'id': 'Buat password pengganti yang minimal 6 karakter.',
    'en': 'Make a replacement password, at least 6 characters.',
  },
  'np_pass1': {'id': 'Password baru', 'en': 'New password'},
  'np_pass2': {'id': 'Ulangi password', 'en': 'Repeat password'},
  'np_mismatch': {
    'id': 'Password tidak sama. Ulangi dengan teliti.',
    'en': 'Passwords do not match. Repeat carefully.',
  },
  'np_short': {
    'id': 'Password minimal 6 karakter.',
    'en': 'Password must be at least 6 characters.',
  },
  'np_save': {'id': 'Simpan password', 'en': 'Save password'},
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
  'bl_soon': {'id': 'Segera hadir', 'en': 'Coming soon'},
  'bl_soon_s': {
    'id': 'Pembayaran Pro dalam persiapan. Kuota Gratis tetap berlaku dan kini ditegakkan server.',
    'en': 'Pro payments are being prepared. Free quotas still apply and are now enforced server-side.',
  },
  'iv_quota': {
    'id': 'Anggota workspace penuh (maksimal 3 di paket Gratis).',
    'en': 'Workspace members full (maximum 3 on the Free plan).',
  },
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
  'org_admin': {'id': 'Admin', 'en': 'Admin'},
  'org_member': {'id': 'Anggota', 'en': 'Member'},
  'org_new': {'id': 'Buat workspace baru', 'en': 'Create new workspace'},
  'org_f_name': {'id': 'Nama workspace', 'en': 'Workspace name'},
  'org_create': {'id': 'Buat', 'en': 'Create'},
  'org_f_code': {'id': 'Kode undangan', 'en': 'Invite code'},
  'org_join': {'id': 'Gabung', 'en': 'Join'},
  // Detail workspace
  'wsm_members': {'id': 'Anggota', 'en': 'Members'},
  'wsm_you': {'id': 'Kamu', 'en': 'You'},
  'wsm_kick': {'id': 'Keluarkan', 'en': 'Remove'},
  'wsm_kick_title': {'id': 'Keluarkan anggota?', 'en': 'Remove member?'},
  'wsm_kick_body': {
    'id': 'Aksesnya ke buku kas ini langsung putus.',
    'en': 'Their access to this ledger ends immediately.',
  },
  'wsm_kick_last': {
    'id': 'Tak bisa keluarkan pemilik terakhir.',
    'en': 'Cannot remove the last owner.',
  },
  'wsm_kick_denied': {
    'id': 'Hanya pemilik/admin.',
    'en': 'Owners/admins only.',
  },
  'wsm_danger': {'id': 'Zona berbahaya', 'en': 'Danger zone'},
  'wsm_delete': {'id': 'Hapus workspace', 'en': 'Delete workspace'},
  'wsm_delete_body': {
    'id': 'Semua dompet, transaksi, dan data ikut terhapus. Ketik nama workspace untuk konfirmasi.',
    'en': 'All wallets, transactions, and data go with it. Type the workspace name to confirm.',
  },
  'wsm_delete_hint': {
    'id': 'Ketik nama workspace',
    'en': 'Type workspace name',
  },
  'wsm_delete_denied': {
    'id': 'Hanya pemilik yang bisa hapus workspace.',
    'en': 'Only owners can delete the workspace.',
  },
  'wsm_nomigration': {
    'id': 'Butuh migration_14: jalankan di Supabase SQL Editor.',
    'en': 'Requires migration_14: run it in the Supabase SQL editor.',
  },
  'wsm_err': {
    'id': 'Gagal. Periksa koneksi.',
    'en': 'Failed. Check your connection.',
  },
  'wsm_detail': {'id': 'Kelola', 'en': 'Manage'},
  'wsm_invite_active': {
    'id': 'Aktifkan workspace ini dulu untuk mengundang anggota.',
    'en': 'Activate this workspace first to invite members.',
  },
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
  'st_need_wallet': {
    'id': 'Dompet belum dipetakan — atur di Pelacakan otomatis lalu Simpan manual',
    'en': 'Wallet not mapped — set it in Auto-tracking then Save manually',
  },
  'st_pending_settle': {
    'id': 'Menunggu cair — Simpan manual saat dana masuk',
    'en': 'Pending settlement — save manually once funds arrive',
  },
  'st_saved': {'id': 'Tersimpan', 'en': 'Saved'},
  'nt_auto_from': {'id': 'Otomatis dari {a}', 'en': 'Auto from {a}'},
  'nt_automerge': {
    'id': 'Otomatis digabung sebagai transfer',
    'en': 'Auto-merged as a transfer',
  },
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
  'tx_nowallet': {'id': 'Tanpa dompet', 'en': 'No wallet'},
  'tx_nowallet_banner': {
    'id': '{n} tanpa dompet · {a} tak masuk total aset',
    'en': '{n} without a wallet · {a} excluded from totals',
  },
  'tx_nowallet_only': {'id': 'Hanya tanpa dompet', 'en': 'Only missing wallet'},
  'tx_show_all': {'id': 'Tampilkan semua', 'en': 'Show all'},
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
  'r_share_xlsx': {
    'id': 'Laporan SSR SPACE (Excel)',
    'en': 'SSR SPACE report (Excel)',
  },
  'r_xlsx_meta': {
    'id': '{p} · diekspor {d}',
    'en': '{p} · exported {d}',
  },
  // Prakiraan kas (Batch 17, skenario waspada)
  'cf_title': {'id': 'Prakiraan 30 hari', 'en': '30-day forecast'},
  'cf_sub': {
    'id': 'Skenario waspada: rata-rata + tagihan terjadwal. Seluruh dompet.',
    'en': 'Cautious scenario: averages + scheduled bills. All wallets.',
  },
  'cf_end': {'id': 'Akhir bulan {m}', 'en': 'Month end {m}'},
  'cf_warn': {
    'id': 'Diprediksi minus {m}, {n} hari lagi',
    'en': 'Predicted negative {m} in {n} days',
  },
  'pdf_filter': {
    'id': 'Dompet: {w} • Jenis: {t}',
    'en': 'Wallet: {w} • Type: {t}',
  },
  'pdf_h_wallet': {'id': 'Dompet', 'en': 'Wallet'},
  'pdf_all': {'id': 'Semua', 'en': 'All'},
  'exp_saved_title': {'id': 'File tersimpan', 'en': 'File saved'},
  'exp_saved_body': {
    'id': '{f} tersimpan di Dokumen/ssr-space.',
    'en': '{f} saved to Documents/ssr-space.',
  },
  'exp_share': {'id': 'Bagikan', 'en': 'Share'},
  'exp_noperm': {
    'id': 'Izin penyimpanan ditolak, file dibagikan saja.',
    'en': 'Storage permission denied, sharing file instead.',
  },
  'ab_credits': {
    'id': 'Ikon: Coolicons oleh Kryston Schwarze (CC BY 4.0).',
    'en': 'Icons: Coolicons by Kryston Schwarze (CC BY 4.0).',
  },
  // Profil: judul seksi katalog
  'pf_data': {'id': 'Data', 'en': 'Data'},
  'pf_tracking': {'id': 'Pelacakan', 'en': 'Tracking'},
  'pf_backup': {'id': 'Data dan cadangan', 'en': 'Data and backup'},
  'pf_workspace': {'id': 'Workspace', 'en': 'Workspace'},
  'pf_appearance': {'id': 'Tampilan', 'en': 'Appearance'},
  'pf_langmoney': {'id': 'Bahasa dan mata uang', 'en': 'Language and currency'},
  'pf_reminder': {'id': 'Pengingat', 'en': 'Reminders'},
  'pf_security': {'id': 'Keamanan', 'en': 'Security'},
  'pf_about': {'id': 'Tentang', 'en': 'About'},
  // Pengaturan: katalog tampilan dan pengingat
  'st_def_currency': {'id': 'Mata uang bawaan', 'en': 'Default currency'},
  'st_topn': {
    'id': 'Top 8 + Lainnya di laporan',
    'en': 'Top 8 + Other in reports',
  },
  'st_topn_sub': {
    'id': 'Batasi kategori terbanyak di laporan',
    'en': 'Limit top categories in reports',
  },
  'st_anims': {'id': 'Animasi', 'en': 'Animations'},
  'st_list_style': {'id': 'Gaya daftar', 'en': 'List style'},
  'st_list_compact': {'id': 'Rapat', 'en': 'Compact'},
  'st_list_comfortable': {'id': 'Lega', 'en': 'Comfortable'},
  'st_date_style': {'id': 'Gaya tanggal', 'en': 'Date style'},
  'st_hero_style': {'id': 'Gaya ringkasan', 'en': 'Summary style'},
  'st_theme': {'id': 'Tema', 'en': 'Theme'},
  'th_auto': {'id': 'Otomatis', 'en': 'Automatic'},
  'th_noir': {'id': 'Noir', 'en': 'Noir'},
  'th_theme_desc': {
    'id': 'Pilih tampilan aplikasi.',
    'en': 'Choose how the app looks.',
  },
  'st_reminder_time': {'id': 'Jam pengingat', 'en': 'Reminder time'},
  'st_reminder_on': {'id': 'Pengingat harian', 'en': 'Daily reminder'},
  'st_weekly_on': {'id': 'Pengingat mingguan', 'en': 'Weekly reminder'},
  'st_weekly_time': {
    'id': 'Waktu pengingat mingguan',
    'en': 'Weekly reminder time',
  },
  'st_weekly_day': {'id': 'Hari', 'en': 'Day'},
  'wd_1': {'id': 'Senin', 'en': 'Monday'},
  'wd_2': {'id': 'Selasa', 'en': 'Tuesday'},
  'wd_3': {'id': 'Rabu', 'en': 'Wednesday'},
  'wd_4': {'id': 'Kamis', 'en': 'Thursday'},
  'wd_5': {'id': 'Jumat', 'en': 'Friday'},
  'wd_6': {'id': 'Sabtu', 'en': 'Saturday'},
  'wd_7': {'id': 'Minggu', 'en': 'Sunday'},
  'st_widget_today': {'id': 'Widget hari ini', 'en': 'Today widget'},
  // Impor CSV
  'imp_title': {'id': 'Impor CSV', 'en': 'Import CSV'},
  'imp_pick': {'id': 'Tempel CSV', 'en': 'Paste CSV'},
  'imp_map_date': {'id': 'Kolom tanggal', 'en': 'Date column'},
  'imp_map_amount': {'id': 'Kolom nominal', 'en': 'Amount column'},
  'imp_map_type': {'id': 'Kolom jenis', 'en': 'Type column'},
  'imp_map_wallet': {'id': 'Kolom dompet', 'en': 'Wallet column'},
  'imp_map_towallet': {
    'id': 'Kolom dompet tujuan',
    'en': 'Destination wallet column',
  },
  'imp_map_cat': {'id': 'Kolom kategori', 'en': 'Category column'},
  'imp_map_note': {'id': 'Kolom catatan', 'en': 'Note column'},
  'imp_preview': {'id': 'Pratinjau', 'en': 'Preview'},
  'imp_errors': {'id': 'Baris bermasalah ({n})', 'en': 'Problem rows ({n})'},
  'imp_import': {'id': 'Impor', 'en': 'Import'},
  'imp_done': {
    'id': 'Impor selesai: {n} transaksi.',
    'en': 'Import done: {n} transactions.',
  },
  'imp_need_wallet': {
    'id': 'Pilih workspace dan buat minimal 1 dompet dulu, baru bisa impor.',
    'en': 'Pick a workspace and create at least 1 wallet first, then import.',
  },
  // Tentang
  'ab_about': {'id': 'Tentang SSR SPACE', 'en': 'About SSR SPACE'},
  'ab_changelog': {'id': 'Catatan perubahan', 'en': 'Changelog'},
  'ab_help': {'id': 'Bantuan', 'en': 'Help'},
  'ab_help_body': {
    'id': 'Periksa koneksi lalu coba lagi. Bila masih gagal, catat pesan galat yang muncul.',
    'en': 'Check your connection and try again. If it still fails, note the error message shown.',
  },
  'ab_feedback': {'id': 'Kirim masukan', 'en': 'Send feedback'},
  'ab_share': {'id': 'Bagikan aplikasi', 'en': 'Share the app'},
  'ab_privacy': {'id': 'Privasi', 'en': 'Privacy'},
  'ab_privacy_body': {
    'id': 'Data tersimpan aman di cloud dan hanya bisa diakses dalam workspace-mu.',
    'en': 'Data is stored securely in the cloud and only accessible within your workspace.',
  },
  'tx_quick_hint': {
    'id': 'Ketik cepat: "makan siang 35rb"',
    'en': 'Quick type: "lunch 35k"',
  },
  'tx_quick_no': {
    'id': 'Tak dikenali, isi manual saja',
    'en': 'Not recognized, fill in manually',
  },
  // Bantuan: tutorial + tanya jawab
  'hp_title': {'id': 'Bantuan', 'en': 'Help'},
  'hp_guide': {'id': 'Cara memakai', 'en': 'How to use'},
  'hp_faq': {'id': 'Tanya jawab', 'en': 'FAQ'},
  'hp_start_t': {'id': 'Mulai: workspace dan dompet', 'en': 'Start: workspace and wallets'},
  'hp_start_b': {
    'id': 'Daftar lalu verifikasi email. Buat atau pilih workspace, tambah dompet (Kas, DANA, Bank), lalu catat pertama lewat tombol +.',
    'en': 'Sign up then verify your email. Create or pick a workspace, add wallets (cash, e-wallet, bank), then record your first entry with the + button.',
  },
  'hp_record_t': {'id': 'Mencatat transaksi', 'en': 'Recording transactions'},
  'hp_record_b': {
    'id': 'Tombol + tengah: ketik nominal di numpad, pilih Masuk, Keluar, atau Transfer. Dompet wajib diisi; tanggal default hari ini, jam opsional. Ketuk baris untuk ubah atau hapus.',
    'en': 'Middle + button: type the amount on the numpad, pick Income, Expense, or Transfer. Wallet is required; date defaults to today, time optional. Tap a row to edit or delete.',
  },
  'hp_track_t': {'id': 'Pelacakan otomatis', 'en': 'Auto tracking'},
  'hp_track_b': {
    'id': 'Profil, Pelacakan otomatis: beri izin akses notifikasi, nyalakan master, petakan tiap bank ke dompet. Transaksi masuk otomatis berlabel Otomatis; benarkan kategori lewat overlay atau sheet koreksi.',
    'en': 'Profile, Auto tracking: grant notification access, turn the master on, map each bank to a wallet. Entries arrive automatically labeled Otomatis; fix the category via the overlay or correction sheet.',
  },
  'hp_budget_t': {'id': 'Budget dan tabungan', 'en': 'Budgets and savings'},
  'hp_budget_b': {
    'id': 'Budget per kategori per bulan; cincin penuh berarti jebol. Kategori Tabungan jadi target emas lengkap dengan laju per hari.',
    'en': 'Monthly budget per category; a full ring means over budget. The Savings category becomes a gold target with a per-day pace.',
  },
  'hp_report_t': {'id': 'Laporan dan cadangan', 'en': 'Reports and backup'},
  'hp_report_b': {
    'id': 'Laporan: saring per bulan dan per dompet, ekspor CSV (bisa ditempel balik di Impor CSV) atau PDF. Cadangan 3 CSV tersedia dari Profil.',
    'en': 'Reports: filter by month and wallet, export CSV (can be pasted back into CSV Import) or PDF. A 3-file CSV backup is available from Profile.',
  },
  'hp_pin_t': {'id': 'PIN dan keamanan', 'en': 'PIN and security'},
  'hp_pin_b': {
    'id': 'PIN 6 digit; 5x salah dikunci 60 detik; app mengunci otomatis setelah 5 menit. Ganti PIN cukup verifikasi PIN lama; lupa PIN pakai link email.',
    'en': '6-digit PIN; 5 wrong tries lock for 60 seconds; the app auto-locks after 5 minutes. Changing PIN only needs the old PIN; forgot it, use the email link.',
  },
  'hp_q1': {'id': 'Saldo dompet beda dengan Beranda?', 'en': 'Wallet balance differs from Home?'},
  'hp_a1': {
    'id': 'Beranda menampilkan arus bulan berjalan, Dompet menampilkan total sepanjang waktu. Transfer diabaikan Beranda, dan transaksi tanpa dompet tak masuk total aset.',
    'en': 'Home shows this month flow, Wallets show the all-time total. Home ignores transfers, and wallet-less entries never join total assets.',
  },
  'hp_q2': {'id': 'Notifikasi bank tak tercatat?', 'en': 'Bank notification not recorded?'},
  'hp_a2': {
    'id': 'Cek master pelacakan ON, izin akses notifikasi, dan service hidup. Sebagian bank menaruh isi di kolom khusus; pakai Pindai lalu Simpan manual bila perlu.',
    'en': 'Check tracking master is ON, notification access granted, and the service alive. Some banks hide content in a special field; use Scan then manual Save if needed.',
  },
  'hp_q3': {'id': 'Impor CSV gagal?', 'en': 'CSV import failed?'},
  'hp_a3': {
    'id': 'Header wajib ada tanggal, nominal, dan jenis. Format Indonesia (1.234,50) didukung. Hasil ekspor aplikasi bisa ditempel balik langsung.',
    'en': 'Headers must include date, amount, and type. Indonesian format (1.234,50) is supported. The app export output can be pasted straight back.',
  },
  'hp_q4': {'id': 'Lupa PIN?', 'en': 'Forgot PIN?'},
  'hp_a4': {
    'id': 'Di Pengaturan, PIN keamanan, ketuk Lupa PIN? Kirim link ke email. Buka email, ketuk link, app terbuka dan PIN baru bisa disimpan.',
    'en': 'In Settings, Security PIN, tap Forgot PIN? Send link to email. Open the email, tap the link, the app opens and a new PIN can be saved.',
  },
  'hp_q5': {'id': 'Ganti HP, data hilang?', 'en': 'New phone, data lost?'},
  'hp_a5': {
    'id': 'Tidak. Data tersimpan di cloud per workspace: masuk dengan akun yang sama lalu pilih workspace-mu. CSV cadangan hanya untuk arsip pribadi.',
    'en': 'No. Data lives in the cloud per workspace: sign in with the same account then pick your workspace. The CSV backup is only for personal archive.',
  },
  'hp_q6': {'id': 'Pengaturan seolah tak berubah?', 'en': 'Setting seems unchanged?'},
  'hp_a6': {
    'id': 'Tutup lalu buka lagi layarnya; sebagian kartu butuh rebuild. Pastikan memakai versi terbaru (lihat Tentang di Profil).',
    'en': 'Close and reopen the screen; some cards need a rebuild. Make sure you run the latest version (see About in Profile).',
  },
  // Cari + penanda tahap
  'search_settings_hint': {
    'id': 'Cari pengaturan...',
    'en': 'Search settings...',
  },
  'search_no_result': {
    'id': 'Tidak ada pengaturan yang cocok. Coba kata lain.',
    'en': 'No matching settings. Try another keyword.',
  },
  'msg_p2': {
    'id': 'Bagian ini tahap P2. Pengaturan tetap tersimpan bila sudah ada.',
    'en':
        'This section is phase P2. Settings stay saved where already present.',
  },
  // Pengingat: varian copy harian (P2 reminder-copy, rotasi deterministik)
  'rmc_m1': {
    'id': 'Luangkan sejenak merapikan catatan kemarin.',
    'en': "Take a moment to tidy yesterday's notes.",
  },
  'rmc_m2': {
    'id': 'Pagi yang tenang untuk mengecek kas.',
    'en': 'A calm morning to check your cash.',
  },
  'rmc_m3': {
    'id': 'Satu menit menutup catatan kemarin.',
    'en': "One minute to close yesterday's log.",
  },
  'rmc_m4': {
    'id': 'Lihat kembali arus kemarin dengan santai.',
    'en': "Glance back at yesterday's flow, calmly.",
  },
  'rmc_m5': {
    'id': 'Rapikan awal hari dengan satu catatan.',
    'en': 'Start the day tidy with one entry.',
  },
  'rmc_m6': {
    'id': 'Cek sisa kemarin sebelum lanjut hari ini.',
    'en': "Review yesterday's remainder before today.",
  },
  'rmc_e1': {
    'id': 'Tutup hari dengan satu catatan singkat.',
    'en': 'End the day with one short entry.',
  },
  'rmc_e2': {
    'id': 'Refleksi singkat: apa yang keluar hari ini?',
    'en': 'A brief reflection: what went out today?',
  },
  'rmc_e3': {
    'id': 'Sejenak menengok buku kas malam ini.',
    'en': "Take a peek at tonight's ledger.",
  },
  'rmc_e4': {
    'id': 'Catat yang tertinggal, lalu istirahat.',
    'en': "Log what's left, then rest.",
  },
  'rmc_e5': {
    'id': 'Satu baris penutup untuk hari ini.',
    'en': 'One closing line for today.',
  },
  'rmc_e6': {
    'id': 'Tenang, cukup catat yang kamu ingat.',
    'en': 'Calmly, just log what you remember.',
  },
  'rmc_b1': {
    'id': 'Akhir bulan: rapikan sisa catatan bulan ini.',
    'en': "Month-end: tidy this month's remaining notes.",
  },
  'rmc_b2': {
    'id': 'Siapkan tutup bulan dengan satu cek singkat.',
    'en': 'Prepare month close with one quick check.',
  },
  // Beranda: calm streak 8 minggu (P2, tanpa angka/API)
  'calm_title': {'id': 'Catatan 8 minggu terakhir', 'en': 'Last 8 weeks'},
  'calm_sub': {
    'id': 'Titik penuh = minggu dengan catatan.',
    'en': 'Filled dot = week with an entry.',
  },
  // NFC e-money
  'nfc_title': {'id': 'E-Money NFC', 'en': 'E-Money NFC'},
  'nfc_sub': {'id': 'Tempel kartu, baca saldo', 'en': 'Tap card, read balance'},
  'nfc_tap': {'id': 'Tempel kartu & baca', 'en': 'Tap card & read'},
  'nfc_scanning': {
    'id': 'Tempelkan kartu ke HP, jangan dilepas…',
    'en': 'Hold the card to the phone…',
  },
  'nfc_stop': {'id': 'Stop', 'en': 'Stop'},
  'nfc_lib_ready': {'id': 'Siap membaca kartu', 'en': 'Ready to read cards'},
  'nfc_no_nfc': {
    'id': 'HP ini tidak mendukung NFC.',
    'en': 'This phone has no NFC support.',
  },
  'nfc_balance': {'id': 'Saldo', 'en': 'Balance'},
  'nfc_card_history': {'id': 'Riwayat kartu', 'en': 'Card history'},
  'nfc_link': {'id': 'Tautkan ke dompet', 'en': 'Link to wallet'},
  'nfc_no_wallet': {'id': 'Tanpa dompet', 'en': 'No wallet'},
  'nfc_save': {'id': 'Simpan kartu', 'en': 'Save card'},
  'nfc_saved': {'id': 'Kartu tersimpan', 'en': 'Card saved'},
  'nfc_checks': {'id': 'Cek terakhir', 'en': 'Recent checks'},
  'nfc_empty': {
    'id': 'Belum ada kartu. Tempel kartu untuk mulai.',
    'en': 'No cards yet. Tap a card to start.',
  },
  'nfc_in': {'id': 'Masuk', 'en': 'In'},
  'nfc_out': {'id': 'Keluar', 'en': 'Out'},
  'nfc_other': {'id': 'Lainnya', 'en': 'Other'},
  'nfc_read_fail': {
    'id': 'Gagal baca kartu. Tempel ulang.',
    'en': 'Card read failed. Tap again.',
  },
  'nfc_delete': {'id': 'Hapus kartu ini?', 'en': 'Delete this card?'},
  // NFC: gate ketersediaan
  'nfc_no_hw': {
    'id': 'HP ini tidak mendukung pembacaan NFC.',
    'en': 'This phone cannot read NFC.',
  },
  'nfc_off': {'id': 'NFC mati', 'en': 'NFC is off'},
  'nfc_off_steps': {
    'id': 'Nyalakan NFC di Pengaturan → Koneksi, lalu Coba lagi.',
    'en': 'Turn on NFC in Settings → Connections, then Retry.',
  },
  'nfc_retry': {'id': 'Coba lagi', 'en': 'Retry'},
  // Dompet: kelola
  'w_rename_t': {'id': 'Ubah dompet', 'en': 'Edit wallet'},
  'w_has_tx': {
    'id': 'Dompet berisi transaksi — hapus tidak bisa. Ubah nama bila perlu.',
    'en': 'Wallet has transactions — cannot delete. Rename if needed.',
  },
  'w_deleted': {'id': 'Dompet dihapus', 'en': 'Wallet deleted'},
  'w_del_confirm': {
    'id': 'Hapus dompet ini? Tindakan tak bisa dibatalkan.',
    'en': 'Delete this wallet? Cannot be undone.',
  },
  'w_opening': {'id': 'Saldo awal (opsional)', 'en': 'Opening balance (optional)'},
  'w_renamed': {'id': 'Dompet diperbarui', 'en': 'Wallet updated'},
  // NFC: taut dompet
  'nfc_make_wallet': {'id': 'Jadikan dompet', 'en': 'Make wallet'},
  'nfc_wallet_made': {
    'id': 'Dompet dibuat + saldo awal tercatat',
    'en': 'Wallet created with opening balance',
  },
  'nfc_matched': {'id': 'Sudah cocok dengan buku', 'en': 'Matches the books'},
  'nfc_diff': {'id': 'Selisih {m}', 'en': 'Difference {m}'},
  // We Space: mode + aktivitas
  'sp_mode': {'id': 'Mode Space', 'en': 'Space mode'},
  'sp_mode_desc': {
    'id':
        'Bebas: semua anggota bisa catat. Bendahara: hanya owner/admin yang catat, anggota lain melihat.',
    'en':
        'Open: every member can record. Treasurer: only owners/admins record, others view.',
  },
  'sp_bebas': {'id': 'Bebas', 'en': 'Open'},
  'sp_bendahara': {'id': 'Bendahara', 'en': 'Treasurer'},
  'sp_bendahara_hint': {
    'id': 'Anggota baru hanya bisa melihat.',
    'en': 'New members can only view.',
  },
  'sp_activity': {'id': 'Aktivitas Space', 'en': 'Space activity'},
  'sp_new': {'id': 'baru', 'en': 'new'},
  'sp_only_treasurer': {
    'id': 'Hanya bendahara yang bisa catat di Space ini.',
    'en': 'Only treasurers can record in this Space.',
  },
  'sp_adminonly': {
    'id': 'Hanya owner/admin yang bisa ganti mode.',
    'en': 'Only owners/admins can change the mode.',
  },
  'sp_badmode': {'id': 'Mode tidak dikenal.', 'en': 'Unknown mode.'},
  'close': {'id': 'Tutup', 'en': 'Close'},
  'sp_by_you': {'id': 'Kamu', 'en': 'You'},
  'sp_by_member': {'id': 'Anggota •{s}', 'en': 'Member •{s}'},
  // LOOP 1: Daily Touch (streak, health score, pace budget)
  'streak_title': {'id': 'Streak catat', 'en': 'Logging streak'},
  'streak_empty': {
    'id': 'Belum ada streak. Catat hari ini buat mulai.',
    'en': 'No streak yet. Log today to start.',
  },
  'streak_today': {
    'id': 'Udah catat hari ini. Besok balik lagi ya.',
    'en': 'Logged today. Come back tomorrow.',
  },
  'streak_grace': {
    'id': 'Kemarin bolong, tapi streak aman. Catat hari ini biar lanjut.',
    'en': 'Yesterday slipped, streak still safe. Log today to keep it.',
  },
  'streak_next': {
    'id': 'Lagi {n} hari ke {m} hari. Gas.',
    'en': '{n} more days to {m}. Keep going.',
  },
  'streak_hit': {
    'id': '{m} hari beruntun. Keren.',
    'en': '{m} days in a row. Nice.',
  },
  'streak_days': {'id': '{n} hari', 'en': '{n} days'},
  'health_title': {'id': 'Skor keuangan', 'en': 'Money score'},
  'health_detail': {'id': 'Lihat rincian', 'en': 'See details'},
  'health_vs': {'id': '{p} poin vs kemarin', 'en': '{p} pts vs yesterday'},
  'health_c_budget': {'id': 'Patuh budget', 'en': 'Budget discipline'},
  'health_c_saving': {'id': 'Nabung', 'en': 'Saving'},
  'health_c_trend': {'id': 'Tren belanja', 'en': 'Spending trend'},
  'health_c_streak': {'id': 'Streak', 'en': 'Streak'},
  'pace_safe': {'id': 'Aman sampai akhir bulan', 'en': 'Safe until month end'},
  'pace_warn': {
    'id': 'Pace ini habis sekitar {d}',
    'en': 'At this pace, out around {d}',
  },
  'pace_danger': {
    'id': 'Jebol atau habis dalam 7 hari',
    'en': 'Over or out within 7 days',
  },
  'pace_summary': {
    'id': '{w} waspada, {b} bahaya. Cek layar Budget.',
    'en': '{w} warning, {b} danger. Check Budget.',
  },
  // LOOP 2: Smart Nudges (casual, tidak menghakimi)
  'nudge_title': {'id': 'Ngebut nih', 'en': 'Spending fast'},
  'nudge_line': {
    'id': 'Belanja {c} ngebut, habis sekitar {d} kalau gini terus.',
    'en': '{c} spending is fast, out around {d} at this pace.',
  },
  'ins_title': {'id': 'Kilasan minggu lalu', 'en': 'Last week recap'},
  'ins_total': {
    'id': 'Keluar {m} minggu lalu',
    'en': 'Spent {m} last week',
  },
  'ins_vs': {
    'id': '{p}% dibanding rata-rata',
    'en': '{p}% vs average',
  },
  'ins_avg': {
    'id': 'Rata-rata {a} per minggu',
    'en': 'Average {a} per week',
  },
  'ins_top': {
    'id': '{c} paling naik ({p}%)',
    'en': '{c} rose the most ({p}%)',
  },
  'ins_new': {
    'id': '{c} paling gede minggu lalu ({m})',
    'en': '{c} was biggest last week ({m})',
  },
  'ins_tip': {
    'id': 'Coba kurangi {c} {w} per minggu, hematnya {m} per bulan.',
    'en': 'Try cutting {c} by {w} a week, saves {m} a month.',
  },
  'cmp_title': {'id': 'Bulan ini vs bulan lalu', 'en': 'This vs last month'},
  'cmp_new': {'id': 'Baru', 'en': 'New'},
  'cmp_empty': {
    'id': 'Belum ada data bulan lalu buat dibandingin.',
    'en': 'No last-month data to compare yet.',
  },
  // Perluasan pengaturan (referensi Money Lover/Wallet/YNAB)
  'st_numformat': {'id': 'Format angka', 'en': 'Number format'},
  'st_def_wallet': {'id': 'Dompet default', 'en': 'Default wallet'},
  'st_def_wallet_none': {'id': 'Tanpa default', 'en': 'No default'},
  'st_weekstart': {'id': 'Awal minggu', 'en': 'Week start'},
  'st_weekstart_sub': {
    'id': 'Mempengaruhi kilasan mingguan dan tantangan.',
    'en': 'Affects weekly recap and challenges.',
  },
  'st_lock_timeout': {'id': 'Kunci otomatis', 'en': 'Auto-lock'},
  'st_lock_sub': {
    'id': 'Kunci PIN setelah app di background.',
    'en': 'PIN lock after app goes to background.',
  },
  'st_lock_min': {'id': '{n} mnt', 'en': '{n} min'},
  'st_notif_denied': {
    'id':
        'Izin notif ditolak HP, pengingat tak bisa bunyi. Nyalakan di Pengaturan HP.',
    'en':
        'Notification permission denied, reminders cannot fire. Enable it in phone Settings.',
  },
  // Batch 2: wizard auto-track 3 langkah
  'wz_title': {'id': 'Panduan pelacakan', 'en': 'Tracking guide'},
  'wz_step': {'id': 'Langkah {n} dari 3', 'en': 'Step {n} of 3'},
  'wz_skip': {'id': 'Lewati', 'en': 'Skip'},
  'wz_next': {'id': 'Lanjut', 'en': 'Next'},
  'wz_back': {'id': 'Kembali', 'en': 'Back'},
  'wz_done': {'id': 'Selesai', 'en': 'Done'},
  'wz_s1_t': {'id': '1. Izinkan baca notifikasi', 'en': '1. Allow reading notifications'},
  'wz_s1_s': {
    'id': 'Tanpa izin ini tak ada yang tercatat. Buka pengaturan HP, nyalakan akses notifikasi untuk SSR SPACE, lalu kembali dan cek lagi.',
    'en': 'Without this permission nothing is recorded. Open phone settings, enable notification access for SSR SPACE, then come back and recheck.',
  },
  'wz_s1_open': {'id': 'Buka pengaturan', 'en': 'Open settings'},
  'wz_s1_recheck': {'id': 'Cek lagi', 'en': 'Recheck'},
  'wz_s2_t': {'id': '2. Nyalakan pelacakan', 'en': '2. Turn tracking on'},
  'wz_s2_s': {
    'id': 'Satu tombol untuk semua bank dan dompet. App menjaga pemantauan tetap hidup di latar.',
    'en': 'One switch for all banks and wallets. The app keeps monitoring alive in the background.',
  },
  'wz_s3_t': {'id': '3. Petakan ke dompet', 'en': '3. Map to wallets'},
  'wz_s3_s': {
    'id': 'Tiap aplikasi uang masuk ke dompet mana? Yang belum dipetakan ikut tebakan nama — ketuk untuk betulkan.',
    'en': 'Which wallet does each money app go to? Unmapped ones follow name guesses — tap to fix.',
  },
  'wz_cta': {'id': 'Panduan 3 langkah', 'en': '3-step guide'},
  'wz_offer_t': {'id': 'Belum mencatat otomatis?', 'en': 'Not auto-recording yet?'},
  'wz_offer_s': {
    'id': 'Tiga langkah cepat: izin, nyalakan, petakan dompet. Mulai sekarang?',
    'en': 'Three quick steps: permission, switch on, map wallets. Start now?',
  },
  'wz_start': {'id': 'Mulai', 'en': 'Start'},
  'wz_later': {'id': 'Nanti', 'en': 'Later'},
  // Batch 2: pagination riwayat
  'tx_partial': {
    'id': 'Menampilkan {n} pertama — gulir ke bawah untuk muat semua.',
    'en': 'Showing first {n} — scroll down to load all.',
  },
  'tx_all_shown': {
    'id': 'Semua {n} transaksi tampil.',
    'en': 'All {n} transactions shown.',
  },
  // Batch 8: cache offline
  'off_s': {
    'id': 'Kamu offline — menampilkan data terakhir tersimpan.',
    'en': 'You are offline — showing last saved data.',
  },
  'off_retry': {'id': 'Muat ulang', 'en': 'Reload'},
  // Batch 9: cadangan JSON + pulihkan
  'bx_title': {'id': 'Cadangan JSON', 'en': 'JSON backup'},
  'bx_sub': {
    'id': 'Satu file utuh yang bisa dipulihkan.',
    'en': 'One complete file that can be restored.',
  },
  'bx_share': {
    'id': 'Cadangan data SSR SPACE (JSON)',
    'en': 'SSR SPACE data backup (JSON)',
  },
  'bx_backup_t': {'id': 'Cadangkan', 'en': 'Back up'},
  'bx_backup_s': {
    'id': 'Simpan dompet, transaksi, dan budget workspace aktif ke satu file JSON.',
    'en': 'Save the active workspace wallets, transactions, and budgets to one JSON file.',
  },
  'bx_backup_btn': {'id': 'Buat cadangan', 'en': 'Make backup'},
  'bx_backup_ok': {
    'id': 'Cadangan {n} transaksi tersimpan + dibagikan.',
    'en': 'Backup of {n} transactions saved + shared.',
  },
  'bx_backup_fail': {
    'id': 'Cadangan gagal. Cek internet lalu coba lagi.',
    'en': 'Backup failed. Check internet and try again.',
  },
  'bx_restore_t': {'id': 'Pulihkan', 'en': 'Restore'},
  'bx_restore_s': {
    'id': 'Tempel isi file cadangan JSON. Dompet dicocokkan per nama (hilang = dibuat), transaksi dikode-ulang.',
    'en': 'Paste a JSON backup file content. Wallets match by name (missing = created), transactions get fresh codes.',
  },
  'bx_restore_btn': {'id': 'Tempel JSON', 'en': 'Paste JSON'},
  'bx_paste_t': {'id': 'Tempel cadangan', 'en': 'Paste backup'},
  'bx_paste_ok': {'id': 'Lanjut', 'en': 'Continue'},
  'bx_pick_fail': {
    'id': 'File tak terbaca atau bukan cadangan SSR SPACE.',
    'en': 'File unreadable or not an SSR SPACE backup.',
  },
  'bx_preview': {
    'id': '{t} transaksi siap • {w} dompet baru • {s} dilewati.',
    'en': '{t} transactions ready • {w} new wallets • {s} skipped.',
  },
  'bx_capped': {
    'id': 'Dibatasi 2000 transaksi pertama.',
    'en': 'Limited to the first 2000 transactions.',
  },
  'bx_confirm': {'id': 'Pulihkan sekarang', 'en': 'Restore now'},
  'bx_result': {
    'id': 'Selesai: {o} masuk, {s} dilewati, {f} gagal, {w} dompet dibuat.',
    'en': 'Done: {o} added, {s} skipped, {f} failed, {w} wallets created.',
  },
  'bx_restore_fail': {
    'id': 'Pulihkan gagal. Cek internet lalu coba lagi.',
    'en': 'Restore failed. Check internet and try again.',
  },
  // Batch 10: notifikasi lokal alert budget
  'ba_n_warn_t': {'id': 'Budget hampir habis', 'en': 'Budget almost spent'},
  'ba_n_breach_t': {'id': 'Budget jebol', 'en': 'Budget exceeded'},
  'ba_n_multi_t': {'id': 'Peringatan budget', 'en': 'Budget warnings'},
  'ba_n_multi_s': {
    'id': '{n} kategori menyentuh batas budget. Buka Budget untuk rincian.',
    'en': '{n} categories hit budget limits. Open Budget for details.',
  },
  // LOOP 3: Goals (casual, tidak menghakimi)
  'goal_title': {'id': 'Target nabung', 'en': 'Saving goals'},
  'goal_sub': {
    'id': 'Nabung biar ada tujuannya',
    'en': 'Save with a purpose',
  },
  'goal_empty_t': {'id': 'Belum ada target', 'en': 'No goals yet'},
  'goal_empty_s': {
    'id': 'Bikin satu biar nabung ada tujuannya.',
    'en': 'Create one to give saving a purpose.',
  },
  'goal_empty_a': {'id': 'Bikin target', 'en': 'Create goal'},
  'goal_add': {'id': 'Target baru', 'en': 'New goal'},
  'goal_name': {'id': 'Buat apa nabungnya', 'en': 'What are you saving for'},
  'goal_target': {'id': 'Target nominal', 'en': 'Target amount'},
  'goal_deadline': {'id': 'Deadline (opsional)', 'en': 'Deadline (optional)'},
  'goal_deadline_hint': {
    'id': 'cth 2026-12-31, kosongkan bila santai',
    'en': 'e.g. 2026-12-31, leave empty if relaxed',
  },
  'goal_mode_auto': {
    'id': 'Ikut kategori Tabungan',
    'en': 'Follow Savings category',
  },
  'goal_mode_manual': {
    'id': 'Setor manual saja',
    'en': 'Manual deposits only',
  },
  'goal_deposit': {'id': 'Setor', 'en': 'Deposit'},
  'goal_deposit_hint': {
    'id': 'Catat progres saja, bukan transaksi.',
    'en': 'Progress note only, not a transaction.',
  },
  'goal_of': {'id': '{s} dari {t}', 'en': '{s} of {t}'},
  'goal_days_left': {'id': '{n} hari lagi', 'en': '{n} days left'},
  'goal_overdue': {'id': 'Lewat {n} hari', 'en': '{n} days overdue'},
  'goal_done': {'id': 'Kecapai. Keren.', 'en': 'Reached. Nice.'},
  'goal_proj': {
    'id': 'Kecapai sekitar {m}',
    'en': 'On track around {m}',
  },
  'goal_noproj': {
    'id': 'Belum bisa diproyeksi, nabung dulu yuk.',
    'en': 'Cannot project yet, save a bit first.',
  },
  'goal_need': {
    'id': 'Butuh {m} per bulan biar pas deadline.',
    'en': 'Needs {m} a month to hit the deadline.',
  },
  'goal_extra': {
    'id': 'Tambah {m} per bulan biar pas deadline.',
    'en': 'Add {m} a month to hit the deadline.',
  },
  'goal_delete': {'id': 'Hapus target ini?', 'en': 'Delete this goal?'},
  'goal_del_yes': {'id': 'Ya, hapus', 'en': 'Yes, delete'},
  'goal_icon': {
    'id': 'Ikon (nama kategori)',
    'en': 'Icon (category name)',
  },
  'goal_deleted': {'id': 'Target dihapus', 'en': 'Goal deleted'},
  'goal_saved': {'id': 'Target tersimpan', 'en': 'Goal saved'},
  'goal_deposited': {'id': 'Setoran tercatat', 'en': 'Deposit recorded'},
  'goal_err': {
    'id': 'Belum bisa simpan. Cek lagi isianmu.',
    'en': 'Cannot save yet. Check your inputs.',
  },
  'em_title': {'id': 'Dana darurat', 'en': 'Emergency fund'},
  'em_unsafe': {'id': 'Belum aman', 'en': 'Not safe yet'},
  'em_progress': {'id': 'Progres', 'en': 'In progress'},
  'em_safe': {'id': 'Aman', 'en': 'Safe'},
  'em_range': {
    'id': 'Target {a} sampai {b} (3-6x belanja).',
    'en': 'Target {a} to {b} (3-6x spending).',
  },
  // LOOP 4: Gamifikasi (casual)
  'game_title': {'id': 'Pencapaian', 'en': 'Achievements'},
  'game_sub': {
    'id': 'Badge, tantangan, level',
    'en': 'Badges, challenges, levels',
  },
  'game_level': {'id': 'Lv.{n} {t}', 'en': 'Lv.{n} {t}'},
  'game_xp_left': {
    'id': '{n} XP lagi ke {t}.',
    'en': '{n} XP to {t}.',
  },
  'game_max': {
    'id': 'Level mentok. Sungkem.',
    'en': 'Max level. Respect.',
  },
  'lvl_1': {'id': 'Baru Mulai', 'en': 'Fresh Start'},
  'lvl_2': {'id': 'Sadar Duit', 'en': 'Money Aware'},
  'lvl_3': {'id': 'Tukang Catat', 'en': 'Habit Logger'},
  'lvl_4': {'id': 'Penjaga Budget', 'en': 'Budget Guard'},
  'lvl_5': {'id': 'Penabung Rajin', 'en': 'Diligent Saver'},
  'lvl_6': {'id': 'Sultan Mini', 'en': 'Mini Sultan'},
  'lvl_7': {'id': 'Legenda Ledger', 'en': 'Ledger Legend'},
  'game_badges': {'id': 'Badge', 'en': 'Badges'},
  'game_new': {'id': 'Baru', 'en': 'New'},
  'b_streak7_t': {'id': 'Seminggu Konsisten', 'en': 'Consistent Week'},
  'b_streak7_d': {
    'id': 'Catat 7 hari beruntun.',
    'en': 'Log 7 days in a row.',
  },
  'b_streak30_t': {'id': 'Sebulan Penuh', 'en': 'Full Month'},
  'b_streak30_d': {
    'id': 'Catat 30 hari beruntun.',
    'en': 'Log 30 days in a row.',
  },
  'b_streak100_t': {'id': 'Seratus Hari', 'en': 'Hundred Days'},
  'b_streak100_d': {
    'id': 'Catat 100 hari beruntun.',
    'en': 'Log 100 days in a row.',
  },
  'b_save1m_t': {'id': 'Jutawan Mini', 'en': 'Mini Millionaire'},
  'b_save1m_d': {
    'id': 'Total nabung tembus 1 juta.',
    'en': 'Total savings hit 1 million.',
  },
  'b_clean30_t': {'id': 'Bulan Bersih', 'en': 'Clean Month'},
  'b_clean30_d': {
    'id': 'Sebulan tanpa budget jebol.',
    'en': 'A month with no broken budget.',
  },
  'b_goal1_t': {'id': 'Mimpi Kecapai', 'en': 'Dream Reached'},
  'b_goal1_d': {
    'id': 'Satu target nabung tercapai.',
    'en': 'One saving goal reached.',
  },
  'b_tx100_t': {'id': 'Seratus Catatan', 'en': 'Hundred Notes'},
  'b_tx100_d': {
    'id': '100+ transaksi tercatat.',
    'en': '100+ transactions logged.',
  },
  'b_emsafe_t': {'id': 'Dana Aman', 'en': 'Fund Safe'},
  'b_emsafe_d': {
    'id': 'Dana darurat sudah aman.',
    'en': 'Emergency fund is safe.',
  },
  'game_challenges': {'id': 'Tantangan', 'en': 'Challenges'},
  'ch_nospend3_t': {'id': 'Puasa Belanja', 'en': 'No-Spend Days'},
  'ch_nospend3_d': {
    'id': '3 hari tanpa belanja minggu ini.',
    'en': '3 days with no spending this week.',
  },
  'ch_jajan50_t': {'id': 'Jajan Kalem', 'en': 'Calm Snacking'},
  'ch_jajan50_d': {
    'id': 'Jajan di bawah 50rb minggu ini.',
    'en': 'Snacks under 50k this week.',
  },
  'ch_log7_t': {'id': 'Rajin Absen', 'en': 'Daily Check-in'},
  'ch_log7_d': {
    'id': 'Catat tiap hari selama 7 hari.',
    'en': 'Log every day for 7 days.',
  },
  'ch_take': {'id': 'Ikut', 'en': 'Join'},
  'ch_done': {'id': 'Selesai +50 XP', 'en': 'Done +50 XP'},
  'ch_failed': {
    'id': 'Gagal, coba lagi minggu depan.',
    'en': 'Failed, try again next week.',
  },
  'ch_progress': {'id': '{p} dari {t}', 'en': '{p} of {t}'},
};

String tr(String key) => _t[key]?[localeCode.value] ?? _t[key]?['id'] ?? key;
