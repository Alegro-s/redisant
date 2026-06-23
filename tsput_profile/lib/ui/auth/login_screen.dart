import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../core/constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/student_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _obscurePassword = true;

  late final AnimationController _intro;
  late final Animation<double> _logoLift;
  late final Animation<double> _logoScale;
  late final Animation<double> _headerOpacity;
  late final Animation<double> _formOpacity;
  late final Animation<double> _loginReveal;
  late final Animation<double> _passwordReveal;
  late final Animation<double> _extrasReveal;
  late final Animation<double> _buttonReveal;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );

    _logoLift = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.42, curve: Curves.easeInOutCubic),
    );
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.02), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 58),
    ]).animate(CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
    ));

    _headerOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.38, 0.58, curve: Curves.easeOut),
    );
    _formOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.48, 0.72, curve: Curves.easeOut),
    );
    _loginReveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.50, 0.72, curve: Curves.easeOutCubic),
    );
    _passwordReveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.58, 0.80, curve: Curves.easeOutCubic),
    );
    _extrasReveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.66, 0.86, curve: Curves.easeOutCubic),
    );
    _buttonReveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.72, 0.94, curve: Curves.easeOutCubic),
    );

    _prefillSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _intro.forward();
    });
  }

  Future<void> _prefillSavedCredentials() async {
    final saved = await AuthService.getSavedCredentials();
    if (!mounted || saved == null) return;
    setState(() {
      _loginController.text = saved['login']!;
      _passwordController.text = saved['password']!;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  
  Widget _revealChild(Animation<double> progress, Widget child) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t.clamp(0.001, 1.0),
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, -10 * (1 - t)),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final screenH = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) {
            final lift = _logoLift.value;
            final logoTop = _lerp(screenH * 0.26, 28.0, lift);
            final logoSize = _lerp(112.0, 88.0, lift);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Column(
                    children: [
                      SizedBox(height: logoTop + logoSize + 18),
                      FadeTransition(
                        opacity: _headerOpacity,
                        child: Column(
                          children: [
                            Text(
                              AppConstants.appName,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppConstants.appSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppConstants.secondaryColor,
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _formOpacity,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _revealChild(
                                _loginReveal,
                                _field(
                                  controller: _loginController,
                                  label: 'Логин',
                                  hint: 'Логин, почта или ФИО',
                                  icon: PhosphorIconsRegular.user,
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Введите логин' : null,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _revealChild(
                                _passwordReveal,
                                _field(
                                  controller: _passwordController,
                                  label: 'Пароль',
                                  hint: 'Пароль',
                                  icon: PhosphorIconsRegular.lock,
                                  obscure: _obscurePassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? PhosphorIconsRegular.eye
                                          : PhosphorIconsRegular.eyeSlash,
                                      color: AppConstants.secondaryColor,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.isEmpty) ? 'Введите пароль' : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _revealChild(
                                _extrasReveal,
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                      activeColor: AppConstants.blockBlack,
                                    ),
                                    const Text('Запомнить меня'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              _revealChild(
                                _buttonReveal,
                                SizedBox(
                                  height: AppConstants.buttonHeight,
                                  child: FilledButton(
                                    onPressed:
                                        authProvider.isLoading ? null : () => _login(context),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Войти'),
                                  ),
                                ),
                              ),
                              if (authProvider.error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0x33B91C1C)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        PhosphorIconsRegular.warningCircle,
                                        color: Color(0xFFB91C1C),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          authProvider.error!,
                                          style: const TextStyle(color: Color(0xFFB91C1C)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              Text(
                                'v${AppConstants.appVersion} · ${AppConstants.appName}',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppConstants.secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: logoTop,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Center(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          PhosphorIconsRegular.graduationCap,
                          size: logoSize * 0.8,
                          color: AppConstants.blockBlack,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppConstants.secondaryColor),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Future<void> _login(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.login(
      _loginController.text.trim(),
      _passwordController.text.trim(),
      rememberMe: _rememberMe,
    );
    if (!mounted) return;
    if (ok) {
      await context.read<StudentProvider>().loadStudentData();
      widget.onLoginSuccess?.call();
    }
  }
}
