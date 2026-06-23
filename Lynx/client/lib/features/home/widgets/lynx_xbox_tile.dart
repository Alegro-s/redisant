import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Карточка в стиле Xbox (плоский фон, без градиентов).
class LynxXboxTile extends StatelessWidget {
  const LynxXboxTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.leading,
    this.badge,
    this.width = 168,
    this.height = 200,
    this.accent,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? leading;
  final String? badge;
  final double width;
  final double height;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = accent ?? cs.primary;
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: const Color(0xFF1A1A1F),
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
                    ColoredBox(color: a.withValues(alpha: 0.18)),
                    if (leading != null)
                      Center(child: leading!)
                    else
                      Center(
                        child: Icon(Icons.videogame_asset_outlined, size: 44, color: a),
                      ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: a,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            badge!,
                            style: GoogleFonts.montserrat(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LynxXboxSectionHeader extends StatelessWidget {
  const LynxXboxSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
