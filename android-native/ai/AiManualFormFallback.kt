package com.ssr.space.ssr_space.ai

import android.content.Context
import android.text.InputType
import android.util.AttributeSet
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Form manual sebagai fallback saat AI gagal.
 * Teks asli dari input cepat sudah terisi di kolom catatan,
 * jadi user tidak perlu ketik ulang.
 *
 * Dipakai saat:
 * - RateLimited (AI sibuk)
 * - Offline (NetworkError)
 * - ModelUnavailable
 * - Parse gagal
 */
class AiManualFormFallback @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
) : LinearLayout(context, attrs, defStyleAttr) {

    /** Callback saat user simpan dari form manual. */
    var onSave: ((TransactionResult) -> Unit)? = null

    /** Callback saat user batal. */
    var onCancel: (() -> Unit)? = null

    private lateinit var etAmount: EditText
    private lateinit var etCategory: EditText
    private lateinit var etDate: EditText
    private lateinit var etNote: EditText
    private lateinit var tvStatus: TextView

    init {
        orientation = VERTICAL
        buildUi()
    }

    private fun buildUi() {
        addView(TextView(context).apply {
            text = "Form Manual"
            textSize = 18f
            setPadding(0, 0, 0, 8)
        })

        addView(TextView(context).apply {
            text = "AI tidak tersedia. Isi manual:"
            textSize = 12f
            setPadding(0, 0, 0, 12)
        })

        // Nominal
        addView(TextView(context).apply { text = "Nominal" })
        etAmount = EditText(context).apply {
            hint = "Contoh: 18000"
            inputType = InputType.TYPE_CLASS_NUMBER
        }
        addView(etAmount)

        // Kategori
        addView(TextView(context).apply {
            text = "Kategori"
            setPadding(0, 8, 0, 0)
        })
        etCategory = EditText(context).apply {
            hint = "Contoh: Makanan"
            inputType = InputType.TYPE_CLASS_TEXT
        }
        addView(etCategory)

        // Tanggal
        addView(TextView(context).apply {
            text = "Tanggal (YYYY-MM-DD)"
            setPadding(0, 8, 0, 0)
        })
        etDate = EditText(context).apply {
            hint = "Contoh: 2026-10-15"
            inputType = InputType.TYPE_CLASS_TEXT
        }
        addView(etDate)

        // Catatan (terisi otomatis dari input asli)
        addView(TextView(context).apply {
            text = "Catatan"
            setPadding(0, 8, 0, 0)
        })
        etNote = EditText(context).apply {
            hint = "Catatan tambahan"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE
        }
        addView(etNote)

        tvStatus = TextView(context).apply {
            setPadding(0, 8, 0, 8)
        }
        addView(tvStatus)

        // Tombol
        val btnRow = LinearLayout(context).apply {
            orientation = HORIZONTAL
            setPadding(0, 8, 0, 0)
        }
        val btnSave = Button(context).apply {
            text = "Simpan"
            setOnClickListener { doSave() }
        }
        val btnCancel = Button(context).apply {
            text = "Batal"
            setOnClickListener {
                onCancel?.invoke()
            }
        }
        btnRow.addView(btnSave, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        btnRow.addView(btnCancel, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        addView(btnRow)
    }

    /**
     * Isi form dengan teks asli dari input cepat.
     * User tinggal lengkapi nominal/kategori/tanggal.
     */
    fun setPrefillText(text: String) {
        etNote.setText(text)
    }

    private fun doSave() {
        val amount = etAmount.text.toString().trim().toLongOrNull()
        if (amount == null || amount <= 0) {
            tvStatus.text = "Nominal tidak valid."
            return
        }
        val category = etCategory.text.toString().trim()
        if (category.isEmpty()) {
            tvStatus.text = "Kategori tidak boleh kosong."
            return
        }
        val date = etDate.text.toString().trim()
        // Validasi via parser
        val check = AiTransactionParser.parse(
            """{"amount":$amount,"category":"$category","date":"$date"}"""
        )
        if (check.isFailure) {
            tvStatus.text = "Tanggal tidak valid (gunakan YYYY-MM-DD)."
            return
        }

        onSave?.invoke(TransactionResult(amount, category, date))
        tvStatus.text = "Tersimpan."
    }

    /** Reset form. */
    fun clear() {
        etAmount.text?.clear()
        etCategory.text?.clear()
        etDate.text?.clear()
        etNote.text?.clear()
        tvStatus.text = ""
    }
}
