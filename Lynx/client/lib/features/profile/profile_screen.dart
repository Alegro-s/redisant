import 'dart:async';

import 'package:client/features/settings/reorder_modules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../auth/models/user.dart';
import '../auth/providers/auth_provider.dart';
import '../projects/providers/project_provider.dart';
import '../../app/providers/settings_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _serverUrlController = TextEditingController();
  File? _newAvatar;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _fullNameController.text = user.fullName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _serverUrlController.text = context.read<AuthProvider>().dioBaseUrl;
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _newAvatar = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_newAvatar != null) {
      try {
        final fileName = _newAvatar!.path.split(RegExp(r'[\\/]+')).last;
        final bytes = await _newAvatar!.readAsBytes();
        await auth.uploadAvatarBytes(bytes: bytes, fileName: fileName);
      } catch (_) {
      }
    }
    await auth.updateProfile(
      fullName: _fullNameController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль обновлён')),
    );
  }

  bool _hasRealm(User? u, String r) {
    if (u == null) return false;
    return u.realms.map((e) => e.toLowerCase()).contains(r.toLowerCase());
  }

  Future<void> _linkProduct(AuthProvider auth, String realm, String label) async {
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Подключить $label'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Один логин и пароль. После подключения этот аккаунт сможет войти и в Lynx Launcher, и в Метрику — как объединение двух способов входа в одном месте.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль этого аккаунта'),
                validator: (v) => (v == null || v.isEmpty) ? 'Введите пароль' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Подключить'),
          ),
        ],
      ),
    );
    if (submit != true) {
      passCtrl.dispose();
      return;
    }
    final err = await auth.linkRealm(realm: realm, password: passCtrl.text);
    passCtrl.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? '$label подключена')),
    );
  }

  Widget _productAccessPanel(BuildContext context, AuthProvider auth, User? user) {
    final cs = Theme.of(context).colorScheme;
    final nexusOk = _hasRealm(user, 'nexus');
    final metricOk = _hasRealm(user, 'metric');
    Widget tile({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool connected,
      VoidCallback? onConnect,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (connected)
                  Icon(Icons.check_circle_rounded, color: cs.primary, size: 22)
                else
                  Icon(Icons.radio_button_unchecked_rounded, color: cs.outline, size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
            if (onConnect != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: onConnect, child: const Text('Подключить')),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: tile(
                icon: Icons.games_rounded,
                title: 'Lynx (лаунчер)',
                subtitle: 'Движок, проекты, вход через Lynx Auth.',
                connected: nexusOk,
                onConnect: nexusOk ? null : () => _linkProduct(auth, 'nexus', 'Lynx'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Icon(Icons.sync_alt_rounded, size: 28, color: cs.primary.withValues(alpha: 0.85)),
                  const SizedBox(height: 4),
                  Text(
                    'один\nаккаунт',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tile(
                icon: Icons.analytics_rounded,
                title: 'Метрика',
                subtitle: 'Веб-консоль Waypoint: дашборды и ingest.',
                connected: metricOk,
                onConnect: metricOk ? null : () => _linkProduct(auth, 'metric', 'Метрику'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _profileSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _compactThemeTile(
    BuildContext context, {
    required SettingsProvider settings,
    required AppTheme theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selected = settings.currentTheme == theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? cs.secondaryContainer.withValues(alpha: 0.35) : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => unawaited(settings.setTheme(theme)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 22, color: selected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleSmall),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), color: cs.primary, size: 22)
                      : Icon(Icons.circle_outlined, key: const ValueKey('off'), color: cs.outlineVariant, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _themePicker(BuildContext context, SettingsProvider settings) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 480) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SegmentedButton<AppTheme>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: [
                  ButtonSegment<AppTheme>(
                    value: AppTheme.purple,
                    label: const Text('Фиолет'),
                    tooltip: 'Тёмная · фиолетовый акцент',
                    icon: Icon(Icons.dark_mode_outlined, size: 18, color: cs.onSurfaceVariant),
                  ),
                  ButtonSegment<AppTheme>(
                    value: AppTheme.monochrome,
                    label: const Text('Светлая'),
                    tooltip: 'Светлый интерфейс',
                    icon: Icon(Icons.light_mode_outlined, size: 18, color: cs.onSurfaceVariant),
                  ),
                  ButtonSegment<AppTheme>(
                    value: AppTheme.midnight,
                    label: const Text('Синий'),
                    tooltip: 'Тёмная · сине-серая',
                    icon: Icon(Icons.nights_stay_outlined, size: 18, color: cs.onSurfaceVariant),
                  ),
                ],
                selected: {settings.currentTheme},
                onSelectionChanged: (next) {
                  if (next.isNotEmpty) unawaited(settings.setTheme(next.first));
                },
              ),
            ),
          );
        }
        return Column(
          children: [
            _compactThemeTile(
              context,
              settings: settings,
              theme: AppTheme.purple,
              icon: Icons.dark_mode_outlined,
              title: 'Тёмная · фиолетовая',
              subtitle: 'Discord / VS Code vibe',
            ),
            _compactThemeTile(
              context,
              settings: settings,
              theme: AppTheme.monochrome,
              icon: Icons.light_mode_outlined,
              title: 'Светлая',
              subtitle: 'Белый фон, тот же акцент',
            ),
            _compactThemeTile(
              context,
              settings: settings,
              theme: AppTheme.midnight,
              icon: Icons.nights_stay_outlined,
              title: 'Тёмная · сине-серая',
              subtitle: 'Ближе к VS Code Dark+',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final user = auth.user;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль и настройки'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final router = GoRouter.of(context);
              await auth.logout();
              if (!context.mounted) return;
              router.go('/login');
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const maxContent = 560.0;
          final hPad = w > maxContent + 40 ? (w - maxContent) / 2 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContent),
                child: Column(
                  children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: cs.primaryContainer,
                          backgroundImage: _newAvatar != null
                              ? FileImage(_newAvatar!)
                              : () {
                                  final url = user?.avatarUrl;
                                  return (url != null && url.isNotEmpty) ? NetworkImage(url) : null;
                                }(),
                          child: user?.avatarUrl == null && _newAvatar == null
                              ? Icon(Icons.person_rounded, size: 50, color: cs.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.primary,
                            child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _profileSection(
                  context,
                  title: 'Аккаунт',
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(labelText: 'ФИО'),
                          validator: (v) => (v?.isEmpty ?? true) ? 'Введите ФИО' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: user?.email,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: user?.nickname,
                          readOnly: true,
                          decoration: const InputDecoration(labelText: 'Никнейм'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: user?.phone,
                          decoration: const InputDecoration(labelText: 'Телефон'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saveProfile,
                          child: const Text('Сохранить изменения'),
                        ),
                      ],
                    ),
                  ),
                ),
                _profileSection(
                  context,
                  title: 'Доступ к продуктам',
                  subtitle:
                      'Регистрация в приложении открывает только доступ к лаунчеру Lynx; на сайте Метрики — только веб-консоль, пока вы не подключите второй продукт паролем (ниже).',
                  child: _productAccessPanel(context, auth, user),
                ),
                _profileSection(
                  context,
                  title: 'Сервер Lynx',
                  subtitle:
                      'Адрес Lynx Hub (например lynx-hub.ru). Вход и ядро подключаются автоматически.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Сервер Lynx',
                          hintText: 'lynx-hub.ru',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          await auth.setApiBaseUrl(_serverUrlController.text);
                          if (!context.mounted) return;
                          await context.read<ProjectProvider>().loadProjects();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL сервера сохранён. При необходимости войдите снова.'),
                            ),
                          );
                        },
                        child: const Text('Сохранить URL сервера'),
                      ),
                    ],
                  ),
                ),
                _profileSection(
                  context,
                  title: 'Привязка ВК (клиент)',
                  subtitle: 'Код для бота в сообществе. Полная настройка VK-модуля — на сайте WaypointMetrik.',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final ctx = context;
                        final messenger = ScaffoldMessenger.of(ctx);
                        final data = await auth.fetchVkBindCode();
                        if (!ctx.mounted) return;
                        if (data == null) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Не удалось получить код')),
                          );
                          return;
                        }
                        final code = data['code']?.toString() ?? '';
                        final hint = data['hint']?.toString() ?? '';
                        if (!ctx.mounted) return;
                        showDialog<void>(
                          context: ctx,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Привязка ВК'),
                            content: SelectableText(
                              'Код: $code\n\n$hint\n\nВ боте группы напишите: привязать $code',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Копировать код'),
                              ),
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Получить код для бота ВК'),
                    ),
                  ),
                ),
                _profileSection(
                  context,
                  title: 'Тема оформления',
                  subtitle: 'На широком экране — переключатель сегментами; на узком — список.',
                  child: _themePicker(context, settings),
                ),
                _profileSection(
                  context,
                  title: 'Модули и навигация',
                  subtitle:
                      'Lynx Hub (главная), проекты, мессенджер, новости (RSS) и Lynx Cloud (каталог JSON). Остальные пункты — в разработке.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.swap_vert_rounded, color: cs.onPrimaryContainer, size: 22),
                        ),
                        title: const Text('Порядок в боковой панели'),
                        subtitle: const Text('Перетащите пункты в удобном порядке'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReorderModulesScreen()),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Видимые модули',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...availableModules.map(
                        (module) {
                          final id = module['id']?.toString() ?? '';
                          final title = module['title'] as String;
                          final on = settings.enabledModules.contains(id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: cs.surfaceContainerHigh.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              child: SwitchListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  id == 'home'
                                      ? 'Всегда в меню (отключить нельзя)'
                                      : on
                                          ? 'Показывается в нижней или боковой навигации'
                                          : 'Скрыт из навигации',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                ),
                                value: on,
                                onChanged: id == 'home'
                                    ? null
                                    : (v) {
                                        settings.toggleModule(id, v);
                                      },
                                secondary: Icon(module['icon'] as IconData, size: 24, color: cs.primary),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                _profileSection(
                  context,
                  title: 'Юридическая информация',
                  subtitle: 'Черновики документов — замените на утверждённые тексты перед релизом.',
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
                        title: const Text('Политика конфиденциальности'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/legal?tab=privacy'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.article_outlined, color: cs.primary),
                        title: const Text('Условия использования'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/legal?tab=terms'),
                      ),
                    ],
                  ),
                ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}