package com.ssr.space.ssr_space.ai

import android.util.Base64
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.UnknownHostException

/**
 * Implementasi AiProvider untuk opencode serve LOKAL (Termux settling).
 *
 * Alur tiap permintaan (jangan pakai ulang sesi):
 * 1. POST {baseUrl}/session {} -> {"id":"ses_..."}
 * 2. POST {baseUrl}/session/{id}/message
 *    {parts:[{"type":"text","text":prompt}], system:...}
 *    -> {"info":{"tokens":{"input":N,...}},"parts":[...]}
 * 3. DELETE {baseUrl}/session/{id} (best-effort, di finally)
 *
 * Auth: basic auth user "opencode", password dari secure storage Dart
 * (diterima per-call via MethodChannel, TIDAK disimpan di native,
 * TIDAK PERNAH di-log).
 *
 * Identitas jujur: header User-Agent "SSR-SPACE LocalOpenCode/1.0".
 * DILARANG menyamar sebagai klien lain (tanpa header tiruan CLI).
 *
 * Error mapping:
 * - HTTP 401 -> AiFailure.InvalidKey (password salah)
 * - Koneksi ditolak/host tak dikenal -> AiFailure.NetworkError
 *   ("Jalankan opencode serve di Termux")
 * - Timeout 30 dtk -> AiFailure.NetworkError
 * - Tanpa part text -> AiFailure.EmptyResponse
 *
 * Tanpa retry (server lokal: gagal = konfigurasi, bukan sesaat).
 */
class LocalOpenCodeProvider(
    baseUrl: String,
    private val password: String,
    private val timeoutMs: Int = 30_000,
    private val systemPrompt: String = DEFAULT_SYSTEM,
) : AiProvider {

    companion object {
        private const val TAG = "LocalOpenCode"
        private const val USER_AGENT = "SSR-SPACE LocalOpenCode/1.0"

        /**
         * System prompt chat Mang AI (sama untuk semua request).
         *
         * Kontrak output WAJIB — balas HANYA satu objek JSON, tanpa
         * markdown fence, tanpa teks di luar JSON:
         * - Tanpa aksi: {"reply":"<teks untuk user>","action":null}
         * - Dengan aksi: {"reply":"...","action":{"type":"in|out|transfer",
         *   "amount":<integer>,"category":"...","wallet":"...","note":"..."}}
         * Aturan field:
         * - "reply": teks Bahasa Indonesia yang tampil ke user, ringkas.
         * - "action": null bila tidak ada transaksi yang perlu dicatat.
         * - "type": hanya "in" (masuk), "out" (keluar), atau "transfer".
         * - "amount": HARUS bilangan bulat > 0 dalam rupiah, tanpa
         *   titik/koma/pemisah (contoh: 16000). Jangan desimal, jangan string.
         * - "category": HARUS salah satu dari: Makanan, Transportasi,
         *   Belanja, Tagihan, Kesehatan, Pendidikan, Hiburan,
         *   Pulsa & Internet, Tabungan, Lainnya.
         * - "wallet": nama dompet persis seperti di DATA USER; bila tidak
         *   tahu, isi string kosong (aplikasi menolak aksi tanpa dompet).
         * - Jangan pakai tool. Jangan mengeksekusi apa pun sendiri;
         *   aplikasi yang menampilkan tombol konfirmasi ke user.
         */
        /** System prompt chat Mang AI (val biasa: butuh trimIndent). */
        val DEFAULT_SYSTEM = """
            Kamu asisten keuangan. Balas HANYA satu objek JSON, tanpa markdown fence, tanpa teks di luar JSON.
            Bentuk: {"reply":"<teks Bahasa Indonesia untuk user>","action":null} atau {"reply":"...","action":{"type":"in|out|transfer","amount":<bilangan bulat>,"category":"...","wallet":"...","note":"..."}}.
            Aturan: "action" null bila tidak ada transaksi yang perlu dicatat. "type" hanya in, out, atau transfer. "amount" HARUS bilangan bulat lebih dari 0 dalam rupiah tanpa titik/koma (contoh 16000); jangan desimal, jangan string. "category" HARUS salah satu dari: Makanan, Transportasi, Belanja, Tagihan, Kesehatan, Pendidikan, Hiburan, Pulsa & Internet, Tabungan, Lainnya. "wallet" adalah nama dompet persis seperti di DATA USER; bila tidak tahu isi "". Jangan pakai tool. Jangan mengeksekusi apa pun sendiri; aplikasi yang menampilkan tombol konfirmasi ke user.
            """.trimIndent()
    }

    private val base = baseUrl.trim().trimEnd('/')

    override suspend fun complete(prompt: String): Result<String> =
        withContext(Dispatchers.IO) {
            // Mask data sensitif sebelum kirim (konsisten dgn ZenProvider)
            val maskedPrompt = DataMasker.mask(prompt)
            var sessionId: String? = null
            try {
                sessionId = createSession()
                val parsed = sendMessage(sessionId, maskedPrompt)
                // Log HANYA jumlah token, bukan isi pesan/key
                Log.d(TAG, "tokens_in=${parsed.inputTokens}")
                Result.success(parsed.text)
            } catch (e: AiFailure) {
                Result.failure(e)
            } catch (e: Exception) {
                Result.failure(AiFailure.Unknown(e.message ?: "Unknown error"))
            } finally {
                sessionId?.let { deleteSession(it) }
            }
        }

    override suspend fun completeWithImage(
        prompt: String,
        imageBytes: ByteArray,
        mimeType: String
    ): Result<String> = completeWithImage(prompt, imageBytes, mimeType, systemPrompt)

    /**
     * Varian dengan system prompt kustom (mis. untuk scan struk).
     * Tools tetap dimatikan; format part gambar ikut skema FilePartInput
     * dari /doc opencode serve: {"type":"file","mime":...,"url":"data:..."}.
     */
    suspend fun completeWithImage(
        prompt: String,
        imageBytes: ByteArray,
        mimeType: String,
        system: String
    ): Result<String> = withContext(Dispatchers.IO) {
        val maskedPrompt = DataMasker.mask(prompt)
        var sessionId: String? = null
        try {
            sessionId = createSession()
            val parsed = sendMessageWithImage(sessionId, maskedPrompt, imageBytes, mimeType, system)
            Log.d(TAG, "tokens_in=${parsed.inputTokens}")
            Result.success(parsed.text)
        } catch (e: AiFailure) {
            Result.failure(e)
        } catch (e: Exception) {
            Result.failure(AiFailure.Unknown(e.message ?: "Unknown error"))
        } finally {
            sessionId?.let { deleteSession(it) }
        }
    }

    /**
     * POST /session/{id}/message dengan gambar (vision).
     * Part gambar ikut skema FilePartInput dari /doc opencode serve
     * (terverifikasi 2026-10-15):
     * {"type":"file","mime":"image/jpeg","url":"data:image/jpeg;base64,..."}.
     */
    private fun sendMessageWithImage(
        sessionId: String,
        maskedPrompt: String,
        imageBytes: ByteArray,
        mimeType: String,
        system: String,
    ): LocalOpenCodeParser.ParsedResult {
        val conn = open("POST", "$base/session/$sessionId/message")
        try {
            val base64Img = Base64.encodeToString(imageBytes, Base64.NO_WRAP)
            val body = JSONObject().apply {
                put("system", system)
                put("parts", JSONArray().apply {
                    put(JSONObject().apply {
                        put("type", "text")
                        put("text", maskedPrompt)
                    })
                    put(JSONObject().apply {
                        put("type", "file")
                        put("mime", mimeType)
                        put("url", "data:$mimeType;base64,$base64Img")
                    })
                })
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString())
                w.flush()
            }
            val code = conn.responseCode
            if (code == 401) throw AiFailure.InvalidKey()
            if (code < 200 || code >= 300) {
                throw AiFailure.Unknown("HTTP $code: ${readErr(conn).take(200)}")
            }
            return LocalOpenCodeParser.parseResponseBody(readOk(conn)).getOrThrow()
        } catch (e: AiFailure) {
            throw e
        } catch (e: Exception) {
            throw mapNetwork(e)
        } finally {
            conn.disconnect()
        }
    }

    // -- wire --------------------------------------------------------------

    /** POST /session -> id sesi. */
    private fun createSession(): String {
        val conn = open("POST", "$base/session")
        try {
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { w ->
                w.write("{}")
                w.flush()
            }
            val code = conn.responseCode
            if (code == 401) throw AiFailure.InvalidKey()
            if (code < 200 || code >= 300) {
                throw AiFailure.Unknown("HTTP $code: ${readErr(conn).take(200)}")
            }
            val id = LocalOpenCodeParser.parseSessionId(readOk(conn)).getOrNull()
                ?: throw AiFailure.InvalidResponse("tanpa 'id' sesi")
            return id
        } catch (e: AiFailure) {
            throw e
        } catch (e: Exception) {
            throw mapNetwork(e)
        } finally {
            conn.disconnect()
        }
    }

    /** POST /session/{id}/message -> ParsedResult (teks + token). */
    private fun sendMessage(
        sessionId: String,
        maskedPrompt: String,
    ): LocalOpenCodeParser.ParsedResult {
        val conn = open("POST", "$base/session/$sessionId/message")
        try {
            val body = JSONObject().apply {
                put("system", systemPrompt)
                put("parts", JSONArray().apply {
                    put(JSONObject().apply {
                        put("type", "text")
                        put("text", maskedPrompt)
                    })
                })
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { w ->
                w.write(body.toString())
                w.flush()
            }
            val code = conn.responseCode
            if (code == 401) throw AiFailure.InvalidKey()
            if (code < 200 || code >= 300) {
                throw AiFailure.Unknown("HTTP $code: ${readErr(conn).take(200)}")
            }
            val raw = readOk(conn)
            return LocalOpenCodeParser.parseResponseBody(raw).getOrElse { throw it }
        } catch (e: AiFailure) {
            throw e
        } catch (e: Exception) {
            throw mapNetwork(e)
        } finally {
            conn.disconnect()
        }
    }

    /** DELETE /session/{id}: best-effort, gagal = diam (sesi kedaluwarsa sendiri). */
    private fun deleteSession(sessionId: String) {
        try {
            val conn = open("DELETE", "$base/session/$sessionId")
            try {
                conn.responseCode
            } finally {
                conn.disconnect()
            }
        } catch (_: Exception) {
        }
    }

    /** Buka koneksi + header auth/UA/timeout. Tanpa body-key di mana pun. */
    private fun open(method: String, url: String): HttpURLConnection {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.requestMethod = method
        conn.connectTimeout = timeoutMs
        conn.readTimeout = timeoutMs
        conn.doOutput = method == "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("User-Agent", USER_AGENT)
        conn.setRequestProperty(
            "Authorization", LocalOpenCodeParser.basicAuthHeader(password)
        )
        return conn
    }

    private fun readOk(conn: HttpURLConnection): String {
        BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { r ->
            return r.readText()
        }
    }

    private fun readErr(conn: HttpURLConnection): String {
        return try {
            conn.errorStream?.let { s ->
                BufferedReader(InputStreamReader(s, Charsets.UTF_8)).use { it.readText() }
            } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    /** Petakan error jaringan ke AiFailure jujur (tanpa bocorkan password). */
    private fun mapNetwork(e: Exception): AiFailure {
        return when (e) {
            is SocketTimeoutException ->
                AiFailure.NetworkError(Exception("Timeout 30 detik, server lokal lambat/tak jawab"))
            is ConnectException, is UnknownHostException ->
                AiFailure.NetworkError(Exception("Jalankan opencode serve di Termux"))
            else -> AiFailure.NetworkError(e)
        }
    }
}
