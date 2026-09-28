import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/services/category_icons.dart';
import 'package:ssr_space/services/category_meta.dart';
import 'package:ssr_space/theme/app_icons.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';

/// Palet 8 warna kategori (dikurasi, bukan color wheel bebas).
/// Slot 0..2 memakai varian ledger yang hidup di kedua mode
/// (primary/error/gold; dulu emerald/rust/gold);
/// urutan slot tetap sehingga indeks tersimpan tidak bergeser makna.
List<Color> _metaPalette(BuildContext context) {
  return List<Color>.generate(8, (i) => metaSlotColor(context, i));
}

/// Ikon terkurasi untuk picker (kunci = nama field AppIcons).
const _kMetaIcons = <String>[
  'food',
  'transport',
  'shopping',
  'bills',
  'health',
  'education',
  'entertainment',
  'topup',
  'income',
  'transfer',
  'wallet',
  'categoryFallback',
];

IconData _metaIconData(String key) {
  switch (key) {
    case 'food':
      return AppIcons.food;
    case 'transport':
      return AppIcons.transport;
    case 'shopping':
      return AppIcons.shopping;
    case 'bills':
      return AppIcons.bills;
    case 'health':
      return AppIcons.health;
    case 'education':
      return AppIcons.education;
    case 'entertainment':
      return AppIcons.entertainment;
    case 'topup':
      return AppIcons.topup;
    case 'income':
      return AppIcons.income;
    case 'transfer':
      return AppIcons.transfer;
    case 'wallet':
      return AppIcons.wallet;
    default:
      return AppIcons.categoryFallback;
  }
}

/// Atur daftar kategori global: tambah, hapus, simpan, kembalikan bawaan.
/// Dipakai form catat dan saran kategori.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<String> items;
  Map<String, CatMeta> meta = {};
  final addC = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    items = [...appCategories.value];
    refreshCategoryMeta().then((m) {
      if (mounted) setState(() => meta = m);
    });
  }

  @override
  void dispose() {
    addC.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _add() {
    final t = addC.text.trim();
    if (t.isEmpty || t.contains('>')) {
      if (t.contains('>')) _snack(tr('sub_sep_err'));
      return;
    }
    if (items.any((e) => e.toLowerCase() == t.toLowerCase())) {
      _snack(tr('c_dupe'));
      return;
    }
    setState(() {
      items.add(t);
      addC.clear();
    });
  }

  void _removeAt(int i) {
    if (items.length <= 1) {
      _snack(tr('c_min_one'));
      return;
    }
    setState(() => items.removeAt(i));
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await saveAppCategories(items);
      await saveCategoryMeta(meta);
      if (!mounted) return;
      setState(() => items = [...appCategories.value]);
      _snack(tr('c_saved'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickColor(String name) async {
    final cur = meta[name] ?? CatMeta.def;
    final idx = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('sub_color')),
        children: [
          Padding(
            padding: const EdgeInsets.all(SsrSpace.lg),
            child: Wrap(
              spacing: SsrSpace.sm,
              runSpacing: SsrSpace.sm,
              children: [
                for (var i = 0; i < _metaPalette(context).length; i++)
                  InkWell(
                    onTap: () => Navigator.pop(context, i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _metaPalette(context)[i],
                        border: Border.all(
                          color: i == cur.color
                              ? Theme.of(ctx).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (idx != null) {
      setState(
        () => meta[name] = CatMeta(color: idx, icon: cur.icon),
      );
    }
  }

  Future<void> _pickIcon(String name) async {
    final cur = meta[name] ?? CatMeta.def;
    final key = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('sub_icon')),
        children: [
          Padding(
            padding: const EdgeInsets.all(SsrSpace.lg),
            child: Wrap(
              spacing: SsrSpace.sm,
              runSpacing: SsrSpace.sm,
              children: [
                for (final k in _kMetaIcons)
                  InkWell(
                    onTap: () => Navigator.pop(context, k),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(SsrRadius.chip),
                        border: Border.all(
                          color: k == cur.icon
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outline,
                        ),
                      ),
                      child: DuoIcon(_metaIconData(k)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (key != null) {
      setState(
        () => meta[name] = CatMeta(color: cur.color, icon: key),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('o_cats'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _CatCard(
            items: items,
            meta: meta,
            onDelete: _removeAt,
            onColor: _pickColor,
            onIcon: _pickIcon,
          ),
          const SizedBox(height: SsrSpace.md),
          _AddRow(controller: addC, onAdd: _add),
          const SizedBox(height: SsrSpace.md),
          PrimaryButton(label: tr('save'), loading: saving, onPressed: _save),
          TextButton(
            onPressed: () => setState(() => items = [...kDefaultCategories]),
            child: Text(tr('c_reset')),
          ),
        ],
      ),
    );
  }
}

/// Daftar kategori + tombol hapus per baris ala ledger.
/// Dot warna dan ikon bisa diketuk untuk memilih dari palet terkurasi.
class _CatCard extends StatelessWidget {
  final List<String> items;
  final Map<String, CatMeta> meta;
  final void Function(int) onDelete;
  final ValueChanged<String> onColor;
  final ValueChanged<String> onIcon;

  const _CatCard({
    required this.items,
    required this.meta,
    required this.onDelete,
    required this.onColor,
    required this.onIcon,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(
        horizontal: SsrSpace.sm,
        vertical: SsrSpace.xs,
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _CatRow(
              name: items[i],
              meta: meta[items[i]],
              onDelete: () => onDelete(i),
              onColor: onColor,
              onIcon: onIcon,
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris kategori: dot warna + badge ikon + nama + hapus.
/// Badge ikon WYSIWYG: resolusi sama persis dengan TxRow (meta lokal
/// -> svg kustom + warna; tanpa meta -> svg kata kunci + tint primer).
class _CatRow extends StatelessWidget {
  final String name;
  final CatMeta? meta;
  final VoidCallback onDelete;
  final ValueChanged<String> onColor;
  final ValueChanged<String> onIcon;

  const _CatRow({
    required this.name,
    required this.meta,
    required this.onDelete,
    required this.onColor,
    required this.onIcon,
  });

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final base = m == null
        ? Theme.of(context).colorScheme.primary
        : metaSlotColor(context, m.color);
    final svg = m == null ? svgForCategory(name) : svgForMetaIcon(m.icon);
    final dot = m == null ? metaSlotColor(context, 7) : base;
    return Row(
      children: [
        InkWell(
          onTap: () => onColor(name),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dot,
            ),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => onIcon(name),
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: SvgPicture.asset(
                svg,
                width: 19,
                colorFilter: ColorFilter.mode(base, BlendMode.srcIn),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 8,
            ),
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        IconButton(
          icon: const DuoIcon(AppIcons.trash),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Kolom tambah kategori baru.
class _AddRow extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onAdd;

  const _AddRow({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(hintText: tr('c_add_hint')),
          ),
        ),
        const SizedBox(width: SsrSpace.sm),
        IconButton.filled(icon: const DuoIcon(AppIcons.add), onPressed: onAdd),
      ],
    );
  }
}
