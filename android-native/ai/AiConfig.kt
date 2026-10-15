package com.ssr.space.ssr_space.ai

/**
 * Konfigurasi AI.
 * Model ID dan API key TIDAK di-hardcode — dibaca dari sumber eksternal
 * (misalnya SharedPreferences, BuildConfig, atau secure storage).
 */
data class AiConfig(
    /** Model ID, misalnya "muse-spark-1.3-contributor-free". */
    val modelId: String,
    /** API key untuk Authorization header. */
    val apiKey: String,
    /** Base URL, default ke OpenCode Zen. */
    val baseUrl: String = "https://opencode.ai/zen/v1",
    /** Timeout dalam milidetik (default 10 detik). */
    val timeoutMs: Int = 10_000,
    /** Maksimal retry (default 1x). */
    val maxRetries: Int = 1,
) {
    init {
        require(modelId.isNotBlank()) { "modelId tidak boleh kosong" }
        require(apiKey.isNotBlank()) { "apiKey tidak boleh kosong" }
    }
}
