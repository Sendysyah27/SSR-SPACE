package com.ssr.space.ssr_space.ai

/**
 * Cache hasil kategori per merchant/kata kunci.
 * Mengurangi panggilan LLM untuk merchant yang sudah pernah dikategorikan.
 *
 * Key dinormalisasi: lowercase + trim.
 * Thread-safe via synchronized.
 */
class AiCategoryCache(
    /** Kapasitas maksimal cache (default 500). */
    private val maxSize: Int = 500,
) {
    /** LinkedHashMap dengan access-order untuk LRU eviction. */
    private val cache = object : LinkedHashMap<String, String>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, String>?): Boolean {
            return size > maxSize
        }
    }

    /**
     * Normalisasi key: lowercase + trim + collapse whitespace.
     */
    private fun normalizeKey(merchant: String): String {
        return merchant.lowercase().trim().replace(Regex("\\s+"), " ")
    }

    /**
     * Ambil kategori dari cache.
     * @param merchant Nama merchant atau kata kunci.
     * @return Kategori jika ada di cache, null jika tidak.
     */
    @Synchronized
    fun get(merchant: String): String? {
        val key = normalizeKey(merchant)
        if (key.isEmpty()) return null
        return cache[key]
    }

    /**
     * Simpan kategori ke cache.
     * @param merchant Nama merchant atau kata kunci.
     * @param category Kategori hasil (dari regex atau LLM).
     */
    @Synchronized
    fun put(merchant: String, category: String) {
        val key = normalizeKey(merchant)
        if (key.isEmpty() || category.isBlank()) return
        cache[key] = category.trim()
    }

    /**
     * Cek apakah merchant ada di cache.
     */
    @Synchronized
    fun contains(merchant: String): Boolean {
        return get(merchant) != null
    }

    /**
     * Hapus semua isi cache.
     */
    @Synchronized
    fun clear() {
        cache.clear()
    }

    /**
     * Jumlah entry di cache.
     */
    @Synchronized
    fun size(): Int = cache.size
}
