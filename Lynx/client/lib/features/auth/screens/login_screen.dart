import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../app/widgets/lynx_logo.dart';
import '../../../app/widgets/lynx_external_links.dart';

enum _LoginPhase { credentials, chooseChannel, enterCode }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.bootstrapped && auth.isAuthenticated) {
        context.go('/');
      }
    });
  }

  _LoginPhase _phase = _LoginPhase.credentials;
  bool _otpExpanded = false;
  bool _isLoading = false;
  String? _error;

  List<String> _channels = [];
  String? _selectedChannel;
  String? _challengeId;
  String? _sessionToken;
  String? _deliveryHint;

  String _channelLabel(String c) {
    return switch (c) {
      'email' => 'Почта',
      'sms' => 'SMS (телефон в профиле)',
      'nexus' => 'Lynx Auth',
      _ => c,
    };
  }

  void _resetOtp() {
    _channels = [];
    _selectedChannel = null;
    _challengeId = null;
    _sessionToken = null;
    _deliveryHint = null;
    _codeController.clear();
    _phase = _LoginPhase.credentials;
  }

  void _goVerifyIfNeeded(String? err) {
    if (err == null || !err.startsWith('EMAIL_VERIFY_REQUIRED|')) return;
    final email = err.substring('EMAIL_VERIFY_REQUIRED|'.length);
    context.go('/verify-email?email=${Uri.encodeComponent(email)}');
  }

  Future<void> _directLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final err = await auth.login(
      _loginController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      if (err.startsWith('EMAIL_VERIFY_REQUIRED|')) {
        _goVerifyIfNeeded(err);
        return;
      }
      setState(() => _error = err);
      return;
    }
    context.go('/');
  }

  Future<void> _afterPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final (channels, err) = await auth.loginOtpPreview(
      _loginController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (err != null) {
      if (err.startsWith('EMAIL_VERIFY_REQUIRED|')) {
        if (mounted) {
          setState(() => _isLoading = false);
          _goVerifyIfNeeded(err);
        }
        return;
      }
      setState(() {
        _error = err;
        _isLoading = false;
      });
      return;
    }
    if (channels.isEmpty) {
      setState(() {
        _error = 'Нет каналов для кода';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _channels = channels;
      _selectedChannel = channels.first;
      _phase = _LoginPhase.chooseChannel;
      _isLoading = false;
    });
  }

  Future<void> _sendCode() async {
    if (_selectedChannel == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final (data, err) = await auth.loginOtpRequestCode(
      login: _loginController.text,
      password: _passwordController.text,
      channel: _selectedChannel!,
    );
    if (!mounted) return;
    if (err != null || data == null) {
      if (err != null && err.startsWith('EMAIL_VERIFY_REQUIRED|')) {
        if (mounted) {
          setState(() => _isLoading = false);
          _goVerifyIfNeeded(err);
        }
        return;
      }
      setState(() {
        _error = err ?? 'Ошибка';
        _isLoading = false;
      });
      return;
    }
    final id = data['challenge_id']?.toString();
    final tok = data['session_token']?.toString();
    final hint = data['delivery_hint']?.toString() ?? '';
    if (id == null || tok == null) {
      setState(() {
        _error = 'Некорректный ответ сервера';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _challengeId = id;
      _sessionToken = tok;
      _deliveryHint = hint;
      _phase = _LoginPhase.enterCode;
      _codeController.clear();
      _isLoading = false;
    });
  }

  Future<void> _fetchNexusCode() async {
    if (_challengeId == null || _sessionToken == null) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final (code, err) = await auth.loginOtpFetchNexusCode(
      challengeId: _challengeId!,
      sessionToken: _sessionToken!,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (code != null) {
      _codeController.text = code;
      setState(() {});
    }
  }

  Future<void> _verifyCode() async {
    if (_challengeId == null || _sessionToken == null) return;
    final raw = _codeController.text.replaceAll(RegExp(r'\s'), '');
    if (raw.length != 6) {
      setState(() => _error = 'Введите 6 цифр');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await auth.loginOtpVerify(
      challengeId: _challengeId!,
      sessionToken: _sessionToken!,
      code: raw,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
    } else {
      context.go('/');
    }
  }

  void _goBack() {
    setState(() {
      _error = null;
      if (_phase == _LoginPhase.enterCode) {
        _phase = _LoginPhase.chooseChannel;
        _challengeId = null;
        _sessionToken = null;
        _deliveryHint = null;
        _codeController.clear();
      } else if (_phase == _LoginPhase.chooseChannel) {
        _phase = _LoginPhase.credentials;
        _resetOtp();
      }
    });
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    final gradientColors = isDark
        ? const [Color(0xFF1a0f2e), Color(0xFF0d1117), Color(0xFF0d1117)]
        : const [Color(0xFFfaf5ff), Color(0xFFFFFFFF), Color(0xFFF4F4F5)];

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: gradientColors.first,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        title: Text(
          'Вход',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600).copyWith(inherit: false),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 32,
                8,
                isCompact ? 16 : 32,
                24 + bottomInset,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: LynxLogo(size: isCompact ? 44 : 48)),
                    const SizedBox(height: 20),
                    Material(
                      color: Theme.of(context).cardTheme.color ?? cs.surface,
                      elevation: isDark ? 0 : 1,
                      shadowColor: Colors.black38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                        side: BorderSide(
                          color: cs.primary.withValues(alpha: isDark ? 0.45 : 0.22),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Form(
                          key: _formKey,
                          child: _buildFormColumn(cs),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      children: [
                        TextButton(
                          onPressed: () => openLynxLegal(context, tab: 'privacy'),
                          child: const Text('Конфиденциальность'),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                        TextButton(
                          onPressed: () => openLynxLegal(context, tab: 'terms'),
                          child: const Text('Условия'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormColumn(ColorScheme cs) {
    String title;
    String subtitle;
    if (_phase == _LoginPhase.chooseChannel) {
      title = 'Куда отправить код';
      subtitle =
          'Выберите канал доставки одноразового кода. На сервере должны быть настроены почта/SMS или режим отладки.';
    } else if (_phase == _LoginPhase.enterCode) {
      title = 'Код подтверждения';
      subtitle = _deliveryHint != null && _deliveryHint!.isNotEmpty
          ? _deliveryHint!
          : 'Введите 6 цифр из письма, SMS или Lynx Auth.';
    } else if (_otpExpanded) {
      title = 'Вход с кодом';
      subtitle =
          'Сначала проверяется пароль, затем отправляется код (почта, SMS или Lynx Auth). Для SMS укажите телефон при регистрации.';
    } else {
      title = 'Учётная запись';
      subtitle =
          'Войдите по email или нику и паролю. Нет аккаунта — кнопка «Регистрация» ниже.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_phase != _LoginPhase.credentials)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _isLoading ? null : _goBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Назад'),
            ),
          ),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (_phase == _LoginPhase.credentials) ...[
          TextFormField(
            controller: _loginController,
            enabled: !_isLoading,
            decoration: const InputDecoration(
              labelText: 'Email или никнейм',
              prefixIcon: Icon(Icons.alternate_email_outlined),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите логин' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            textInputAction: TextInputAction.done,
            onEditingComplete: () => FocusScope.of(context).unfocus(),
            validator: (v) => (v == null || v.length < 3) ? 'Слишком короткий пароль' : null,
          ),
        ],
        if (_phase == _LoginPhase.chooseChannel) ...[
          Text(
            'Логин: ${_loginController.text.trim()}',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: _channels.map((c) {
              final sel = _selectedChannel == c;
              return ChoiceChip(
                label: Text(
                  _channelLabel(c),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: sel,
                onSelected: _isLoading ? null : (_) => setState(() => _selectedChannel = c),
              );
            }).toList(),
          ),
        ],
        if (_phase == _LoginPhase.enterCode) ...[
          if (_deliveryHint != null && _deliveryHint!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _deliveryHint!,
                style: TextStyle(fontSize: 13, color: cs.primary),
              ),
            ),
          TextFormField(
            controller: _codeController,
            enabled: !_isLoading,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Код из письма / SMS / Lynx',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            onFieldSubmitted: (_) => _verifyCode(),
            validator: (_) => null,
          ),
          if (_selectedChannel == 'nexus') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _fetchNexusCode,
              icon: const Icon(Icons.smartphone_outlined, size: 18),
              label: const Text('Показать код (Lynx Auth)'),
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              color: cs.error,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (_phase == _LoginPhase.credentials && !_otpExpanded) ...[
          Center(
            child: SizedBox(
              width: 240,
              child: FilledButton(
                onPressed: _isLoading ? null : _directLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Войти'),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _otpExpanded = true;
                        _error = null;
                      }),
              child: const Text('Вход с кодом на почту / SMS / Lynx'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () => context.go('/register'),
              child: const Text('Регистрация'),
            ),
          ),
        ],
        if (_phase == _LoginPhase.credentials && _otpExpanded) ...[
          FilledButton(
            onPressed: _isLoading ? null : _afterPassword,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Продолжить'),
          ),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _otpExpanded = false;
                      _resetOtp();
                      _error = null;
                    }),
            child: const Text('Обычный вход без кода'),
          ),
        ],
        if (_phase == _LoginPhase.chooseChannel)
          FilledButton(
            onPressed: _isLoading ? null : _sendCode,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Выслать код'),
          ),
        if (_phase == _LoginPhase.enterCode)
          FilledButton(
            onPressed: _isLoading ? null : _verifyCode,
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Войти'),
          ),
      ],
    );
  }
}
