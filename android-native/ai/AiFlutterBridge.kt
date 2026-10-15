package com.ssr.space.ssr_space.ai

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Helper untuk integrasi AI dengan Flutter.
 *
 * MethodChannel: "ssr_space/ai"
 * Methods:
 * - "hasKey": return Boolean, apakah API key sudah diset
 * - "openSettings": buka AiSettingsActivity
 *
 * Di sisi Dart/Flutter:
 * - Panggil "hasKey" saat init
 * - Jika false: sembunyikan/disable fitur AI (jangan tampilkan error)
 * - Jika true: tampilkan fitur AI normal
 */
object AiFlutterBridge {
    const val CHANNEL = "ssr_space/ai"

    /**
     * Setup MethodChannel handler. Panggil dari MainActivity.onCreate.
     */
    fun setup(context: Context, channel: MethodChannel) {
        val keyStore = AiKeyStore(context.applicationContext)
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "hasKey" -> {
                    result.success(keyStore.hasApiKey())
                }
                "openSettings" -> {
                    try {
                        val intent = android.content.Intent(
                            context,
                            AiSettingsActivity::class.java
                        ).apply {
                            // Jika context bukan Activity, perlu flag ini
                            if (context !is android.app.Activity) {
                                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

/**
 * Helper untuk Dart: cek apakah fitur AI tersedia.
 * Gunakan ini di Flutter untuk hide/disable (bukan error).
 *
 * Contoh di Dart:
 * ```dart
 * final hasKey = await MethodChannel('ssr_space/ai').invokeMethod<bool>('hasKey') ?? false;
 * if (!hasKey) {
 *   // Sembunyikan tombol AI, jangan tampilkan error
 *   return SizedBox.shrink();
 * }
 * // Tampilkan fitur AI normal
 * ```
 */
