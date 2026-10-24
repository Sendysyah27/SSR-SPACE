import 'package:flutter/material.dart';
import 'package:ssr_space/services/ai_scan_note_builder.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
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
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('ai_scan_settings_title'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : DribTokens.navy,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(SsrSpace.md),
              children: [
                Text(
                  tr('ai_scan_settings_intro'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: DribTokens.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: SsrSpace.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: DribTokens.cardOf(context),
                    borderRadius:
                        const BorderRadius.all(Radius.circular(20)),
                    boxShadow: DribTokens.cardShadow,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tr('ai_scan_note_enabled'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: DribTokens.navy,
                      ),
                    ),
                    subtitle: Text(
                      tr('ai_scan_note_enabled_sub'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DribTokens.textSecondary,
                      ),
                    ),
                    activeTrackColor: DribTokens.primaryStrong,
                    value: _settings.enabled,
                    onChanged: (v) =>
                        _save(_settings.copyWith(enabled: v)),
                  ),
                ),
                const Divider(height: 24, color: DribTokens.border),
                Text(
                  tr('ai_scan_note_order_title'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : DribTokens.navy,
                  ),
                ),
                const SizedBox(height: SsrSpace.xs),
                Text(
                  tr('ai_scan_note_order_sub'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: DribTokens.textSecondary),
                ),
                const SizedBox(height: SsrSpace.sm),
                for (var i = 0; i < _settings.order.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: SsrSpace.xs),
                    decoration: BoxDecoration(
                      color: DribTokens.cardOf(context),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(16)),
                      boxShadow: DribTokens.cardShadow,
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        aiScanNotePieceLabels[_settings.order[i]] ??
                            _settings.order[i],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DribTokens.navy,
                        ),
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
                const Divider(height: 24, color: DribTokens.border),
                TextField(
                  controller: _ownerC,
                  decoration: InputDecoration(
                    labelText: tr('ai_scan_owner_label'),
                    helperText: tr('ai_scan_owner_helper'),
                    filled: true,
                    fillColor: DribTokens.cardOf(context),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: DribTokens.border),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: DribTokens.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(
                          color: DribTokens.primaryStrong, width: 1.5),
                    ),
                  ),
                  onChanged: (v) => _save(_settings.copyWith(ownerName: v)),
                ),
              ],
            ),
    );
  }
}
