package com.ssr.space.ssr_space.ai

/**
 * Interface untuk AI provider.
 * Implementasi: ZenProvider (production), FakeAiProvider (testing).
 */
interface AiProvider {
    /**
     * Kirim prompt ke AI dan dapatkan response sebagai String.
     * @param prompt Prompt yang sudah di-mask (tidak ada data sensitif).
     * @return Result<String> berisi response, atau AiFailure jika gagal.
     */
    suspend fun complete(prompt: String): Result<String>
}

/**
 * Sealed class untuk semua kegagalan AI.
 * Setiap failure punya pesan yang user-friendly.
 */
sealed class AiFailure(message: String) : Exception(message) {
    /** HTTP 429 - Rate limit terlampaui. */
    class RateLimited : AiFailure("Model AI lagi sibuk, coba lagi sebentar.")

    /** HTTP 404 - Model tidak ditemukan. */
    class ModelUnavailable : AiFailure("Model AI tidak tersedia.")

    /** HTTP 401 - API key tidak valid. */
    class InvalidKey : AiFailure("Kunci AI tidak valid.")

    /** Network error atau timeout. */
    class NetworkError(cause: Throwable? = null) :
        AiFailure(buildNetworkMessage(cause))

    companion object {
        private fun buildNetworkMessage(cause: Throwable?): String {
            val msg = cause?.message ?: ""
            // Cleartext atau koneksi ditolak -> server lokal bermasalah
            if (msg.contains("Cleartext", ignoreCase = true) ||
                msg.contains("127.0.0.1", ignoreCase = true) ||
                msg.contains("localhost", ignoreCase = true) ||
                msg.contains("Connection refused", ignoreCase = true) ||
                msg.contains("Failed to connect", ignoreCase = true)) {
                return "Tidak bisa terhubung ke server lokal (cek Termux)."
            }
            return "Gagal terhubung ke AI."
        }
    }

    /** Response tidak valid atau parsing gagal. */
    class InvalidResponse(reason: String) :
        AiFailure("Response AI tidak valid: $reason")

    /** AI tidak mengembalikan part teks sama sekali. */
    class EmptyResponse :
        AiFailure("AI tidak mengembalikan teks.")

    /** Error tidak diketahui. */
    class Unknown(message: String) : AiFailure(message)
}
