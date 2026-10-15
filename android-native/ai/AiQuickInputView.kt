package com.ssr.space.ssr_space.ai

import android.content.Context
import android.text.InputType
import android.util.AttributeSet
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * View untuk input cepat transaksi dengan AI.
 *
 * Alur:
 * 1. User ketik di kolom input, misal: "kopi 18rb tadi pagi"
 * 2. Tekan "Parse" -> AI jalan (tampilkan loading)
 * 3. Hasil tampil sebagai KARTU KONFIRMASI (nominal, kategori, tanggal, bisa diedit)
 * 4. User tekan "Simpan" atau "Batal"
 *
 * TIDAK ADA penyimpanan otomatis tanpa konfirmasi.
 *
 * Error handling:
 * - RateLimited -> pesan jelas + fallback form manual
 * - Offline -> pesan jelas + fallback form manual
 * - InvalidKey -> pesan jelas + arahkan ke pengaturan
 */
class AiQuickInputView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : LinearLayout(context, attrs, defStyleAttr) {

    /** Callback saat user konfirmasi simpan. */
    var onSave: ((TransactionResult) -> Unit)? = null

    /** Callback saat user batal. */
    var onCancel: (() -> Unit)? = null

    /** Callback untuk buka form manual dengan teks terisi. */
    var onOpenManualForm: ((prefillText: String) -> Unit)? = null

    private val keyStore = AiKeyStore(context)
    private val cache = AiCategoryCache()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private lateinit var etInput: EditText
    private lateinit var btnParse: Button
    private lateinit var progress: ProgressBar
    private lateinit var tvStatus: TextView

    // Kartu konfirmasi
    private lateinit var cardConfirmation: LinearLayout
    private lateinit var etAmount: EditText
    private lateinit var etCategory: EditText
    private lateinit var etDate: EditText
    private lateinit var btnSave: Button
    private lateinit var btnCancel: Button

    init {
        orientation = VERTICAL
        buildUi()
    }

    private fun buildUi() {
        // Label
        addView(TextView(context).apply {
            text = "Input Cepat AI"
            textSize = 18f
            setPadding(0, 0, 0, 8)
        })

        // Contoh hint
        addView(TextView(context).apply {
            text = "Contoh: \"kopi 18rb tadi pagi\""
            textSize = 12f
            setPadding(0, 0, 0, 8)
        })

        // Kolom input cepat
        etInput = EditText(context).apply {
            hint = "Ketik: kopi 18rb tadi pagi"
            inputType = InputType.TYPE_CLASS_TEXT
        }
        addView(etInput)

        // Tombol Parse
        btnParse = Button(context).apply {
            text = "Parse dengan AI"
            setOnClickListener { parseInput() }
        }
        addView(btnParse)

        // Loading
        progress = ProgressBar(context).apply {
            visibility = View.GONE
        }
        addView(progress)

        // Status
        tvStatus = TextView(context).apply {
            setPadding(0, 8, 0, 8)
        }
        addView(tvStatus)

        // Kartu konfirmasi (disembunyikan awal)
        cardConfirmation = LinearLayout(context).apply {
            orientation = VERTICAL
            visibility = View.GONE
            setPadding(16, 16, 16, 16)
            // Background card sederhana
            setBackgroundColor(0xFF1E1E1E.toInt())
        }

        cardConfirmation.addView(TextView(context).apply {
            text = "Konfirmasi Transaksi"
            textSize = 16f
            setPadding(0, 0, 0, 12)
        })

        // Nominal (bisa diedit)
        cardConfirmation.addView(TextView(context).apply { text = "Nominal" })
        etAmount = EditText(context).apply {
            inputType = InputType.TYPE_CLASS_NUMBER
        }
        cardConfirmation.addView(etAmount)

        // Kategori (bisa diedit)
        cardConfirmation.addView(TextView(context).apply {
            text = "Kategori"
            setPadding(0, 8, 0, 0)
        })
        etCategory = EditText(context).apply {
            inputType = InputType.TYPE_CLASS_TEXT
        }
        cardConfirmation.addView(etCategory)

        // Tanggal (bisa diedit, format YYYY-MM-DD)
        cardConfirmation.addView(TextView(context).apply {
            text = "Tanggal (YYYY-MM-DD)"
            setPadding(0, 8, 0, 0)
        })
        etDate = EditText(context).apply {
            inputType = InputType.TYPE_CLASS_TEXT
        }
        cardConfirmation.addView(etDate)

        // Tombol Simpan / Batal
        val btnRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            setPadding(0, 16, 0, 0)
        }
        btnSave = Button(context).apply {
            text = "Simpan"
            setOnClickListener { confirmSave() }
        }
        btnCancel = Button(context).apply {
            text = "Batal"
            setOnClickListener { cancelConfirmation() }
        }
        btnRow.addView(btnSave, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        btnRow.addView(btnCancel, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        cardConfirmation.addView(btnRow)

        addView(cardConfirmation)
    }

    /**
     * Parse input user dengan AI.
     */
    private fun parseInput() {
        val input = etInput.text.toString().trim()
        if (input.isEmpty()) {
            tvStatus.text = "Ketik dulu transaksinya."
            return
        }

        val config = keyStore.toAiConfig()
        if (config == null) {
            tvStatus.text = "Belum ada API key. Buka Pengaturan AI dulu."
            return
        }

        setLoading(true)
        tvStatus.text = "AI sedang memproses..."
        cardConfirmation.visibility = View.GONE

        scope.launch {
            try {
                val provider = ZenProvider(config)
                val classifier = AiTransactionClassifier(provider, cache)

                // Coba parse dengan AI
                // Untuk demo, kita buat prompt yang minta JSON
                val prompt = """
                    Parse transaksi berikut menjadi JSON:
                    "$input"
                    
                    Jawab HANYA dengan JSON valid:
                    {"amount":<angka>,"category":"<kategori>","date":"YYYY-MM-DD"}
                    
                    Kategori: Makanan, Transportasi, Belanja, Tagihan, Kesehatan, Pendidikan, Hiburan, Tabungan, Lainnya.
                    Tanggal: gunakan hari ini (${getTodayString()}) jika tidak disebutkan.
                """.trimIndent()

                val llmResult = withContext(Dispatchers.IO) {
                    provider.complete(prompt)
                }

                llmResult.fold(
                    onSuccess = { json ->
                        val parsed = AiTransactionParser.parse(json)
                        parsed.fold(
                            onSuccess = { tx -> showConfirmation(tx) },
                            onFailure = { e ->
                                // Parse gagal -> fallback ke form manual
                                tvStatus.text = "AI tidak mengerti. Buka form manual."
                                onOpenManualForm?.invoke(input)
                            }
                        )
                    },
                    onFailure = { e ->
                        handleAiError(e, input)
                    }
                )
            } finally {
                setLoading(false)
            }
        }
    }

    /**
     * Handle error dari AI dengan pesan jelas + fallback.
     */
    private fun handleAiError(e: Throwable, originalInput: String) {
        when (e) {
            is AiFailure.RateLimited -> {
                tvStatus.text = "AI lagi sibuk (limit). Coba lagi nanti, atau isi manual."
                onOpenManualForm?.invoke(originalInput)
            }
            is AiFailure.NetworkError -> {
                tvStatus.text = "Offline. Periksa koneksi, atau isi form manual."
                onOpenManualForm?.invoke(originalInput)
            }
            is AiFailure.InvalidKey -> {
                tvStatus.text = "API key salah. Periksa di Pengaturan AI."
                // Jangan fallback ke manual, arahkan ke pengaturan
            }
            is AiFailure.ModelUnavailable -> {
                tvStatus.text = "Model AI tidak tersedia. Isi form manual."
                onOpenManualForm?.invoke(originalInput)
            }
            else -> {
                tvStatus.text = "Gagal: ${e.message}. Isi form manual."
                onOpenManualForm?.invoke(originalInput)
            }
        }
        // JANGAN log e yang mungkin mengandung data sensitif
    }

    /**
     * Tampilkan kartu konfirmasi dengan hasil parse.
     * Semua field bisa diedit user sebelum simpan.
     */
    private fun showConfirmation(tx: TransactionResult) {
        etAmount.setText(tx.amount.toString())
        etCategory.setText(tx.category)
        etDate.setText(tx.date)
        cardConfirmation.visibility = View.VISIBLE
        tvStatus.text = "Periksa dan edit jika perlu, lalu Simpan."
    }

    /**
     * User tekan Simpan -> validasi -> callback onSave.
     * TIDAK ADA penyimpanan otomatis; hanya via callback.
     */
    private fun confirmSave() {
        val amountStr = etAmount.text.toString().trim()
        val category = etCategory.text.toString().trim()
        val date = etDate.text.toString().trim()

        // Validasi
        val amount = amountStr.toLongOrNull()
        if (amount == null || amount <= 0) {
            tvStatus.text = "Nominal tidak valid."
            return
        }
        if (category.isEmpty()) {
            tvStatus.text = "Kategori tidak boleh kosong."
            return
        }
        // Validasi tanggal via parser
        val check = AiTransactionParser.parse(
            """{"amount":$amount,"category":"$category","date":"$date"}"""
        )
        if (check.isFailure) {
            tvStatus.text = "Tanggal tidak valid (gunakan YYYY-MM-DD)."
            return
        }

        val result = TransactionResult(amount, category, date)
        // Panggil callback; penyimpanan dilakukan oleh caller, bukan di sini
        onSave?.invoke(result)

        // Reset UI
        cardConfirmation.visibility = View.GONE
        etInput.text?.clear()
        tvStatus.text = "Tersimpan."
    }

    private fun cancelConfirmation() {
        cardConfirmation.visibility = View.GONE
        tvStatus.text = "Dibatalkan."
        onCancel?.invoke()
    }

    private fun setLoading(loading: Boolean) {
        progress.visibility = if (loading) View.VISIBLE else View.GONE
        btnParse.isEnabled = !loading
        etInput.isEnabled = !loading
    }

    private fun getTodayString(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    fun onDestroy() {
        scope.cancel()
    }
}
