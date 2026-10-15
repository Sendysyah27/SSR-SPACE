package com.ssr.space.ssr_space.ai

import org.json.JSONObject

/**
 * Hasil parsing transaksi dari output LLM.
 * @param amount Jumlah dalam satuan terkecil (misalnya rupiah).
 * @param category Kategori transaksi (misalnya "Makanan", "Transportasi").
 * @param date Tanggal format YYYY-MM-DD.
 */
data class TransactionResult(
    val amount: Long,
    val category: String,
    val date: String,
)

/**
 * Parser untuk output LLM yang wajib JSON:
 * {"amount":Long,"category":String,"date":"YYYY-MM-DD"}
 *
 * Validasi ketat:
 * - amount harus Long (bukan String, bukan Double)
 * - category harus String tidak kosong
 * - date harus format YYYY-MM-DD yang valid
 * - Semua field wajib ada
 *
 * Invalid -> Result.failure(AiFailure.InvalidResponse), TIDAK throw/crash.
 */
object AiTransactionParser {
    /** Regex untuk validasi tanggal YYYY-MM-DD. */
    private val DATE_REGEX = Regex("^\\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])$")

    /**
     * Parse JSON string menjadi TransactionResult.
     * @param json JSON string dari LLM.
     * @return Result<TransactionResult> sukses atau AiFailure.InvalidResponse.
     */
    fun parse(json: String): Result<TransactionResult> {
        return try {
            val obj = JSONObject(json.trim())

            // Validasi: semua field wajib ada
            if (!obj.has("amount")) {
                return Result.failure(AiFailure.InvalidResponse("field 'amount' hilang"))
            }
            if (!obj.has("category")) {
                return Result.failure(AiFailure.InvalidResponse("field 'category' hilang"))
            }
            if (!obj.has("date")) {
                return Result.failure(AiFailure.InvalidResponse("field 'date' hilang"))
            }

            // Validasi amount: harus Long (tolak Double/String)
            val amount = try {
                // JSONObject.getLong akan throw jika bukan number
                // Tapi kita perlu pastikan bukan Double
                val raw = obj.get("amount")
                when (raw) {
                    is Long -> raw
                    is Int -> raw.toLong()
                    // JSONObject kadang parse number sebagai Int/Long
                    // Tolak Double dan String secara eksplisit
                    is Double -> return Result.failure(
                        AiFailure.InvalidResponse("'amount' harus Long, bukan desimal")
                    )
                    is String -> return Result.failure(
                        AiFailure.InvalidResponse("'amount' harus Long, bukan String")
                    )
                    else -> return Result.failure(
                        AiFailure.InvalidResponse("'amount' tipe tidak didukung")
                    )
                }
            } catch (_: Exception) {
                return Result.failure(AiFailure.InvalidResponse("'amount' bukan angka valid"))
            }

            // Validasi category: String tidak kosong
            val category = obj.optString("category", "").trim()
            if (category.isEmpty()) {
                return Result.failure(AiFailure.InvalidResponse("'category' kosong"))
            }

            // Validasi date: format YYYY-MM-DD
            val date = obj.optString("date", "").trim()
            if (!DATE_REGEX.matches(date)) {
                return Result.failure(
                    AiFailure.InvalidResponse("'date' harus format YYYY-MM-DD, dapat: '$date'")
                )
            }
            // Validasi tambahan: tanggal harus valid (misalnya tidak ada 2026-02-30)
            if (!isValidDate(date)) {
                return Result.failure(AiFailure.InvalidResponse("'date' bukan tanggal valid: '$date'"))
            }

            Result.success(TransactionResult(amount, category, date))
        } catch (e: Exception) {
            // JSON rusak atau error lain -> failure, jangan crash
            Result.failure(AiFailure.InvalidResponse("JSON rusak: ${e.message}"))
        }
    }

    /**
     * Validasi tanggal benar-benar ada di kalender.
     * Misalnya 2026-02-30 tidak valid.
     */
    private fun isValidDate(date: String): Boolean {
        return try {
            val parts = date.split("-")
            val year = parts[0].toInt()
            val month = parts[1].toInt()
            val day = parts[2].toInt()
            // Validasi sederhana: cek hari maksimal per bulan
            val maxDay = when (month) {
                1, 3, 5, 7, 8, 10, 12 -> 31
                4, 6, 9, 11 -> 30
                2 -> if (isLeapYear(year)) 29 else 28
                else -> return false
            }
            day in 1..maxDay
        } catch (_: Exception) {
            false
        }
    }

    private fun isLeapYear(year: Int): Boolean {
        return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }
}
