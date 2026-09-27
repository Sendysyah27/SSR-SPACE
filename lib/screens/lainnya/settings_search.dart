import 'package:flutter/material.dart';
import 'package:ssr_space/utils/strings.dart';

/// Kunci rute hasil pencarian.
/// 'p2' berarti baris tahap P2, caller menampilkan dialog msg_p2.
/// 'hub' berarti toggle sudah terlihat di hub, cukup tutup pencarian.
const kSearchP2 = 'p2';
const kSearchHub = 'hub';

/// Satu baris hub atau pengaturan yang bisa dicari.
/// titleKey dan sectionKey adalah kunci tr(), en kata kunci Inggris.
class SettingsSearchEntry {
  final String titleKey;
  final String en;
  final String sectionKey;
  final String route;

  const SettingsSearchEntry({
    required this.titleKey,
    required this.en,
    required this.sectionKey,
    required this.route,
  });
}

/// Daftar statis semua baris hub, pengaturan, impor, dan tentang.
const kSettingsSearchEntries = <SettingsSearchEntry>[
  // Data.
  SettingsSearchEntry(
    titleKey: 'o_wallets',
    en: 'wallets money cash bank ewallet',
    sectionKey: 'pf_data',
    route: 'wallets',
  ),
  SettingsSearchEntry(
    titleKey: 'o_cats',
    en: 'categories',
    sectionKey: 'pf_data',
    route: 'categories',
  ),
  SettingsSearchEntry(
    titleKey: 'nav_budget',
    en: 'budget limit spending',
    sectionKey: 'pf_data',
    route: 'budgets',
  ),
  SettingsSearchEntry(
    titleKey: 'nav_transaksi',
    en: 'transactions history record',
    sectionKey: 'pf_data',
    route: 'history',
  ),
  // Pelacakan.
  SettingsSearchEntry(
    titleKey: 'o_tracking',
    en: 'auto tracking notification listener bank',
    sectionKey: 'pf_tracking',
    route: 'tracking',
  ),
  SettingsSearchEntry(
    titleKey: 'ic_popup',
    en: 'instant correction popup overlay',
    sectionKey: 'pf_tracking',
    route: 'tracking',
  ),
  // Data dan cadangan.
  SettingsSearchEntry(
    titleKey: 'o_backup',
    en: 'back up data csv share',
    sectionKey: 'pf_backup',
    route: 'backup',
  ),
  SettingsSearchEntry(
    titleKey: 'nav_laporan',
    en: 'reports export download csv pdf',
    sectionKey: 'pf_backup',
    route: 'export',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_title',
    en: 'import csv file',
    sectionKey: 'pf_backup',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'st_reset_correct',
    en: 'reset instant correction cache',
    sectionKey: 'pf_backup',
    route: 'clearCache',
  ),
  // Workspace.
  SettingsSearchEntry(
    titleKey: 'o_invite',
    en: 'invite members token',
    sectionKey: 'pf_workspace',
    route: 'invite',
  ),
  SettingsSearchEntry(
    titleKey: 'o_switch',
    en: 'switch workspace change',
    sectionKey: 'pf_workspace',
    route: 'switch',
  ),
  SettingsSearchEntry(
    titleKey: 'wsm_detail',
    en: 'manage workspace detail members',
    sectionKey: 'pf_workspace',
    route: 'detail',
  ),
  SettingsSearchEntry(
    titleKey: 'o_billing',
    en: 'billing plan pro free upgrade',
    sectionKey: 'pf_workspace',
    route: 'billing',
  ),
  // Tampilan.
  SettingsSearchEntry(
    titleKey: 'o_mask',
    en: 'mask amounts hide privacy',
    sectionKey: 'pf_appearance',
    route: kSearchHub,
  ),
  SettingsSearchEntry(
    titleKey: 'st_font',
    en: 'font size text',
    sectionKey: 'pf_appearance',
    route: 'settings',
  ),
  // Bahasa dan mata uang.
  SettingsSearchEntry(
    titleKey: 'st_lang',
    en: 'language bahasa indonesia english',
    sectionKey: 'pf_langmoney',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_currency',
    en: 'display currency exchange rates',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_def_currency',
    en: 'default currency input form',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_fx_refresh',
    en: 'refresh rates update kurs',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  // Pengingat.
  SettingsSearchEntry(
    titleKey: 'st_reminder_on',
    en: 'daily reminder notification',
    sectionKey: 'pf_reminder',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_reminder_time',
    en: 'reminder time clock hour',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_widget_today',
    en: 'today widget home',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  // Tampilan dan laporan di pengaturan.
  SettingsSearchEntry(
    titleKey: 'st_topn',
    en: 'top categories other reports',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_anims',
    en: 'animations',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_list_style',
    en: 'list style compact comfortable',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_date_style',
    en: 'date style format',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'st_hero_style',
    en: 'summary style hero',
    sectionKey: 'st_title',
    route: 'settings',
  ),
  // Keamanan.
  SettingsSearchEntry(
    titleKey: 'st_pin',
    en: 'security pin change',
    sectionKey: 'pf_security',
    route: 'settings',
  ),
  SettingsSearchEntry(
    titleKey: 'o_logout',
    en: 'log out sign out exit',
    sectionKey: 'pf_security',
    route: 'logout',
  ),
  // Tentang.
  SettingsSearchEntry(
    titleKey: 'ab_about',
    en: 'about version app',
    sectionKey: 'pf_about',
    route: kSearchHub,
  ),
  SettingsSearchEntry(
    titleKey: 'ab_changelog',
    en: 'changelog update log changes',
    sectionKey: 'pf_about',
    route: 'changelog',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_help',
    en: 'help support',
    sectionKey: 'pf_about',
    route: kSearchHub,
  ),
  SettingsSearchEntry(
    titleKey: 'ab_feedback',
    en: 'send feedback email suggestion',
    sectionKey: 'pf_about',
    route: kSearchHub,
  ),
  SettingsSearchEntry(
    titleKey: 'ab_share',
    en: 'share app recommend',
    sectionKey: 'pf_about',
    route: kSearchHub,
  ),
  SettingsSearchEntry(
    titleKey: 'ab_privacy',
    en: 'privacy policy data',
    sectionKey: 'pf_about',
    route: kSearchHub,
  ),
  // Baris layar impor (mendarat di pratinjau impor).
  SettingsSearchEntry(
    titleKey: 'imp_pick',
    en: 'paste csv',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_date',
    en: 'date column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_amount',
    en: 'amount column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_type',
    en: 'type column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_wallet',
    en: 'wallet column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_towallet',
    en: 'destination wallet column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_cat',
    en: 'category column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_map_note',
    en: 'note column mapping',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_preview',
    en: 'preview rows check',
    sectionKey: 'imp_title',
    route: 'import',
  ),
  SettingsSearchEntry(
    titleKey: 'imp_import',
    en: 'import execute save',
    sectionKey: 'imp_title',
    route: 'import',
  ),
];

/// Delegate pencarian pengaturan di atas daftar statis.
/// Cocokkan judul Indonesia, kata kunci Inggris, dan nama seksi.
class SettingsSearchDelegate extends SearchDelegate<String?> {
  @override
  String? get searchFieldLabel => tr('search_settings_hint');

  List<SettingsSearchEntry> _match(String q) {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) return kSettingsSearchEntries;
    return kSettingsSearchEntries.where((e) {
      final id = tr(e.titleKey).toLowerCase();
      final section = tr(e.sectionKey).toLowerCase();
      return id.contains(needle) ||
          e.en.toLowerCase().contains(needle) ||
          section.contains(needle);
    }).toList();
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _ResultList(
      entries: _match(query),
      onTap: (route) => close(context, route),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _ResultList(
      entries: _match(query),
      onTap: (route) => close(context, route),
    );
  }
}

/// Daftar hasil: ketuk menutup delegate dengan kunci rute entri.
class _ResultList extends StatelessWidget {
  final List<SettingsSearchEntry> entries;
  final ValueChanged<String> onTap;

  const _ResultList({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(child: Text(tr('search_no_result')));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return ListTile(
          title: Text(tr(e.titleKey)),
          subtitle: Text(tr(e.sectionKey)),
          onTap: () => onTap(e.route),
        );
      },
    );
  }
}
