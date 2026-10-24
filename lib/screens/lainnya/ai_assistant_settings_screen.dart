import 'package:flutter/material.dart';

import 'package:ssr_space/services/ai_context.dart';
import 'package:ssr_space/services/ai_memory.dart';
import 'package:ssr_space/services/ai_persona.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/drib_card.dart';

// Layar Pengaturan Asisten khusus (batch 285 tahap D, pola route
// /ai-assistant/settings Ollo): mengumpulkan personalisasi + izin
// akses data + ringkasan memori yang sebelumnya tersebar di sheet
// Memori AI ke satu layar, dibuka dari header Mode Asisten. Kunci
// prefs TIDAK berubah (tanpa migrasi data).

class AiAssistantSettingsScreen extends StatefulWidget {
  const AiAssistantSettingsScreen({super.key});

  @override
  State<AiAssistantSettingsScreen> createState() =>
      _AiAssistantSettingsScreenState();
}

class _AiAssistantSettingsScreenState
    extends State<AiAssistantSettingsScreen> {
  AiPersonaPrefs _persona = const AiPersonaPrefs();
  bool _dataChoice = false;
  List<String> _facts = const [];
  List<String> _summaries = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final persona = await loadAiPersona();
    final facts = await loadAiMemory();
    final summaries = await loadAiSummaries();
    bool choice = false;
    try {
      choice = await aiDataChoice() ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _persona = persona;
      _facts = facts;
      _summaries = summaries;
      _dataChoice = choice;
    });
  }

  Future<void> _askText(String title, String initial,
      Future<void> Function(String) onSave) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: tr('ai_set_empty'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('ai_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('save')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await onSave(c.text);
      await _reload();
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : DribTokens.navy,
          ),
        ),
        const SizedBox(height: SsrSpace.sm),
        DribCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
        const SizedBox(height: SsrSpace.md),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DribTokens.bgOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr('ai_aset_title'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : DribTokens.navy,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.md),
        children: [
          _section(tr('ai_set_persona'), [
            Wrap(
              spacing: SsrSpace.xs,
              children: [
                for (final e in kAiPersonaStyles.entries)
                  ChoiceChip(
                    label: Text(tr('ai_persona_${e.key}')),
                    selected: _persona.persona == e.key,
                    selectedColor: const Color(0xFFD9E6FA),
                    checkmarkColor: DribTokens.navy,
                    side: const BorderSide(color: DribTokens.border),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _persona.persona == e.key
                          ? DribTokens.navy
                          : DribTokens.textSecondary,
                    ),
                    onSelected: (_) async {
                      await saveAiPersona(
                          _persona.copyWith(persona: e.key));
                      await _reload();
                    },
                  ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: DribTokens.balanceGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome,
                    size: 19, color: Colors.white),
              ),
              title: Text(
                tr('ai_set_nickname'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.navy,
                ),
              ),
              subtitle: Text(
                _persona.nickname.isEmpty
                    ? tr('ai_set_empty')
                    : _persona.nickname,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: DribTokens.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _askText(
                tr('ai_set_nickname'),
                _persona.nickname,
                (v) => saveAiPersona(
                    _persona.copyWith(nickname: v.trim())),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('ai_set_custom'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.navy,
                ),
              ),
              subtitle: Text(
                _persona.customInstruction.isEmpty
                    ? tr('ai_set_empty')
                    : _persona.customInstruction,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: DribTokens.textSecondary,
                ),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _askText(
                tr('ai_set_custom'),
                _persona.customInstruction,
                (v) => saveAiPersona(
                    _persona.copyWith(customInstruction: v.trim())),
              ),
            ),
          ]),
          _section(tr('ai_aset_data'), [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr('ai_aset_data'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DribTokens.navy,
                ),
              ),
              subtitle: Text(
                tr('ai_aset_data_s'),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: DribTokens.textSecondary,
                ),
              ),
              activeTrackColor: DribTokens.primaryStrong,
              value: _dataChoice,
              onChanged: (v) async {
                try {
                  await setAiDataChoice(v);
                } catch (_) {}
                if (mounted) setState(() => _dataChoice = v);
              },
            ),
          ]),
          _section(tr('chat_mem_facts_t'), [
            if (_facts.isEmpty)
              Text(tr('chat_mem_empty'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DribTokens.textSecondary,
                  )),
            for (final f in _facts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  f,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DribTokens.navy,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await removeAiMemory(f);
                    await _reload();
                  },
                ),
              ),
          ]),
          _section(tr('chat_mem_sum_t'), [
            if (_summaries.isEmpty)
              Text(tr('chat_mem_empty'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DribTokens.textSecondary,
                  )),
            for (final s in _summaries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DribTokens.navy,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await removeAiSummary(s);
                    await _reload();
                  },
                ),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: DribTokens.errorText,
                side: const BorderSide(color: DribTokens.errorText),
              ),
              onPressed: () async {
                await clearAiMemory();
                await clearAiSummaries();
                await _reload();
              },
              child: Text(tr('chat_mem_clear')),
            ),
          ]),
        ],
      ),
    );
  }
}
