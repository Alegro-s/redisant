import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../app/providers/settings_provider.dart';
import '../../../app/widgets/lynx_logo.dart';
import '../../../app/widgets/lynx_external_links.dart';
import '../providers/auth_provider.dart';

String? _validateStrongPassword(String? v) {
  if (v == null || v.isEmpty) return 'Введите пароль';
  if (v.length < 10) return 'Минимум 10 символов';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Нужна строчная латинская буква';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Нужна заглавная латинская буква';
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Нужна цифра';
  if (!RegExp(r'[^a-zA-Z0-9]').hasMatch(v)) {
    return 'Нужен спецсимвол (например !@#%)';
  }
  return null;
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();

  final Set<String> _selectedInterests = {};
  File? _avatarFile;
  bool _isLoading = false;
  String? _error;
  int _currentStep = 0;

  static const String _kHomeModuleId = 'home';

  List<Map<String, dynamic>> get _optionalModules => [
        for (final m in availableModules)
          if (m['id']?.toString() != _kHomeModuleId) m,
      ];

  Map<String, dynamic>? get _homeModule {
    for (final m in availableModules) {
      if (m['id']?.toString() == _kHomeModuleId) return m;
    }
    return null;
  }

  void _nextPage() {
    if (_currentStep == 0 && !_formKey.currentState!.validate()) return;
    setState(() => _currentStep++);
  }

  void _prevPage() {
    if (_currentStep <= 0) return;
    setState(() => _currentStep--);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _avatarFile = File(image.path));
    }
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final outcome = await auth.register(
      email: _emailController.text,
      phone: _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : null,
      fullName: _fullNameController.text,
      nickname: _nicknameController.text,
      password: _passwordController.text,
      settings: {'interests': _selectedInterests.toList()},
    );

    if (outcome.error != null) {
      setState(() {
        _error = outcome.error;
        _isLoading = false;
      });
    } else if (outcome.pendingEmail != null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go('/verify-email?email=${Uri.encodeComponent(outcome.pendingEmail!)}');
    } else {
      if (!mounted) return;
      await context.read<SettingsProvider>().applyEnabledModulesFromOnboarding(
        _selectedInterests,
      );
      if (_avatarFile != null) {
        try {
          final fileName = _avatarFile!.path.split(RegExp(r'[\\/]+')).last;
          final bytes = await _avatarFile!.readAsBytes();
          await auth.uploadAvatarBytes(bytes: bytes, fileName: fileName);
        } catch (_) {
        }
      }
      if (mounted) {
        context.go('/engine-install');
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final isCompact = mq.size.width < 520;
    final bottomInset = mq.viewInsets.bottom;

    final gradientColors = isDark
        ? const [Color(0xFF1a0f2e), Color(0xFF0d1117), Color(0xFF14121c)]
        : const [Color(0xFFfaf5ff), Color(0xFFFFFFFF), Color(0xFFF4F4F5)];

    return Scaffold(
      backgroundColor: gradientColors.first,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        title: Text(
          'Регистрация',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
          ).copyWith(inherit: false),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 28,
                  0,
                  isCompact ? 16 : 28,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: LynxLogo(size: 36, compact: true)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (_currentStep + 1) / 3),
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: cs.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Material(
                        color: Theme.of(context).cardTheme.color ?? cs.surface,
                        elevation: isDark ? 0 : 2,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                          side: BorderSide(
                            color: cs.primary.withValues(
                              alpha: isDark ? 0.4 : 0.18,
                            ),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            final offset =
                                Tween<Offset>(
                                  begin: const Offset(0.04, 0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: anim,
                                    curve: Curves.easeOutCubic,
                                  ),
                                );
                            return FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: offset,
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentStep),
                            child: _stepBody(
                              bottomInset: bottomInset,
                              isCompact: isCompact,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 2),
                      child: Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => context.go('/login'),
                          child: const Text('Вход'),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => openLynxLegal(context, tab: 'privacy'),
                            child: const Text('Конфиденциальность'),
                          ),
                          Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => openLynxLegal(context, tab: 'terms'),
                            child: const Text('Условия'),
                          ),
                        ],
                      ),
                    ),
                    if (bottomInset <= 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
                        child: _buildNavBar(isCompact),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(bool isCompact) {
    final nextLabel = _currentStep < 2 ? 'Далее' : 'Завершить';
    return Row(
      children: [
        if (_currentStep > 0)
          TextButton(
            onPressed: _isLoading ? null : _prevPage,
            child: const Text('Назад'),
          )
        else
          const SizedBox(width: 8),
        const Spacer(),
        FilledButton(
          onPressed: _isLoading
              ? null
              : () {
                  if (_currentStep < 2) {
                    _nextPage();
                  } else {
                    _register();
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12 : 20,
                  ),
                  child: Text(nextLabel),
                ),
        ),
      ],
    );
  }

  Widget _stepBody({required double bottomInset, required bool isCompact}) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(bottomInset: bottomInset);
      case 1:
        return _buildStep2(isCompact: isCompact, bottomInset: bottomInset);
      default:
        return _buildStep3(bottomInset: bottomInset);
    }
  }

  Widget _buildStep1({required double bottomInset}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) => (v != null && v.contains('@'))
                  ? null
                  : 'Введите корректный email',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Телефон (необязательно)',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'ФИО'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v != null && v.isNotEmpty) ? null : 'Введите ФИО',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(labelText: 'Никнейм'),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v != null && v.isNotEmpty) ? null : 'Введите никнейм',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Пароль'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _nextPage(),
              validator: _validateStrongPassword,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2({required bool isCompact, required double bottomInset}) {
    final cs = Theme.of(context).colorScheme;
    final w = MediaQuery.sizeOf(context).width;
    final useDesktopPicker = w >= 640;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Отметьте модули для бокового меню. Lynx Hub включён автоматически. '
            'Снятые пункты можно снова включить в профиле.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (useDesktopPicker) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Быстрый выбор:',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedInterests
                        ..clear()
                        ..addAll(
                          _optionalModules
                              .map((m) => m['id']?.toString())
                              .whereType<String>(),
                        );
                    });
                  },
                  child: const Text('Все модули'),
                ),
                TextButton(
                  onPressed: () => setState(_selectedInterests.clear),
                  child: const Text('Снять выбор'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_homeModule != null) _registerModuleDesktopHomeCard(_homeModule!, cs),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final maxExt = c.maxWidth >= 1000
                    ? 340.0
                    : (c.maxWidth >= 780 ? 300.0 : 260.0);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxExt,
                    mainAxisExtent: 112,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _optionalModules.length,
                  itemBuilder: (context, index) {
                    final module = _optionalModules[index];
                    return _registerModuleDesktopCard(module, cs);
                  },
                );
              },
            ),
          ] else ...[
            LayoutBuilder(
              builder: (context, c) {
                final cross = isCompact ? 1 : 2;
                final aspect = cross == 1 ? 3.2 : 2.0;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    childAspectRatio: aspect,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _optionalModules.length,
                  itemBuilder: (context, index) {
                    final module = _optionalModules[index];
                    final mid = module['id']?.toString() ?? '';
                    final isSelected = _selectedInterests.contains(mid);
                    final icon = module['icon'] is IconData
                        ? module['icon'] as IconData
                        : Icons.widgets_outlined;
                    return FilterChip(
                      label: Text(
                        module['title']?.toString() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      avatar: Icon(icon, size: 18),
                      selected: isSelected,
                      showCheckmark: false,
                      onSelected: mid.isEmpty
                          ? null
                          : (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedInterests.add(mid);
                                } else {
                                  _selectedInterests.remove(mid);
                                }
                              });
                            },
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _registerModuleDesktopHomeCard(
    Map<String, dynamic> module,
    ColorScheme cs,
  ) {
    final icon = module['icon'] is IconData
        ? module['icon'] as IconData
        : Icons.home_work_outlined;
    final subtitle = module['subtitle']?.toString() ?? '';
    return Material(
      color: cs.primaryContainer.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 32, color: cs.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module['title']?.toString() ?? 'Lynx Hub',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle.isEmpty
                        ? 'Всегда в боковом меню.'
                        : '$subtitle · всегда в боковом меню.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_outline_rounded, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _registerModuleDesktopCard(
    Map<String, dynamic> module,
    ColorScheme cs,
  ) {
    final mid = module['id']?.toString() ?? '';
    final selected = _selectedInterests.contains(mid);
    final icon = module['icon'] is IconData
        ? module['icon'] as IconData
        : Icons.widgets_outlined;
    final subtitle = module['subtitle']?.toString() ?? '';

    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.55)
          : cs.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: mid.isEmpty
            ? null
            : () {
                setState(() {
                  if (selected) {
                    _selectedInterests.remove(mid);
                  } else {
                    _selectedInterests.add(mid);
                  }
                });
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module['title']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: mid.isEmpty
                    ? null
                    : (v) {
                        setState(() {
                          if (v ?? false) {
                            _selectedInterests.add(mid);
                          } else {
                            _selectedInterests.remove(mid);
                          }
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep3({required double bottomInset}) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Добавьте аватар (необязательно)',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: cs.primaryContainer,
                backgroundImage: _avatarFile != null
                    ? FileImage(_avatarFile!)
                    : null,
                child: _avatarFile == null
                    ? Icon(Icons.camera_alt, size: 40, color: cs.primary)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Вы сможете изменить аватар позже в настройках.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurfaceVariant,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Material(
              color: cs.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.error, fontSize: 13, height: 1.35),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
