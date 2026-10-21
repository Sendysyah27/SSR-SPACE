import 'package:flutter/material.dart';
import 'package:ssr_space/services/ai_scan_note_builder.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';

// Pengaturan AI Scan (batch 284 tahap C): saklar catatan otomatis,
// urutan potongan catatan, dan nama pemilik untuk struk transfer.
// Semua teks Bahasa Indonesia; preferensi disimpan via
// ai_scan_note_builder (SharedPreferences).
class AiScanSettingsScreen extends StatefulWidget {
  const AiScanSettingsScreen({super.key});

  @override
  State<AiScanSettingsScreen> createState() => _AiScanSettingsScreenState();
}

class _AiScanSettingsScreenState extends State<AiScanSettingsScreen> {
  AiScanNoteSettings _settings = const AiScanNoteSettings();
  final _ownerC = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await loadAiScanNoteSettings();
    if (!mounted) return;
    setState(() {
      _settings = st;
      _ownerC.text = st.ownerName;
      _loading = false;
    });
  }

  Future<void> _save(AiScanNoteSettings next) async {
    setState(() => _settings = next);
    await saveAiScanNoteSettings(next);
  }

  void _move(int index, int delta) {
    final order = [..._settings.order];
    final target = index + delta;
    if (target < 0 || target >= order.length) return;
    final tmp = order[index];
    order[index] = order[target];
    order[target] = tmp;
    _save(_settings.copyWith(order: order));
  }

  @override
  void dispose() {
    _ownerC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('ai_scan_settings_title'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.md),
              children: [
                Text(
                  tr('ai_scan_settings_intro'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: SsrSpace.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('ai_scan_note_enabled')),
                  subtitle: Text(tr('ai_scan_note_enabled_sub')),
                  value: _settings.enabled,
                  onChanged: (v) =>
                      _save(_settings.copyWith(enabled: v)),
                ),
                const Divider(height: 24),
                Text(
                  tr('ai_scan_note_order_title'),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('ai_scan_note_order_sub'),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: SsrSpace.sm),
                for (var i = 0; i < _settings.order.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: SsrSpace.xs),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        aiScanNotePieceLabels[_settings.order[i]] ??
                            _settings.order[i],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: i == 0 ? null : () => _move(i, -1),
                            tooltip: tr('ai_scan_move_up'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: i == _settings.order.length - 1
                                ? null
                                : () => _move(i, 1),
                            tooltip: tr('ai_scan_move_down'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Divider(height: 24),
                TextField(
                  controller: _ownerC,
                  decoration: InputDecoration(
                    labelText: tr('ai_scan_owner_label'),
                    helperText: tr('ai_scan_owner_helper'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => _save(_settings.copyWith(ownerName: v)),
                ),
              ],
            ),
    );
  }
}
