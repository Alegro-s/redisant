import 'package:flutter/material.dart';

@immutable
class NexusShellTheme extends ThemeExtension<NexusShellTheme> {
  final Color activityBar;
  final Color activityBarBorder;
  final Color sidebar;
  final Color sidebarHover;
  final Color sidebarSelected;
  final Color sidebarBorder;
  final Color contentChrome;
  final Color messageBubbleMine;
  final Color messageBubbleOther;

  const NexusShellTheme({
    required this.activityBar,
    required this.activityBarBorder,
    required this.sidebar,
    required this.sidebarHover,
    required this.sidebarSelected,
    required this.sidebarBorder,
    required this.contentChrome,
    required this.messageBubbleMine,
    required this.messageBubbleOther,
  });

  static const NexusShellTheme dark = NexusShellTheme(
    activityBar: Color(0xFF0D1117),
    activityBarBorder: Color(0xFF30363D),
    sidebar: Color(0xFF161B22),
    sidebarHover: Color(0xFF21262D),
    sidebarSelected: Color(0xFF342554),
    sidebarBorder: Color(0xFF30363D),
    contentChrome: Color(0xFF0D1117),
    messageBubbleMine: Color(0xFF7C3AED),
    messageBubbleOther: Color(0xFF272236),
  );

  static const NexusShellTheme light = NexusShellTheme(
    activityBar: Color(0xFFF4F4F5),
    activityBarBorder: Color(0xFFE4E4E7),
    sidebar: Color(0xFFFFFFFF),
    sidebarHover: Color(0xFFF4F4F5),
    sidebarSelected: Color(0xFFE8EBF4),
    sidebarBorder: Color(0xFFE4E4E7),
    contentChrome: Color(0xFFFAFAFA),
    messageBubbleMine: Color(0xFF5C6BA3),
    messageBubbleOther: Color(0xFFF4F4F5),
  );

  @override
  NexusShellTheme copyWith({
    Color? activityBar,
    Color? activityBarBorder,
    Color? sidebar,
    Color? sidebarHover,
    Color? sidebarSelected,
    Color? sidebarBorder,
    Color? contentChrome,
    Color? messageBubbleMine,
    Color? messageBubbleOther,
  }) {
    return NexusShellTheme(
      activityBar: activityBar ?? this.activityBar,
      activityBarBorder: activityBarBorder ?? this.activityBarBorder,
      sidebar: sidebar ?? this.sidebar,
      sidebarHover: sidebarHover ?? this.sidebarHover,
      sidebarSelected: sidebarSelected ?? this.sidebarSelected,
      sidebarBorder: sidebarBorder ?? this.sidebarBorder,
      contentChrome: contentChrome ?? this.contentChrome,
      messageBubbleMine: messageBubbleMine ?? this.messageBubbleMine,
      messageBubbleOther: messageBubbleOther ?? this.messageBubbleOther,
    );
  }

  @override
  NexusShellTheme lerp(ThemeExtension<NexusShellTheme>? other, double t) {
    if (other is! NexusShellTheme) return this;
    Color lc(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;
    return NexusShellTheme(
      activityBar: lc(activityBar, other.activityBar, t),
      activityBarBorder: lc(activityBarBorder, other.activityBarBorder, t),
      sidebar: lc(sidebar, other.sidebar, t),
      sidebarHover: lc(sidebarHover, other.sidebarHover, t),
      sidebarSelected: lc(sidebarSelected, other.sidebarSelected, t),
      sidebarBorder: lc(sidebarBorder, other.sidebarBorder, t),
      contentChrome: lc(contentChrome, other.contentChrome, t),
      messageBubbleMine: lc(messageBubbleMine, other.messageBubbleMine, t),
      messageBubbleOther: lc(messageBubbleOther, other.messageBubbleOther, t),
    );
  }
}

extension NexusShellThemeX on BuildContext {
  NexusShellTheme get nexusShell =>
      Theme.of(this).extension<NexusShellTheme>() ?? NexusShellTheme.dark;
}
