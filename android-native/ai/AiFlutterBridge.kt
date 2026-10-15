package com.ssr.space.ssr_space.ai

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Helper untuk integrasi AI dengan Flutter.
 *
 * MethodChannel: "ssr_space/ai"
 * Methods:
 * - "hasKey": return Boolean, apakah API key sudah diset
 * - "openSettings": buka AiSettingsActivity
 * - "complete": kirim prompt ke AI, return String response
 *   Args: {"prompt": String}
 *   Error: AiFailure message
 *
 * Di sisi Dart/Flutter:
 * - Panggil "hasKey" saat init
 * - Jika false: sembunyikan/disable fitur AI (jangan tampilkan error)
 * - Jika true: panggil "complete" untuk chat
 */
object AiFlutterBridge {
    const val CHANNEL = "ssr_space/ai"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /**
     * Setup MethodChannel handler. Panggil dari MainActivity.onCreate.
     */
    fun setup(context: Context, channel: MethodChannel) {
        val appContext = context.applicationContext
        val keyStore = AiKeyStore(appContext)
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
                "complete" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt.isNullOrBlank()) {
                        result.error("INVALID", "prompt kosong", null)
                        return@setMethodCallHandler
                    }
                    val config = keyStore.toAiConfig()
                    if (config == null) {
                        result.error("NO_KEY", "Belum ada API key", null)
                        return@setMethodCallHandler
                    }
                    // Jalankan di background, return via result
                    scope.launch {
                        try {
                            val provider = ZenProvider(config)
                            val aiResult = withContext(Dispatchers.IO) {
                                provider.complete(prompt)
                            }
                            aiResult.fold(
                                onSuccess = { text -> result.success(text) },
                                onFailure = { e ->
                                    // JANGAN sertakan key di error!
                                    val code = when (e) {
                                        is AiFailure.RateLimited -> "RATE_LIMITED"
                                        is AiFailure.InvalidKey -> "INVALID_KEY"
                                        is AiFailure.ModelUnavailable -> "MODEL_UNAVAILABLE"
                                        is AiFailure.NetworkError -> "OFFLINE"
                                        else -> "ERROR"
                                    }
                                    result.error(code, e.message, null)
                                }
                            )
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onDestroy() {
        scope.cancel()
    }
}
