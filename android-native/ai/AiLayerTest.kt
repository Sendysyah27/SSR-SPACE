package com.ssr.space.ssr_space.ai

import kotlinx.coroutines.runBlocking

/**
 * Unit test untuk lapisan AI.
 * Dijalankan via: kotlinc + java, atau Android Studio.
 *
 * Test cases (sesuai permintaan):
 * - FakeAiProvider: sukses
 * - FakeAiProvider: 429 (RateLimited)
 * - FakeAiProvider: 401 (InvalidKey)
 * - FakeAiProvider: model hilang (ModelUnavailable)
 * - AiTransactionParser: JSON rusak
 * - AiTransactionParser: JSON kurang field
 * - DataMasker: nomor panjang di-mask
 * - AiCategoryCache: put/get/normalisasi
 * - AiTransactionClassifier: regex hit (tanpa panggil LLM)
 * - AiTransactionClassifier: regex miss -> LLM dipanggil
 * - AiTransactionClassifier: cache hit (LLM tidak dipanggil 2x)
 */

private var passed = 0
private var failed = 0

private fun check(name: String, condition: Boolean) {
    if (condition) {
        passed++
        println("  PASS: $name")
    } else {
        failed++
        println("  FAIL: $name")
    }
}

fun main() = runBlocking {
    println("=== AI Layer Unit Tests ===\n")

    testFakeSukses()
    testFake429()
    testFake401()
    testFakeModelHilang()
    testParserJsonRusak()
    testParserJsonKurangField()
    testParserSukses()
    testParserAmountBukanLong()
    testParserTanggalInvalid()
    testDataMasker()
    testCache()
    testClassifierRegexHit()
    testClassifierLlmFallback()
    testClassifierCacheHit()

    println("\n=== Hasil: $passed lulus, $failed gagal ===")
    if (failed > 0) {
        println("ADA TEST GAGAL!")
        kotlin.system.exitProcess(1)
    } else {
        println("SEMUA TEST LULUS!")
    }
}

// --- FakeAiProvider tests ---

private suspend fun testFakeSukses() {
    println("[Fake] sukses")
    val fake = FakeAiProvider()
    val result = fake.complete("halo")
    check("result sukses", result.isSuccess)
    check("callCount=1", fake.callCount == 1)
    check("prompt tersimpan", fake.lastPrompt == "halo")
}

private suspend fun testFake429() {
    println("[Fake] 429 RateLimited")
    val fake = FakeAiProvider(fakeError = AiFailure.RateLimited())
    val result = fake.complete("halo")
    check("result failure", result.isFailure)
    check("error adalah RateLimited", result.exceptionOrNull() is AiFailure.RateLimited)
}

private suspend fun testFake401() {
    println("[Fake] 401 InvalidKey")
    val fake = FakeAiProvider(fakeError = AiFailure.InvalidKey())
    val result = fake.complete("halo")
    check("result failure", result.isFailure)
    check("error adalah InvalidKey", result.exceptionOrNull() is AiFailure.InvalidKey)
}

private suspend fun testFakeModelHilang() {
    println("[Fake] 404 ModelUnavailable")
    val fake = FakeAiProvider(fakeError = AiFailure.ModelUnavailable())
    val result = fake.complete("halo")
    check("result failure", result.isFailure)
    check("error adalah ModelUnavailable", result.exceptionOrNull() is AiFailure.ModelUnavailable)
}

// --- AiTransactionParser tests ---

private fun testParserJsonRusak() {
    println("[Parser] JSON rusak")
    val result = AiTransactionParser.parse("{ini bukan json")
    check("result failure", result.isFailure)
    check("error adalah InvalidResponse", result.exceptionOrNull() is AiFailure.InvalidResponse)
}

private fun testParserJsonKurangField() {
    println("[Parser] JSON kurang field")
    // Kurang 'date'
    val result = AiTransactionParser.parse("""{"amount":50000,"category":"Makanan"}""")
    check("result failure", result.isFailure)
    val err = result.exceptionOrNull() as? AiFailure.InvalidResponse
    check("error menyebut 'date'", err?.message?.contains("date") == true)

    // Kurang 'amount'
    val r2 = AiTransactionParser.parse("""{"category":"Makanan","date":"2026-10-15"}""")
    check("kurang amount -> failure", r2.isFailure)

    // Kurang 'category'
    val r3 = AiTransactionParser.parse("""{"amount":50000,"date":"2026-10-15"}""")
    check("kurang category -> failure", r3.isFailure)
}

private fun testParserSukses() {
    println("[Parser] sukses")
    val result = AiTransactionParser.parse(
        """{"amount":75000,"category":"Transportasi","date":"2026-10-15"}"""
    )
    check("result sukses", result.isSuccess)
    val tx = result.getOrNull()
    check("amount=75000", tx?.amount == 75000L)
    check("category=Transportasi", tx?.category == "Transportasi")
    check("date=2026-10-15", tx?.date == "2026-10-15")
}

private fun testParserAmountBukanLong() {
    println("[Parser] amount bukan Long")
    // amount sebagai String
    val r1 = AiTransactionParser.parse(
        """{"amount":"50000","category":"Makanan","date":"2026-10-15"}"""
    )
    check("amount String -> failure", r1.isFailure)

    // amount sebagai Double
    val r2 = AiTransactionParser.parse(
        """{"amount":50000.5,"category":"Makanan","date":"2026-10-15"}"""
    )
    check("amount Double -> failure", r2.isFailure)
}

private fun testParserTanggalInvalid() {
    println("[Parser] tanggal invalid")
    // Format salah
    val r1 = AiTransactionParser.parse(
        """{"amount":50000,"category":"Makanan","date":"15-10-2026"}"""
    )
    check("format DD-MM-YYYY -> failure", r1.isFailure)

    // Tanggal tidak ada di kalender
    val r2 = AiTransactionParser.parse(
        """{"amount":50000,"category":"Makanan","date":"2026-02-30"}"""
    )
    check("2026-02-30 -> failure", r2.isFailure)

    // Bulan 13
    val r3 = AiTransactionParser.parse(
        """{"amount":50000,"category":"Makanan","date":"2026-13-01"}"""
    )
    check("bulan 13 -> failure", r3.isFailure)
}

// --- DataMasker tests ---

private fun testDataMasker() {
    println("[Masker] nomor panjang")
    val masked = DataMasker.mask("Transfer ke 1234567890 sebesar 50000")
    check("10 digit di-mask", !masked.contains("1234567890"))
    check("placeholder ada", masked.contains("[MASKED]"))
    check("angka pendek tidak di-mask", masked.contains("50000"))

    val clean = DataMasker.mask("Bayar 50000 untuk makan")
    check("tidak ada nomor panjang -> tidak berubah", clean == "Bayar 50000 untuk makan")
}

// --- AiCategoryCache tests ---

private fun testCache() {
    println("[Cache] put/get")
    val cache = AiCategoryCache()
    cache.put("Indomaret", "Belanja")
    check("get hit", cache.get("Indomaret") == "Belanja")
    check("case insensitive", cache.get("indomaret") == "Belanja")
    check("whitespace trim", cache.get("  INDOMARET  ") == "Belanja")
    check("miss -> null", cache.get("TidakAda") == null)
    check("size=1", cache.size() == 1)
}

// --- AiTransactionClassifier tests ---

private suspend fun testClassifierRegexHit() {
    println("[Classifier] regex hit (LLM tidak dipanggil)")
    val fake = FakeAiProvider()
    val classifier = AiTransactionClassifier(fake)
    val result = classifier.classify("Belanja di Indomaret")
    check("result sukses", result.isSuccess)
    check("kategori=Belanja", result.getOrNull() == "Belanja")
    check("LLM TIDAK dipanggil", fake.callCount == 0)
}

private suspend fun testClassifierLlmFallback() {
    println("[Classifier] regex miss -> LLM dipanggil")
    val fake = FakeAiProvider(
        fakeResponse = """{"amount":0,"category":"Lainnya","date":"2026-10-15"}"""
    )
    val classifier = AiTransactionClassifier(fake)
    // "XYZ123" tidak match regex apapun -> fallback ke LLM
    val result = classifier.classify("XYZ123 Toko Aneh")
    check("result sukses", result.isSuccess)
    check("kategori dari LLM", result.getOrNull() == "Lainnya")
    check("LLM dipanggil 1x", fake.callCount == 1)
}

private suspend fun testClassifierCacheHit() {
    println("[Classifier] cache hit (LLM tidak dipanggil 2x)")
    val fake = FakeAiProvider(
        fakeResponse = """{"amount":0,"category":"Lainnya","date":"2026-10-15"}"""
    )
    val classifier = AiTransactionClassifier(fake)
    classifier.classify("XYZ999 Toko Unik")
    val firstCount = fake.callCount
    classifier.classify("XYZ999 Toko Unik") // harusnya dari cache
    check("LLM hanya dipanggil 1x total", fake.callCount == firstCount)
}
