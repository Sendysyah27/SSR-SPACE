package com.ssr.space.ssr_space.ai

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit test untuk AiKeyStore dengan Android Keystore.
 *
 * Menggunakan Robolectric untuk shadow Android framework
 * (termasuk AndroidKeyStore).
 *
 * Test cases:
 * - save -> load mengembalikan key yang sama
 * - save -> hasApiKey true
 * - clear -> hasApiKey false, getApiKey null
 * - save kosong -> diabaikan
 * - data rusak -> getApiKey null (JANGAN crash)
 * - key tidak boleh muncul di log (verifikasi manual)
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class AiKeyStoreTest {

    private lateinit var context: Context
    private lateinit var keyStore: AiKeyStore

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        keyStore = AiKeyStore(context)
        // Bersihkan sebelum tiap test
        keyStore.clearApiKey()
    }

    @After
    fun teardown() {
        keyStore.clearApiKey()
    }

    @Test
    fun `save lalu load mengembalikan key yang sama`() {
        val original = "sk-test-key-12345"
        keyStore.saveApiKey(original)
        val loaded = keyStore.getApiKey()
        assertEquals(original, loaded)
    }

    @Test
    fun `hasApiKey true setelah save`() {
        assertFalse(keyStore.hasApiKey())
        keyStore.saveApiKey("test-key")
        assertTrue(keyStore.hasApiKey())
    }

    @Test
    fun `clear menghapus key`() {
        keyStore.saveApiKey("test-key")
        assertTrue(keyStore.hasApiKey())
        keyStore.clearApiKey()
        assertFalse(keyStore.hasApiKey())
        assertNull(keyStore.getApiKey())
    }

    @Test
    fun `save key kosong diabaikan`() {
        keyStore.saveApiKey("")
        assertFalse(keyStore.hasApiKey())
        keyStore.saveApiKey("   ")
        assertFalse(keyStore.hasApiKey())
    }

    @Test
    fun `save key dengan whitespace di-trim`() {
        keyStore.saveApiKey("  my-key  ")
        assertEquals("my-key", keyStore.getApiKey())
    }

    @Test
    fun `data rusak tidak crash, return null`() {
        // Simulasi: tulis data rusak langsung ke prefs
        val prefs = context.getSharedPreferences("ai_key_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("api_key_enc", "!!!bukan-base64-valid!!!").apply()

        // getApiKey harus return null, JANGAN throw
        val result = try {
            keyStore.getApiKey()
        } catch (e: Exception) {
            fail("getApiKey tidak boleh throw, tapi throw: ${e.message}")
            null
        }
        assertNull(result)
        assertFalse(keyStore.hasApiKey())
    }

    @Test
    fun `data terpotong tidak crash`() {
        val prefs = context.getSharedPreferences("ai_key_prefs", Context.MODE_PRIVATE)
        // Base64 valid tapi terlalu pendek (kurang dari IV length)
        prefs.edit().putString("api_key_enc", "YWI=").apply() // "ab" dalam Base64

        val result = keyStore.getApiKey()
        assertNull(result)
    }

    @Test
    fun `model ID default dan custom`() {
        // Default
        assertEquals(AiKeyStore.DEFAULT_MODEL_ID, keyStore.getModelId())
        // Custom
        keyStore.saveModelId("custom-model")
        assertEquals("custom-model", keyStore.getModelId())
        // Kosong -> default
        keyStore.saveModelId("")
        assertEquals(AiKeyStore.DEFAULT_MODEL_ID, keyStore.getModelId())
    }

    @Test
    fun `toAiConfig null jika belum ada key`() {
        assertNull(keyStore.toAiConfig())
        keyStore.saveApiKey("test-key")
        val config = keyStore.toAiConfig()
        assertNotNull(config)
        assertEquals("test-key", config?.apiKey)
    }

    @Test
    fun `toAiConfig pakai model ID tersimpan`() {
        keyStore.saveApiKey("test-key")
        keyStore.saveModelId("my-model")
        val config = keyStore.toAiConfig()
        assertEquals("my-model", config?.modelId)
    }

    @Test
    fun `key terenkripsi di storage (bukan plaintext)`() {
        val original = "sk-secret-12345"
        keyStore.saveApiKey(original)
        // Baca langsung dari prefs, pastikan bukan plaintext
        val prefs = context.getSharedPreferences("ai_key_prefs", Context.MODE_PRIVATE)
        val stored = prefs.getString("api_key_enc", null)
        assertNotNull(stored)
        // Stored value tidak boleh sama dengan original (harus terenkripsi)
        assertNotEquals(original, stored)
        // Stored value tidak boleh mengandung original
        assertFalse(stored!!.contains(original))
    }
}
