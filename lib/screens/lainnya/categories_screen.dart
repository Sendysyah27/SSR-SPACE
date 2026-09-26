import 'package:flutter/material.dart';
import 'package:ssr_space/services/app_categories.dart';
import 'package:ssr_space/theme/app_theme.dart';
import 'package:ssr_space/utils/strings.dart';
import 'package:ssr_space/widgets/primary_button.dart';
import 'package:ssr_space/widgets/section_card.dart';

/// Atur daftar kategori global: tambah, hapus, simpan, kembalikan bawaan.
/// Dipakai popup koreksi, form catat, dan saran kategori.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<String> items;
  final addC = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    items = [...appCategories.value];
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
    if (t.isEmpty) return;
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
      if (!mounted) return;
      setState(() => items = [...appCategories.value]);
      _snack(tr('c_saved'));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('o_cats'))),
      body: ListView(
        padding: const EdgeInsets.all(SsrSpace.lg),
        children: [
          _CatCard(items: items, onDelete: _removeAt),
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
class _CatCard extends StatelessWidget {
  final List<String> items;
  final void Function(int) onDelete;

  const _CatCard({required this.items, required this.onDelete});

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
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Text(
                      items[i],
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDelete(i),
                ),
              ],
            ),
          ],
        ],
      ),
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
        IconButton.filled(icon: const Icon(Icons.add), onPressed: onAdd),
      ],
    );
  }
}
