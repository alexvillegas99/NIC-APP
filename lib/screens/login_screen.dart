import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:nic_pre_u/screens/privacy_policy_screen.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const bool _devAutoLogin = bool.fromEnvironment('NIC_DEV_AUTO_LOGIN');
  static const String _devLoginCedula = String.fromEnvironment(
    'NIC_DEV_LOGIN_CEDULA',
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  static const _storage = FlutterSecureStorage();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _rememberMe = false;
  bool _policyAccepted = true; // pre-aceptado por defecto

  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryDevAutoLogin());
  }

  /// Precarga el email/cédula si el usuario marcó "Recordar mi cuenta"
  Future<void> _loadSavedCredentials() async {
    final remember = await _storage.read(key: 'remember_flag');
    if (remember == 'true') {
      final savedEmail = await _storage.read(key: 'remember_email');
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    }
  }

  Future<void> _tryDevAutoLogin() async {
    if (!_devAutoLogin || _devLoginCedula.isEmpty || !mounted) return;
    final cedula = _devLoginCedula.trim();
    _emailController.text = cedula;
    _passwordController.text = cedula;
    setState(() => _isLoading = true);
    await _authService.login(
      cedula,
      cedula,
      context,
      mode: LoginMode.credential,
      cedula: cedula,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Detecta si el input parece ser una cédula ecuatoriana (10 dígitos)
  bool _isCedula(String value) {
    return RegExp(r'^\d{10}$').hasMatch(value.trim());
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_policyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes aceptar la Política de Privacidad para continuar',
            style: DS.poppins(size: 14, color: Colors.white),
          ),
          backgroundColor: DS.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final input = _emailController.text.trim();

    // Guardar o limpiar credenciales según "Recordar mi cuenta"
    if (_rememberMe) {
      await _storage.write(key: 'remember_flag', value: 'true');
      await _storage.write(key: 'remember_email', value: input);
    } else {
      await _storage.delete(key: 'remember_flag');
      await _storage.delete(key: 'remember_email');
    }

    if (!mounted) return;
    if (_isCedula(input)) {
      // Login por cédula (usuarios admin/EC2/local con cédula como credencial)
      await _authService.login(
        input,
        _passwordController.text,
        context,
        mode: LoginMode.credential,
        cedula: input,
      );
    } else {
      // Login clásico por email + contraseña
      if (!mounted) return;
      await _authService.login(
        input,
        _passwordController.text,
        context,
        mode: LoginMode.classic,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _submitGoogle() async {
    if (!_policyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes aceptar la Política de Privacidad para continuar',
            style: DS.poppins(size: 14, color: Colors.white),
          ),
          backgroundColor: DS.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    setState(() => _isGoogleLoading = true);
    HapticFeedback.lightImpact();
    await _authService.loginWithGoogle(context);
    if (mounted) setState(() => _isGoogleLoading = false);
  }

  void _showForgotPassword() {
    final ctrl = TextEditingController();
    bool sending = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DS.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(Icons.lock_reset_rounded, size: 40, color: DS.purple),
              const SizedBox(height: 12),
              Text(
                'Recuperar contraseña',
                style: DS.poppins(
                  size: 20,
                  weight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa tu email y te enviaremos un enlace.',
                textAlign: TextAlign.center,
                style: DS.poppins(size: 14, color: DS.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.emailAddress,
                style: DS.poppins(size: 16, color: DS.textPrimary),
                decoration: _inputDeco(
                  hint: 'tu@email.com',
                  icon: Icons.mail_outline_rounded,
                ),
              ),
              const SizedBox(height: 20),
              NicButton(
                text: sending ? 'Enviando...' : 'Enviar enlace',
                isLoading: sending,
                color: DS.purple,
                onPressed: () async {
                  final email = ctrl.text.trim();
                  if (email.isEmpty || !email.contains('@')) return;
                  set(() => sending = true);
                  try {
                    final apiUrl = dotenv.env['API_URL'] ?? '';
                    await http.post(
                      Uri.parse('$apiUrl/auth/forgot-password'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({'email': email}),
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Revisa tu correo $email',
                            style: DS.poppins(size: 14, color: Colors.white),
                          ),
                          backgroundColor: DS.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                    }
                  } catch (_) {
                    if (ctx.mounted) set(() => sending = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: DS.poppins(size: 14, color: DS.textSecondary),
      prefixIcon: Icon(icon, color: DS.textSecondary, size: 20),
      suffixIcon: suffix != null
          ? Padding(padding: const EdgeInsets.only(right: 10), child: suffix)
          : null,
      filled: true,
      fillColor: DS.cardSoft,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DS.divider, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DS.purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DS.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DS.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        // ── NIC logo ──
                        Image.asset(
                          'assets/imagenes/logonic.png',
                          height: 54,
                          fit: BoxFit.contain,
                          semanticLabel: 'NIC Academy',
                        ),
                        const SizedBox(height: 28),

                        // ── Title ──
                        Text(
                          'Iniciar sesión',
                          style: DS.poppins(
                            size: 26,
                            weight: FontWeight.w700,
                            color: DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Por favor, ingresar su email y contraseña\npara poder continuar.',
                          textAlign: TextAlign.center,
                          style: DS.poppins(
                            size: 14,
                            color: DS.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Form ──
                        Form(key: _formKey, child: _buildLoginForm()),

                        const SizedBox(height: 14),

                        // ── Olvidaste contraseña ──
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _showForgotPassword,
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              style: DS.poppins(
                                size: 13,
                                weight: FontWeight.w600,
                                color: DS.purple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Remember me ──
                        GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _rememberMe
                                      ? DS.purple
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _rememberMe
                                        ? DS.purple
                                        : DS.textSecondary,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: _rememberMe
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Recordar mi cuenta',
                                style: DS.poppins(
                                  size: 14,
                                  color: DS.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── Política de privacidad ──
                        _buildPolicyCheckbox(),

                        const SizedBox(height: 24),

                        // ── Aceptar button ──
                        NicButton(
                          text: 'Aceptar',
                          isLoading: _isLoading,
                          color: DS.purple,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 24),

                        // ── Divider ──
                        Row(
                          children: [
                            const Expanded(child: Divider(color: DS.divider)),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Text(
                                'o iniciar sesión con',
                                style: DS.poppins(
                                  size: 12,
                                  color: DS.textSecondary,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: DS.divider)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Google sign-in ──
                        _SocialButton(
                          label: 'Continuar con Google',
                          icon: Icons.g_mobiledata_rounded,
                          isLoading: _isGoogleLoading,
                          onTap: _submitGoogle,
                        ),
                        const SizedBox(height: 28),

                        // ── Crear cuenta ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No tienes una cuenta? ',
                              style: DS.poppins(
                                size: 14,
                                color: DS.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: Text(
                                'Crear cuenta',
                                style: DS.poppins(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: DS.purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Formulario unificado (email o cédula) ────────────────────────────────

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Email o número de cédula',
          style: DS.poppins(
            size: 13,
            weight: FontWeight.w600,
            color: DS.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: DS.poppins(size: 16, color: DS.textPrimary),
          decoration: _inputDeco(
            hint: 'usuario@email.com o 10 dígitos',
            icon: Icons.person_outline_rounded,
          ),
          validator: (v) {
            final val = (v ?? '').trim();
            if (val.isEmpty) return 'Ingresa tu email o cédula';
            // Acepta email válido o cédula de 10 dígitos
            final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(val);
            final isCedula = RegExp(r'^\d{10}$').hasMatch(val);
            if (!isEmail && !isCedula) {
              return 'Ingresa un email válido o cédula de 10 dígitos';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Contraseña',
          style: DS.poppins(
            size: 13,
            weight: FontWeight.w600,
            color: DS.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: DS.poppins(size: 16, color: DS.textPrimary),
          decoration: _inputDeco(
            hint: '••••••••••',
            icon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: DS.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
        ),
      ],
    );
  }

  // ─── Checkbox política de privacidad ─────────────────────────────────────

  Widget _buildPolicyCheckbox() {
    return GestureDetector(
      onTap: () => setState(() => _policyAccepted = !_policyAccepted),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _policyAccepted ? DS.purple : Colors.transparent,
                border: Border.all(
                  color: _policyAccepted ? DS.purple : DS.textSecondary,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: _policyAccepted
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              children: [
                Text(
                  'Acepto la ',
                  style: DS.poppins(size: 13, color: DS.textSecondary),
                ),
                GestureDetector(
                  onTap: () => PrivacyPolicyScreen.show(context),
                  child: Text(
                    'Política de Privacidad y Protección de Datos',
                    style: DS.poppins(
                      size: 13,
                      weight: FontWeight.w600,
                      color: DS.purple,
                    ),
                  ),
                ),
                Text(
                  ' de NIC Academy (LOPDP Ecuador · GDPR)',
                  style: DS.poppins(size: 13, color: DS.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══ Social Button ════════════════════════════════════════════════════════
class _SocialButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: DS.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DS.divider),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DS.purple,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: DS.textSecondary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: DS.poppins(
                          size: 12,
                          weight: FontWeight.w600,
                          color: DS.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
