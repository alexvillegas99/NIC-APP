import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/widgets/background_shapes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cedulaController = TextEditingController();

  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _credentialMode = false; // modo credencial: solo cédula

  // Colores del diseño
  static const Color bg = Color(0xFF0E0F16);
  static const Color card = Color(0xFF111320);
  static const Color textPrimary = Color(0xFFEDEDED);
  static const Color textSecondary = Color(0xFF9EA3B0);
  static const Color accent = Color(0xFF7C3AED);
  static const Color inputFill = Color(0xFF15182A);
  static const double radius = 12;

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        content: Row(
          children: const [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Iniciando sesión...", style: TextStyle(color: textPrimary)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    const borderSide = BorderSide(color: accent, width: 1.2);
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: inputFill,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Color(0xFF2A2E45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: borderSide,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _credentialMode
        ? _cedulaController.text.trim()
        : _emailController.text.trim();

    final password = _credentialMode
        ? _cedulaController.text.trim()
        : _passwordController.text;

    _showLoadingDialog(context);

    await _authService.login(
      username,
      password,
      context,
      mode: _credentialMode ? LoginMode.credential : LoginMode.classic,
      cedula: _credentialMode ? _cedulaController.text.trim() : null,
    );

    if (mounted) Navigator.of(context).pop(); // cerrar loading
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const BackgroundShapes(), // comenta si quieres fondo plano
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Image.asset(
                          'assets/imagenes/logo.png',
                          height: 64,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),

                      // Título
                      const Text(
                        'Iniciar sesión',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Por favor, ingresa tus credenciales\npara poder continuar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Card contenedora
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: card.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1D2136)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: _credentialMode
                                ? _buildCedulaForm()
                                : _buildEmailPasswordForm(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Footer link (toggle de modo)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _credentialMode = !_credentialMode;
                          });
                        },
                        child: Text(
                          _credentialMode
                              ? 'Iniciar sesión con email y contraseña'
                              : 'Iniciar sesión con credencial',
                          style: const TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Form clásico: Email + Password ---
  Widget _buildEmailPasswordForm() {
    return Column(
      key: const ValueKey('form_email_password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ingresa tu email',
          style: TextStyle(color: textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: textPrimary),
          decoration: _inputDecoration(
            label: 'email@example.com',
            icon: Icons.mail_outline,
          ),
          validator: (v) {
            if (_credentialMode) return null;
            if (v == null || v.trim().isEmpty) return 'Ingresa tu email';
            final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());
            return ok ? null : 'Email inválido';
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'Ingresar contraseña',
          style: TextStyle(color: textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: textPrimary),
          decoration: _inputDecoration(
            label: '••••••••',
            icon: Icons.lock_outline,
            suffix: IconButton(
              onPressed: () => setState(() {
                _obscurePassword = !_obscurePassword;
              }),
              icon: const Icon(Icons.visibility, color: textSecondary),
            ),
          ),
          validator: (v) {
            if (_credentialMode) return null;
            if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
            return null;
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: const Text(
              'INICIAR SESIÓN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  // --- Form credencial: solo Cédula ---
  Widget _buildCedulaForm() {
    return Column(
      key: const ValueKey('form_credencial'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ingresa tu cédula',
          style: TextStyle(color: textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cedulaController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: textPrimary),
          decoration: _inputDecoration(
            label: 'Cédula',
            icon: Icons.badge_outlined,
          ),
          validator: (v) {
            if (!_credentialMode) return null;
            final val = (v ?? '').trim();
            if (val.isEmpty) return 'Ingresa tu cédula';
            if (val.length != 10) return 'Cédula inválida (10 dígitos)';
            return null;
          },
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: const Text(
              'Aceptar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
