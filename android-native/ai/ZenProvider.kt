package com.ssr.space.ssr_space.ai

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Implementasi AiProvider untuk OpenCode Zen API.
 * Endpoint: POST {baseUrl}/chat/completions
 * Format: OpenAI chat completions (model, messages).
 * Header: Authorization: Bearer <apiKey>.
 *
 * Error mapping:
 * - HTTP 429 -> AiFailure.RateLimited
 * - HTTP 404 -> AiFailure.ModelUnavailable
 * - HTTP 401 -> AiFailure.InvalidKey
 * - Timeout/Network -> AiFailure.NetworkError
 *
 * Retry: maksimal 1x dengan backoff (hanya untuk 429 dan network error).
 */
class ZenProvider(
    private val config: AiConfig,
) : AiProvider {

    companion object {
        /** Delay backoff untuk retry (ms). */
        private const val BACKOFF_MS = 1_000L
    }

    override suspend fun complete(prompt: String): Result<String> =
        withContext(Dispatchers.IO) {
            // Mask data sensitif sebelum kirim
            val maskedPrompt = DataMasker.mask(prompt)

            var lastError: Throwable? = null
            // Attempt 0 = percobaan pertama, attempt 1 = retry
            for (attempt in 0..config.maxRetries) {
                try {
                    val result = doRequest(maskedPrompt)
                    return@withContext result
                } catch (e: AiFailure.RateLimited) {
                    // 429 boleh retry sekali dengan backoff
                    lastError = e
                    if (attempt < config.maxRetries) {
                        delay(BACKOFF_MS * (attempt + 1))
                    }
                } catch (e: AiFailure.NetworkError) {
                    // Network error boleh retry sekali
                    lastError = e
                    if (attempt < config.maxRetries) {
                        delay(BACKOFF_MS * (attempt + 1))
                    }
                } catch (e: AiFailure) {
                    // Failure lain (401, 404, invalid) langsung return, tanpa retry
                    return@withContext Result.failure(e)
                } catch (e: Exception) {
                    return@withContext Result.failure(AiFailure.Unknown(e.message ?: "Unknown error"))
                }
            }
            Result.failure(lastError ?: AiFailure.Unknown("Gagal setelah retry"))
        }

    /**
     * Lakukan satu HTTP request ke Zen API.
     * @throws AiFailure jika HTTP error atau parsing gagal.
     */
    private fun doRequest(maskedPrompt: String): Result<String> {
        val url = URL("${config.baseUrl}/chat/completions")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = config.timeoutMs
            readTimeout = config.timeoutMs
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Authorization", "Bearer ${config.apiKey}")
        }

        try {
            // Body: format OpenAI chat completions
            val body = JSONObject().apply {
                put("model", config.modelId)
                put("messages", JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", maskedPrompt)
                    })
                })
            }

            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(body.toString())
                writer.flush()
            }

            val code = conn.responseCode
            when (code) {
                200 -> {
                    val responseText = readStream(conn)
                    return parseCompletion(responseText)
                }
                429 -> throw AiFailure.RateLimited()
                404 -> throw AiFailure.ModelUnavailable()
                401 -> throw AiFailure.InvalidKey()
                else -> {
                    val errBody = readErrorStream(conn)
                    throw AiFailure.Unknown("HTTP $code: ${errBody.take(200)}")
                }
            }
        } finally {
            conn.disconnect()
        }
    }

    /** Baca response body dari input stream. */
    private fun readStream(conn: HttpURLConnection): String {
        BufferedReader(InputStreamReader(conn.inputStream, Charsets.UTF_8)).use { reader ->
            return reader.readText()
        }
    }

    /** Baca error body (jika ada). */
    private fun readErrorStream(conn: HttpURLConnection): String {
        return try {
            conn.errorStream?.let { stream ->
                BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
            } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    /**
     * Parse OpenAI chat completion response.
     * Ambil choices[0].message.content.
     */
    private fun parseCompletion(json: String): Result<String> {
        return try {
            val root = JSONObject(json)
            val choices = root.optJSONArray("choices")
                ?: return Result.failure(AiFailure.InvalidResponse("tidak ada 'choices'"))
            if (choices.length() == 0) {
                return Result.failure(AiFailure.InvalidResponse("'choices' kosong"))
            }
            val content = choices.getJSONObject(0)
                .optJSONObject("message")
                ?.optString("content")
                ?: return Result.failure(AiFailure.InvalidResponse("tidak ada 'message.content'"))
            Result.success(content)
        } catch (e: Exception) {
            Result.failure(AiFailure.InvalidResponse("JSON rusak: ${e.message}"))
        }
    }
}
