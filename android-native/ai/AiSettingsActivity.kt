package com.ssr.space.ssr_space.ai

import android.os.Bundle
import android.text.InputType
import android.text.method.LinkMovementMethod
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.text.HtmlCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Layar Pengaturan AI.
 *
 * Fitur:
 * - Input API key (masked dengan inputType password)
 * - Input model ID (default dari AiKeyStore.DEFAULT_MODEL_ID)
 * - Tombol "Tes koneksi": kirim prompt "balas: ok"
 * - Tombol "Hapus key"
 * - Link "Dapatkan key di opencode.ai/auth"
 *
 * Keamanan:
 * - Key TIDAK PERNAH di-log
 * - Key disimpan di EncryptedSharedPreferences
 * - Key tidak ikut backup (via backup rules)
 */
class AiSettingsActivity : AppCompatActivity() {

    private lateinit var keyStore: AiKeyStore
    private lateinit var etApiKey: EditText
    private lateinit var etModelId: EditText
    private lateinit var btnSave: Button
    private lateinit var btnTest: Button
    private lateinit var btnDelete: Button
    private lateinit var tvStatus: TextView
    private lateinit var tvLink: TextView
    private lateinit var progress: ProgressBar

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        keyStore = AiKeyStore(this)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 48, 48, 48)
        }

        // Judul
        root.addView(TextView(this).apply {
            text = "Pengaturan AI"
            textSize = 22f
        })

        // Link dapatkan key
        tvLink = TextView(this).apply {
            text = HtmlCompat.fromHtml(
                "<a href=\"https://opencode.ai/auth\">Dapatkan key di opencode.ai/auth</a>",
                HtmlCompat.FROM_HTML_MODE_LEGACY
            )
            movementMethod = LinkMovementMethod.getInstance()
            setPadding(0, 16, 0, 24)
        }
        root.addView(tvLink)

        // Input API key (masked)
        root.addView(TextView(this).apply {
            text = "API Key"
            setPadding(0, 8, 0, 4)
        })
        etApiKey = EditText(this).apply {
            hint = "Masukkan API key"
            // Masked: tidak terlihat saat diketik
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        }
        root.addView(etApiKey)

        // Input Model ID
        root.addView(TextView(this).apply {
            text = "Model ID"
            setPadding(0, 16, 0, 4)
        })
        etModelId = EditText(this).apply {
            hint = AiKeyStore.DEFAULT_MODEL_ID
            inputType = InputType.TYPE_CLASS_TEXT
        }
        root.addView(etModelId)

        // Status
        tvStatus = TextView(this).apply {
            setPadding(0, 16, 0, 16)
        }
        root.addView(tvStatus)

        // Progress
        progress = ProgressBar(this).apply {
            visibility = View.GONE
        }
        root.addView(progress)

        // Tombol Simpan
        btnSave = Button(this).apply {
            text = "Simpan"
            setOnClickListener { saveKey() }
        }
        root.addView(btnSave)

        // Tombol Tes Koneksi
        btnTest = Button(this).apply {
            text = "Tes koneksi"
            setOnClickListener { testConnection() }
        }
        root.addView(btnTest)

        // Tombol Hapus
        btnDelete = Button(this).apply {
            text = "Hapus key"
            setOnClickListener { deleteKey() }
        }
        root.addView(btnDelete)

        setContentView(root)
        loadCurrent()
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        // Bersihkan input dari memori
        etApiKey.text?.clear()
    }

    /** Load key & model yang tersimpan (tampilkan masked). */
    private fun loadCurrent() {
        val hasKey = keyStore.hasApiKey()
        etApiKey.setText(if (hasKey) "••••••••••••••••" else "")
        etModelId.setText(keyStore.getModelId())
        tvStatus.text = if (hasKey) "Key tersimpan." else "Belum ada key."
        btnDelete.isEnabled = hasKey
    }

    /** Simpan key + model ID. */
    private fun saveKey() {
        val key = etApiKey.text.toString()
        // Jangan simpan placeholder
        if (key.isBlank() || key.startsWith("•")) {
            tvStatus.text = "Masukkan API key yang valid."
            return
        }
        // JANGAN log key!
        keyStore.saveApiKey(key)
        keyStore.saveModelId(etModelId.text.toString())
        // Bersihkan input setelah simpan
        etApiKey.text?.clear()
        loadCurrent()
        tvStatus.text = "Key tersimpan."
    }

    /** Hapus key. */
    private fun deleteKey() {
        keyStore.clearApiKey()
        etApiKey.text?.clear()
        loadCurrent()
        tvStatus.text = "Key dihapus."
    }

    /** Tes koneksi: kirim "balas: ok", tampilkan hasil. */
    private fun testConnection() {
        val config = keyStore.toAiConfig()
        if (config == null) {
            tvStatus.text = "Belum ada key. Simpan key dulu."
            return
        }

        setTesting(true)
        tvStatus.text = "Menghubungi AI..."

        scope.launch {
            val provider = ZenProvider(config)
            // JANGAN log prompt atau response yang mungkin mengandung key!
            val result = withContext(Dispatchers.IO) {
                provider.complete("balas: ok")
            }
            setTesting(false)

            result.fold(
                onSuccess = { response ->
                    // Tampilkan hanya awal response, jangan seluruhnya jika panjang
                    val preview = response.take(100)
                    tvStatus.text = "Sukses! AI membalas: $preview"
                },
                onFailure = { e ->
                    tvStatus.text = when (e) {
                        is AiFailure.InvalidKey -> "Key salah. Periksa kembali API key."
                        is AiFailure.RateLimited -> "Limit terlampaui. Coba lagi nanti."
                        is AiFailure.ModelUnavailable -> "Model tidak tersedia."
                        is AiFailure.NetworkError -> "Offline. Periksa koneksi internet."
                        else -> "Gagal: ${e.message}"
                    }
                    // JANGAN log e yang mungkin mengandung key!
                }
            )
        }
    }

    private fun setTesting(testing: Boolean) {
        progress.visibility = if (testing) View.VISIBLE else View.GONE
        btnTest.isEnabled = !testing
        btnSave.isEnabled = !testing
        btnDelete.isEnabled = !testing && keyStore.hasApiKey()
    }
}
