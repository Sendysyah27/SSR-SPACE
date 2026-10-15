package com.ssr.space.ssr_space.ai

import android.content.Context
import android.content.SharedPreferences

/**
 * Penyimpanan untuk API key AI.
 *
 * CATATAN: Saat ini pakai SharedPreferences biasa (MODE_PRIVATE).
 * TODO: Upgrade ke EncryptedSharedPreferences jika dependency tersedia.
 *
 * Key TIDAK BOLEH:
 * - Muncul di log (jangan pernah log nilainya)
 * - Masuk crash report (jangan sertakan di custom keys)
 * - Ikut backup (diatur via backup rules)
 */
class AiKeyStore(context: Context) {

    companion object {
        private const val PREFS_NAME = "ai_key_prefs"
        private const val KEY_API_KEY = "api_key"
        private const val KEY_MODEL_ID = "model_id"

        /** Default model ID jika belum diset. */
        const val DEFAULT_MODEL_ID = "muse-spark-1.3-contributor-free"
    }

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Simpan API key.
     * @param apiKey Key yang akan disimpan. Kosong/null akan diabaikan.
     */
    fun saveApiKey(apiKey: String) {
        if (apiKey.isBlank()) return
        prefs.edit().putString(KEY_API_KEY, apiKey.trim()).apply()
    }

    /**
     * Ambil API key.
     * @return API key atau null jika belum diset.
     */
    fun getApiKey(): String? {
        return prefs.getString(KEY_API_KEY, null)?.takeIf { it.isNotBlank() }
    }

    /**
     * Cek apakah API key sudah diset.
     */
    fun hasApiKey(): Boolean = getApiKey() != null

    /**
     * Hapus API key.
     */
    fun clearApiKey() {
        prefs.edit().remove(KEY_API_KEY).apply()
    }

    /**
     * Simpan model ID.
     */
    fun saveModelId(modelId: String) {
        val id = modelId.trim().ifEmpty { DEFAULT_MODEL_ID }
        prefs.edit().putString(KEY_MODEL_ID, id).apply()
    }

    /**
     * Ambil model ID (default dari config jika belum diset).
     */
    fun getModelId(): String {
        return prefs.getString(KEY_MODEL_ID, DEFAULT_MODEL_ID) ?: DEFAULT_MODEL_ID
    }

    /**
     * Buat AiConfig dari key + model yang tersimpan.
     * @return AiConfig atau null jika key belum diset.
     */
    fun toAiConfig(): AiConfig? {
        val key = getApiKey() ?: return null
        return AiConfig(
            modelId = getModelId(),
            apiKey = key,
        )
    }
}
