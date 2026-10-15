# Layar Pengaturan AI

## File
- `AiKeyStore.kt` — EncryptedSharedPreferences untuk API key
- `AiSettingsActivity.kt` — UI pengaturan (input masked, tes koneksi, hapus)
- `AiFlutterBridge.kt` — MethodChannel `ssr_space/ai` untuk Flutter
- `backup_rules.xml` — exclude key dari backup
- `data_extraction_rules.xml` — exclude key dari Android 12+ backup

## Integrasi ke AndroidManifest.xml
```xml
<application
    android:allowBackup="true"
    android:fullBackupContent="@xml/backup_rules"
    android:dataExtractionRules="@xml/data_extraction_rules">
    
    <activity
        android:name=".ai.AiSettingsActivity"
        android:exported="false" />
</application>
```

## Integrasi ke MainActivity (Kotlin)
```kotlin
// Di onCreate, setelah flutterEngine setup:
val aiChannel = MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "ssr_space/ai"
)
AiFlutterBridge.setup(this, aiChannel)
```

## Integrasi ke Flutter (Dart)
```dart
// Cek apakah AI tersedia (untuk hide/disable, bukan error)
final hasKey = await MethodChannel('ssr_space/ai')
    .invokeMethod<bool>('hasKey') ?? false;

if (!hasKey) {
  // Sembunyikan fitur AI
  return SizedBox.shrink();
}
// Tampilkan fitur AI

// Buka pengaturan
await MethodChannel('ssr_space/ai').invokeMethod('openSettings');
```

## Dependencies (build.gradle)
```gradle
dependencies {
    implementation "androidx.security:security-crypto:1.1.0-alpha06"
    implementation "androidx.appcompat:appcompat:1.6.1"
}
```

## Keamanan
- Key TIDAK PERNAH di-log
- Key di EncryptedSharedPreferences (AES256-GCM)
- Key tidak ikut backup (backup_rules.xml)
- Input masked (TYPE_TEXT_VARIATION_PASSWORD)
- Key dibersihkan dari memori di onDestroy
