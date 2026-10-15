package com.ssr.space.ssr_space.ai

import org.json.JSONObject

/**
 * Parser murni untuk wire format opencode serve (d verifikasi 1.18.9).
 *
 * Bentuk respons POST /session/{id}/message:
 * {"info":{"tokens":{"input":N,...},...},"parts":[
 *   {"type":"step-start",...},
 *   {"type":"reasoning","text":"...",...},   // DIABAIKAN
 *   {"type":"text","text":"..."},            // HANYA ini diambil
 *   {"type":"step-finish",...}]}
 *
 * Aturan:
 * - Ambil HANYA parts bertipe "text", gabung dengan newline.
 * - Abaikan reasoning/step-start/step-finish (isi reasoning bisa
 *   terenkripsi & besar — jangan pernah di-log).
 * - Jumlah token input dari info.tokens.input (bukan isi pesan).
 * - Terima juga envelope SSE ("data: {...}" per baris): gabung semua chunk.
 *
 * Murni (org.json + java.util saja) supaya bisa di-unit-test di JVM.
 */
object LocalOpenCodeParser {

    /** Hasil parse: teks gabungan + token input (-1 bila tak ada info). */
    data class ParsedResult(val text: String, val inputTokens: Int)

    /**
     * Parse body respons message (JSON biasa atau SSE).
     * @return teks gabungan, atau EmptyResponse bila tanpa part text,
     *   atau InvalidResponse bila JSON rusak.
     */
    fun parseResponseBody(body: String): Result<ParsedResult> {
        val chunks = splitChunks(body)
        if (chunks.isEmpty()) {
            return Result.failure(AiFailure.InvalidResponse("body kosong"))
        }
        val texts = mutableListOf<String>()
        var tokens = -1
        for (chunk in chunks) {
            val root = try {
                JSONObject(chunk)
            } catch (_: Exception) {
                return Result.failure(AiFailure.InvalidResponse("JSON rusak"))
            }
            collectTextParts(root, texts)
            readInputTokens(root)?.let { tokens = it }
        }
        val combined = texts.joinToString("\n").trim()
        if (combined.isEmpty()) {
            return Result.failure(AiFailure.EmptyResponse())
        }
        return Result.success(ParsedResult(combined, tokens))
    }

    /**
     * Parse session id dari POST /session.
     * Bentuk: {"id":"ses_...",...} (cadangan: {"session":{"id":...}}).
     */
    fun parseSessionId(json: String): Result<String> {
        return try {
            val root = JSONObject(json)
            val id = root.optString("id").ifEmpty { null }
                ?: root.optJSONObject("session")?.optString("id")?.ifEmpty { null }
            if (id.isNullOrEmpty()) {
                Result.failure(AiFailure.InvalidResponse("tanpa 'id' sesi"))
            } else {
                Result.success(id)
            }
        } catch (_: Exception) {
            Result.failure(AiFailure.InvalidResponse("JSON sesi rusak"))
        }
    }

    /**
     * Header Authorization basic auth (user selalu "opencode").
     * Password TIDAK PERNAH di-log di mana pun — hanya masuk header.
     */
    fun basicAuthHeader(password: String): String {
        val raw = "opencode:$password".toByteArray(Charsets.UTF_8)
        return "Basic " + java.util.Base64.getEncoder().encodeToString(raw)
    }

    // -- internal ----------------------------------------------------------

    /** Pecah SSE ("data: {...}") jadi chunk JSON; non-SSE = satu chunk. */
    private fun splitChunks(body: String): List<String> {
        val lines = body.lines()
        val dataLines = lines
            .map { it.trim() }
            .filter { it.startsWith("data:") }
            .map { it.removePrefix("data:").trim() }
            .filter { it.isNotEmpty() && it != "[DONE]" }
        if (dataLines.isNotEmpty()) return dataLines
        val trimmed = body.trim()
        return if (trimmed.isEmpty()) emptyList() else listOf(trimmed)
    }

    /** Kumpulkan .text dari parts bertipe "text" (root.parts atau root.message.parts). */
    private fun collectTextParts(root: JSONObject, out: MutableList<String>) {
        val parts = root.optJSONArray("parts")
            ?: root.optJSONObject("message")?.optJSONArray("parts")
            ?: return
        for (i in 0 until parts.length()) {
            val part = parts.optJSONObject(i) ?: continue
            if (part.optString("type") == "text") {
                val t = part.optString("text")
                if (t.isNotEmpty()) out.add(t)
            }
        }
    }

    /** Baca info.tokens.input (cadangan: info.input_tokens). Null bila tak ada. */
    private fun readInputTokens(root: JSONObject): Int? {
        val info = root.optJSONObject("info") ?: return null
        val tokens = info.optJSONObject("tokens")
        if (tokens != null && tokens.has("input")) {
            return tokens.optInt("input", -1).takeIf { it >= 0 }
        }
        if (info.has("input_tokens")) {
            return info.optInt("input_tokens", -1).takeIf { it >= 0 }
        }
        return null
    }
}
