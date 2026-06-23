import 'package:flutter/material.dart';

import '../themes/lynx_hub_palette.dart';

class LynxXboxTile extends StatelessWidget {
  const LynxXboxTile({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.icon,
    this.badge,
    this.accent,
    this.width = 200,
    this.height = 280,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData? icon;
  final String? badge;
  final Color? accent;
  final double width;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPurple = cs.primary.value == LynxHubPalette.accent.value;
    final tileAccent = accent ?? cs.primary;
    final cover = imageUrl != null && imageUrl!.isNotEmpty
        ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _cover(context, icon, tileAccent))
        : _cover(context, icon, tileAccent);

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: isPurple ? LynxHubPalette.card : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover,
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(badge!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  color: isPurple ? LynxHubPalette.surface : cs.surfaceContainerHighest,
                  border: Border(top: BorderSide(color: isPurple ? LynxHubPalette.border : cs.outline.withValues(alpha: 0.2))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isPurple ? LynxHubPalette.text : cs.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: isPurple ? LynxHubPalette.muted : cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context, IconData? ic, Color ac) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (isLight) {
      return ColoredBox(
        color: ac.withValues(alpha: 0.1),
        child: Center(
          child: Icon(ic ?? Icons.sports_esports_outlined, size: 52, color: ac),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ac.withValues(alpha: 0.35), LynxHubPalette.markBottom],
        ),
      ),
      child: Center(
        child: Icon(ic ?? Icons.sports_esports_outlined, size: 52, color: ac.withValues(alpha: 0.9)),
      ),
    );
  }
}
