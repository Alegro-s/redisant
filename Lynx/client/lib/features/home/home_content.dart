import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../projects/providers/project_provider.dart';
import 'lynx_hub_feed.dart';

class HomeContent extends StatefulWidget {
  final void Function(String moduleId)? onSelectModule;

  const HomeContent({super.key, this.onSelectModule});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated) {
        context.read<ProjectProvider>().loadProjects();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LynxHubFeed(onSelectModule: widget.onSelectModule);
  }
}
