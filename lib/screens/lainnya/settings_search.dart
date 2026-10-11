import 'package:flutter/material.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/utils/strings.dart';

/// Satu baris hub atau pengaturan yang bisa dicari.
/// titleKey dan sectionKey adalah kunci tr(), en kata kunci Inggris.
/// focus = kartu SettingsScreen yang di-scroll saat rute 'settings'.
class SettingsSearchEntry {
  final String titleKey;
  final String en;
  final String sectionKey;
  final String route;
  final String? focus;

  const SettingsSearchEntry({
    required this.titleKey,
    required this.en,
    required this.sectionKey,
    required this.route,
    this.focus,
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
    titleKey: 'o_clearcache_t',
    en: 'clear local cache',
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
    titleKey: 'fam_title',
    en: 'family members spending per member',
    sectionKey: 'pf_workspace',
    route: 'family',
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
    titleKey: 'sp_activity',
    en: 'space activity feed who recorded',
    sectionKey: 'pf_workspace',
    route: 'space_activity',
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
    route: 'hub_mask',
  ),
  SettingsSearchEntry(
    titleKey: 'st_font',
    en: 'font size text',
    sectionKey: 'pf_appearance',
    route: 'settings',
    focus: 'font',
  ),
  // Bahasa dan mata uang.
  SettingsSearchEntry(
    titleKey: 'st_lang',
    en: 'language bahasa indonesia english',
    sectionKey: 'pf_langmoney',
    route: 'settings',
    focus: 'lang',
  ),
  SettingsSearchEntry(
    titleKey: 'st_currency',
    en: 'display currency exchange rates',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'currency',
  ),
  SettingsSearchEntry(
    titleKey: 'st_def_currency',
    en: 'default currency input form',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'currency',
  ),
  SettingsSearchEntry(
    titleKey: 'st_fx_refresh',
    en: 'refresh rates update kurs',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'currency',
  ),
  // Pengingat.
  SettingsSearchEntry(
    titleKey: 'st_reminder_on',
    en: 'daily reminder notification',
    sectionKey: 'pf_reminder',
    route: 'settings',
    focus: 'reminder',
  ),
  SettingsSearchEntry(
    titleKey: 'st_reminder_time',
    en: 'reminder time clock hour',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'reminder',
  ),
  SettingsSearchEntry(
    titleKey: 'st_weekly_on',
    en: 'weekly reminder notification recap',
    sectionKey: 'pf_reminder',
    route: 'settings',
    focus: 'reminder',
  ),
  SettingsSearchEntry(
    titleKey: 'st_widget_today',
    en: 'today widget home',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'widget',
  ),
  // Tampilan dan laporan di pengaturan.
  SettingsSearchEntry(
    titleKey: 'st_topn',
    en: 'top categories other reports',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'topn',
  ),
  SettingsSearchEntry(
    titleKey: 'st_anims',
    en: 'animations',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'anims',
  ),
  SettingsSearchEntry(
    titleKey: 'st_list_style',
    en: 'list style compact comfortable',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'list',
  ),
  SettingsSearchEntry(
    titleKey: 'st_date_style',
    en: 'date style format',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'date',
  ),
  SettingsSearchEntry(
    titleKey: 'st_hero_style',
    en: 'summary style hero',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'hero',
  ),
  // Keamanan.
  SettingsSearchEntry(
    titleKey: 'st_pin',
    en: 'security pin change',
    sectionKey: 'pf_security',
    route: 'settings',
    focus: 'pin',
  ),
  SettingsSearchEntry(
    titleKey: 'st_numformat',
    en: 'number format dots commas',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'numformat',
  ),
  SettingsSearchEntry(
    titleKey: 'st_def_wallet',
    en: 'default wallet form',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'defwallet',
  ),
  SettingsSearchEntry(
    titleKey: 'st_weekstart',
    en: 'week start monday sunday',
    sectionKey: 'st_title',
    route: 'settings',
    focus: 'weekstart',
  ),
  SettingsSearchEntry(
    titleKey: 'st_lock_timeout',
    en: 'auto lock timeout pin background',
    sectionKey: 'pf_security',
    route: 'settings',
    focus: 'lock',
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
    route: 'hub_about',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_changelog',
    en: 'changelog update log changes',
    sectionKey: 'pf_about',
    route: 'changelog',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_help',
    en: 'help support tutorial faq',
    sectionKey: 'pf_about',
    route: 'help',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_feedback',
    en: 'send feedback email suggestion',
    sectionKey: 'pf_about',
    route: 'hub_feedback',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_share',
    en: 'share app recommend',
    sectionKey: 'pf_about',
    route: 'hub_share',
  ),
  SettingsSearchEntry(
    titleKey: 'ab_privacy',
    en: 'privacy policy data',
    sectionKey: 'pf_about',
    route: 'hub_privacy',
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
      IconButton(
        icon: const DuoIcon(AppIcons.close),
        tooltip: tr('clear'),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const DuoIcon(AppIcons.back),
      tooltip: tr('back'),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _ResultList(
      entries: _match(query),
      onTap: (e) => close(
        context,
        e.focus == null ? e.route : '${e.route}:${e.focus}',
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _ResultList(
      entries: _match(query),
      onTap: (e) => close(
        context,
        e.focus == null ? e.route : '${e.route}:${e.focus}',
      ),
    );
  }
}

/// Daftar hasil: ketuk menutup delegate dengan kunci rute entri
/// (+ fokus kartu bila ada, format `route:focus`).
class _ResultList extends StatelessWidget {
  final List<SettingsSearchEntry> entries;
  final ValueChanged<SettingsSearchEntry> onTap;

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
          onTap: () => onTap(e),
        );
      },
    );
  }
}
