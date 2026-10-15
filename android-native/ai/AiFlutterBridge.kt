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
                    // Provider dipilih sisi Dart (prefs ai_provider):
                    // "local" = opencode serve lokal (password per-call,
                    // tidak disimpan di native), selain itu = Zen.
                    val which = call.argument<String>("provider") ?: "zen"
                    if (which == "local") {
                        val base = (call.argument<String>("baseUrl") ?: "")
                            .trim().trimEnd('/')
                        // JANGAN log password!
                        val pass = call.argument<String>("localPassword") ?: ""
                        if (base.isEmpty() || pass.isEmpty()) {
                            result.error(
                                "NO_LOCAL_PASS",
                                "Belum ada password OpenCode lokal. Isi di layar Mang AI.",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val tmo = (call.argument<Int>("timeoutMs") ?: 30_000)
                            .coerceIn(5_000, 300_000)
                        runProvider(LocalOpenCodeProvider(base, pass, tmo), prompt, result)
                        return@setMethodCallHandler
                    }
                    val config = keyStore.toAiConfig()
                    if (config == null) {
                        result.error("NO_KEY", "Belum ada API key", null)
                        return@setMethodCallHandler
                    }
                    runProvider(ZenProvider(config), prompt, result)
                }
                "completeWithImage" -> {
                    val prompt = call.argument<String>("prompt")
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val mimeType = call.argument<String>("mimeType") ?: "image/jpeg"
                    // System prompt kustom opsional (mis. scan struk); null = default chat.
                    val system = call.argument<String>("system")
                    if (prompt.isNullOrBlank() || imageBytes == null || imageBytes.isEmpty()) {
                        result.error("INVALID", "prompt atau gambar kosong", null)
                        return@setMethodCallHandler
                    }
                    val which = call.argument<String>("provider") ?: "zen"
                    if (which == "local") {
                        val base = (call.argument<String>("baseUrl") ?: "").trim().trimEnd('/')
                        val pass = call.argument<String>("localPassword") ?: ""
                        if (base.isEmpty() || pass.isEmpty()) {
                            result.error("NO_LOCAL_PASS", "Belum ada password OpenCode lokal.", null)
                            return@setMethodCallHandler
                        }
                        val tmoImg = (call.argument<Int>("timeoutMs") ?: 30_000)
                            .coerceIn(5_000, 300_000)
                        runProviderWithImage(LocalOpenCodeProvider(base, pass, tmoImg), prompt, imageBytes, mimeType, system, result)
                        return@setMethodCallHandler
                    }
                    result.error("UNSUPPORTED", "Vision hanya untuk OpenCode lokal.", null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onDestroy() {
        scope.cancel()
    }

    private fun runProviderWithImage(
        provider: LocalOpenCodeProvider,
        prompt: String,
        imageBytes: ByteArray,
        mimeType: String,
        system: String?,
        result: MethodChannel.Result,
    ) {
        scope.launch {
            try {
                val aiResult = withContext(Dispatchers.IO) {
                    if (system.isNullOrBlank()) {
                        provider.completeWithImage(prompt, imageBytes, mimeType)
                    } else {
                        provider.completeWithImage(prompt, imageBytes, mimeType, system)
                    }
                }
                aiResult.fold(
                    onSuccess = { text -> result.success(text) },
                    onFailure = { e ->
                        result.error("AI_ERROR", e.message ?: "Unknown", null)
                    }
                )
            } catch (e: Exception) {
                result.error("AI_ERROR", e.message ?: "Unknown", null)
            }
        }
    }

    /**
     * Jalankan provider di background, return via result.
     * Dipakai Zen maupun OpenCode lokal (routing di "complete").
     */
    private fun runProvider(
        provider: AiProvider,
        prompt: String,
        result: MethodChannel.Result,
    ) {
        scope.launch {
            try {
                val aiResult = withContext(Dispatchers.IO) {
                    provider.complete(prompt)
                }
                aiResult.fold(
                    onSuccess = { text -> result.success(text) },
                    onFailure = { e ->
                        // JANGAN sertakan key/password di error!
                        val code = when (e) {
                            is AiFailure.RateLimited -> "RATE_LIMITED"
                            is AiFailure.InvalidKey -> "INVALID_KEY"
                            is AiFailure.ModelUnavailable -> "MODEL_UNAVAILABLE"
                            is AiFailure.NetworkError -> "OFFLINE"
                            is AiFailure.EmptyResponse -> "EMPTY"
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
}
