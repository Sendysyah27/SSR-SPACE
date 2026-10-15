package com.ssr.space.ssr_space.ai

/**
 * Masker data sensitif sebelum dikirim ke AI.
 * Menghapus pola nomor panjang (>= 10 digit berurutan) untuk mencegah
 * kebocoran data seperti nomor rekening, nomor kartu, atau nomor HP.
 */
object DataMasker {
    /** Regex untuk nomor panjang: 10 digit atau lebih berurutan. */
    private val LONG_NUMBER = Regex("\\d{10,}")

    /** Placeholder untuk nomor yang di-mask. */
    const val MASK = "[MASKED]"

    /**
     * Mask semua nomor panjang (>= 10 digit) dalam teks.
     * @param text Teks asli yang mungkin mengandung nomor sensitif.
     * @return Teks dengan nomor panjang diganti [MASKED].
     */
    fun mask(text: String): String {
        return LONG_NUMBER.replace(text, MASK)
    }

    /**
     * Cek apakah teks mengandung nomor panjang.
     */
    fun containsLongNumber(text: String): Boolean {
        return LONG_NUMBER.containsMatchIn(text)
    }
}
