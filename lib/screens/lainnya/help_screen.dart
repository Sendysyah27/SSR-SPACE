import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/labeled_section_card.dart';

/// Bantuan: tutorial pemakaian per fitur + tanya jawab umum.
/// Dibuka dari seksi Tentang di Profil dan hasil pencarian Bantuan.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _guides = <(String, String)>[
    ('hp_start_t', 'hp_start_b'),
    ('hp_record_t', 'hp_record_b'),
    ('hp_track_t', 'hp_track_b'),
    ('hp_budget_t', 'hp_budget_b'),
    ('hp_report_t', 'hp_report_b'),
    ('hp_pin_t', 'hp_pin_b'),
  ];

  static const _faqs = <(String, String)>[
    ('hp_q1', 'hp_a1'),
    ('hp_q2', 'hp_a2'),
    ('hp_q3', 'hp_a3'),
    ('hp_q4', 'hp_a4'),
    ('hp_q5', 'hp_a5'),
    ('hp_q6', 'hp_a6'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('hp_title'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          LabeledSectionCard(
            label: tr('hp_guide'),
            children: [for (final g in _guides) _Tile(t: g.$1, b: g.$2)],
          ),
          const SizedBox(height: SsrSpace.md),
          LabeledSectionCard(
            label: tr('hp_faq'),
            children: [for (final f in _faqs) _Tile(t: f.$1, b: f.$2)],
          ),
        ],
      ),
    );
  }
}

/// Satu baris lipat: judul selalu tampil, isi terbuka saat diketuk.
class _Tile extends StatelessWidget {
  final String t;
  final String b;

  const _Tile({required this.t, required this.b});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: SsrSpace.sm),
      title: Text(
        tr(t),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(tr(b), style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
