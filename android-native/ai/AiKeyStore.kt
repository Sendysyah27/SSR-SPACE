package com.ssr.space.ssr_space.ai

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Penyimpanan aman untuk API key AI menggunakan Android Keystore bawaan.
 *
 * TANPA dependency tambahan (tidak pakai security-crypto).
 *
 * Cara kerja:
 * - Buat key AES-256 di AndroidKeyStore (alias "ai_key_wrap")
 *   KeyGenParameterSpec: GCM, NoPadding, tanpa auth user
 * - save(key): enkripsi AES/GCM/NoPadding, simpan IV + ciphertext (Base64)
 *   di SharedPreferences MODE_PRIVATE
 * - load(): dekripsi; kalau gagal (key hilang/rusak) -> return null, JANGAN crash
 * - clear(): hapus ciphertext
 *
 * Key TIDAK BOLEH muncul di log.
 */
class AiKeyStore(context: Context) {

    companion object {
        private const val PREFS_NAME = "ai_key_prefs"
        private const val KEY_API_KEY = "api_key_enc"  // ciphertext Base64
        private const val KEY_MODEL_ID = "model_id"

        /** Alias key di AndroidKeyStore. */
        private const val KEYSTORE_ALIAS = "ai_key_wrap"

        /** Provider AndroidKeyStore. */
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"

        /** Transformasi cipher. */
        private const val TRANSFORMATION = "AES/GCM/NoPadding"

        /** Ukuran IV GCM (12 bytes) dan tag (128 bit). */
        private const val GCM_IV_LENGTH = 12
        private const val GCM_TAG_LENGTH = 128

        /** Default model ID jika belum diset. */
        const val DEFAULT_MODEL_ID = "muse-spark-1.3-contributor-free"
    }

    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // ========================================================================
    // Public interface (JANGAN DIUBAH)
    // ========================================================================

    /**
     * Simpan API key (terenkripsi).
     * @param apiKey Key yang akan disimpan. Kosong/null akan diabaikan.
     */
    fun saveApiKey(apiKey: String) {
        if (apiKey.isBlank()) return
        // JANGAN log apiKey!
        try {
            val encrypted = encrypt(apiKey.trim())
            if (encrypted != null) {
                prefs.edit().putString(KEY_API_KEY, encrypted).apply()
            }
            // Jika encrypt gagal, jangan simpan apa-apa (fail closed)
        } catch (_: Exception) {
            // JANGAN log detail yang mungkin mengandung key
        }
    }

    /**
     * Ambil API key (dekripsi).
     * @return API key atau null jika belum diset / gagal dekripsi.
     */
    fun getApiKey(): String? {
        return try {
            val encrypted = prefs.getString(KEY_API_KEY, null) ?: return null
            decrypt(encrypted)
            // decrypt return null jika gagal -> JANGAN crash
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Cek apakah API key sudah diset.
     */
    fun hasApiKey(): Boolean = getApiKey() != null

    /**
     * Hapus API key (ciphertext).
     */
    fun clearApiKey() {
        prefs.edit().remove(KEY_API_KEY).apply()
    }

    /**
     * Simpan model ID (tidak sensitif, plaintext ok).
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

    // ========================================================================
    // Internal: Android Keystore crypto
    // ========================================================================

    /**
     * Ambil atau buat SecretKey AES-256 di AndroidKeyStore.
     * @return SecretKey atau null jika gagal.
     */
    private fun getOrCreateKey(): SecretKey? {
        return try {
            val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            // Cek apakah key sudah ada
            (ks.getEntry(KEYSTORE_ALIAS, null) as? KeyStore.SecretKeyEntry)?.secretKey
                ?: createKey()
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Buat key AES-256 baru di AndroidKeyStore.
     */
    private fun createKey(): SecretKey? {
        return try {
            // AndroidKeyStore membutuhkan API 23+ untuk KeyGenParameterSpec
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                return null
            }
            val keyGen = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE
            )
            val spec = KeyGenParameterSpec.Builder(
                KEYSTORE_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                // Tanpa user authentication (agar bisa dipakai background)
                .setUserAuthenticationRequired(false)
                // Key tidak diekspor
                .build()
            keyGen.init(spec)
            keyGen.generateKey()
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Enkripsi plaintext dengan AES/GCM/NoPadding.
     * @return Base64(IV + ciphertext) atau null jika gagal.
     */
    private fun encrypt(plaintext: String): String? {
        return try {
            val key = getOrCreateKey() ?: return null
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val iv = cipher.iv  // 12 bytes untuk GCM
            val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
            // Gabung IV + ciphertext, encode Base64
            val combined = ByteBuffer.allocate(iv.size + ciphertext.size)
                .put(iv)
                .put(ciphertext)
                .array()
            Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Dekripsi Base64(IV + ciphertext).
     * @return plaintext atau null jika gagal (key hilang/rusak).
     * JANGAN throw, JANGAN crash.
     */
    private fun decrypt(encryptedB64: String): String? {
        return try {
            val key = getOrCreateKey() ?: return null
            val combined = Base64.decode(encryptedB64, Base64.NO_WRAP)
            if (combined.size < GCM_IV_LENGTH + 1) return null
            val iv = combined.copyOfRange(0, GCM_IV_LENGTH)
            val ciphertext = combined.copyOfRange(GCM_IV_LENGTH, combined.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, key, spec)
            val plaintext = cipher.doFinal(ciphertext)
            String(plaintext, Charsets.UTF_8)
        } catch (_: Exception) {
            // Key hilang, data rusak, atau IV invalid -> return null, JANGAN crash
            null
        }
    }
}
