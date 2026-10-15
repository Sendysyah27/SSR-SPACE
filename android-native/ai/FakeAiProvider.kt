package com.ssr.space.ssr_space.ai

/**
 * Fake AiProvider untuk testing.
 * Bisa diset untuk return sukses atau simulasi error tertentu.
 */
class FakeAiProvider(
    /** Response yang akan dikembalikan jika mode sukses. */
    var fakeResponse: String = """{"amount":50000,"category":"Makanan","date":"2026-10-15"}""",
    /** Jika tidak null, complete() akan return failure ini. */
    var fakeError: AiFailure? = null,
) : AiProvider {
    /** Hitung berapa kali complete() dipanggil. */
    var callCount: Int = 0
        private set
    /** Simpan prompt terakhir yang diterima. */
    var lastPrompt: String? = null
        private set

    override suspend fun complete(prompt: String): Result<String> {
        callCount++
        lastPrompt = prompt
        fakeError?.let { return Result.failure(it) }
        return Result.success(fakeResponse)
    }

    /** Reset counter dan state. */
    fun reset() {
        callCount = 0
        lastPrompt = null
        fakeError = null
    }
}
