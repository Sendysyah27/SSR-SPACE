package com.ssr.space.ssr_space.ai

/**
 * Classifier transaksi dengan alur:
 * 1. Cek cache (merchant/keyword) -> return jika hit
 * 2. Coba regex -> return jika match, simpan ke cache
 * 3. Fallback ke LLM (AiProvider) -> parse JSON, simpan ke cache
 *
 * LLM hanya dipanggil kalau regex gagal.
 */
class AiTransactionClassifier(
    private val provider: AiProvider,
    private val cache: AiCategoryCache = AiCategoryCache(),
    /** Daftar regex kategori: Pair<Regex, Category>. */
    private val regexRules: List<Pair<Regex, String>> = defaultRegexRules(),
) {
    companion object {
        /**
         * Aturan regex default untuk kategori umum Indonesia.
         * Bisa di-override via constructor.
         */
        fun defaultRegexRules(): List<Pair<Regex, String>> = listOf(
            // Makanan
            Regex("(?i)\\b(warteg|warung|restoran|rm\\b|kafe|kopi|makan|kuliner|soto|bakso|mie|ayam|padang|sate)\\b") to "Makanan",
            // Transportasi
            Regex("(?i)\\b(gojek|grab|ojek|taksi|bensin|bensin|parkir|tol|kereta|busway|transjakarta|mrt)\\b") to "Transportasi",
            // Belanja
            Regex("(?i)\\b(indomaret|alfamart|superindo|hypermart|mall|belanja|market|store|shop)\\b") to "Belanja",
            // Tagihan
            Regex("(?i)\\b(pln|pdam|listrik|air|internet|wifi|pulsa|token|bpjs|pajak)\\b") to "Tagihan",
            // Kesehatan
            Regex("(?i)\\b(rumah sakit|rs\\b|klinik|apotek|dokter|obat|puskesmas)\\b") to "Kesehatan",
            // Pendidikan
            Regex("(?i)\\b(sekolah|kampus|kuliah|kursus|buku|spp|ukt)\\b") to "Pendidikan",
            // Hiburan
            Regex("(?i)\\b(bioskop|nonton|game|netflix|spotify|karaoke|tiket)\\b") to "Hiburan",
        )
    }

    /**
     * Klasifikasikan merchant ke kategori.
     * @param merchant Nama merchant atau deskripsi transaksi.
     * @return Result<String> kategori, atau AiFailure jika semua gagal.
     */
    suspend fun classify(merchant: String): Result<String> {
        val trimmed = merchant.trim()
        if (trimmed.isEmpty()) {
            return Result.failure(AiFailure.InvalidResponse("merchant kosong"))
        }

        // 1. Cek cache dulu
        cache.get(trimmed)?.let { return Result.success(it) }

        // 2. Coba regex
        for ((regex, category) in regexRules) {
            if (regex.containsMatchIn(trimmed)) {
                cache.put(trimmed, category)
                return Result.success(category)
            }
        }

        // 3. Fallback ke LLM
        val prompt = buildPrompt(trimmed)
        val llmResult = provider.complete(prompt)
        if (llmResult.isFailure) {
            return Result.failure(llmResult.exceptionOrNull() ?: AiFailure.Unknown("LLM gagal"))
        }

        val parsed = AiTransactionParser.parse(llmResult.getOrThrow())
        if (parsed.isFailure) {
            return Result.failure(parsed.exceptionOrNull() ?: AiFailure.InvalidResponse("parse gagal"))
        }

        val category = parsed.getOrThrow().category
        cache.put(trimmed, category)
        return Result.success(category)
    }

    /**
     * Bangun prompt untuk LLM.
     * Minta output JSON ketat.
     */
    private fun buildPrompt(merchant: String): String {
        // DataMasker.mask sudah dipanggil di ZenProvider, tapi kita mask juga di sini
        // untuk provider lain yang mungkin tidak mask.
        val safe = DataMasker.mask(merchant)
        return """
            Klasifikasikan merchant berikut ke salah satu kategori:
            Makanan, Transportasi, Belanja, Tagihan, Kesehatan, Pendidikan, Hiburan, Tabungan, Lainnya.

            Merchant: "$safe"

            Jawab HANYA dengan JSON valid, tanpa penjelasan:
            {"amount":0,"category":"<kategori>","date":"2026-10-15"}
        """.trimIndent()
    }
}
