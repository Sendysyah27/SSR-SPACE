import 'package:flutter/material.dart';
import 'package:ssr_space/theme/dribbble_tokens.dart';

/// Satu pilihan workspace.
class WorkspaceOption {
  final String id;
  final String name;
  final String? role;
  final bool selected;
  const WorkspaceOption({
    required this.id,
    required this.name,
    this.role,
    this.selected = false,
  });
}

/// Kartu putih pilih workspace TAHAP 3 (baru, belum dipakai layar).
///
/// Presentasional murni: daftar + centang pilihan, aksi via [onSelect].
class WorkspaceSwitcher extends StatelessWidget {
  final List<WorkspaceOption> options;
  final ValueChanged<WorkspaceOption> onSelect;

  const WorkspaceSwitcher({
    super.key,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: DribTokens.card,
        borderRadius:
            BorderRadius.circular(DribTokens.cardRadius),
        boxShadow: DribTokens.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            InkWell(
              onTap: () => onSelect(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          if ((o.role ?? '').isNotEmpty)
                            Text(
                              o.role!,
                              style: TextStyle(
                                fontSize: 12,
                                color: DribTokens.navy
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (o.selected)
                      const Icon(
                        Icons.check_circle,
                        color: DribTokens.primary,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
