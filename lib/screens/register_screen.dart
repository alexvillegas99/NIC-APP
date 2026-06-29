import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  static const int _totalSteps = 6;

  // Step 1 — Account type
  String? _accountType; // 'presencial' | 'online' | 'profesor'

  // Step 2 — Personal data
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Step 3 — Password
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showPass = false;
  bool _showConfirm = false;

  // Step 4 — Date of birth
  DateTime? _birthDate;

  // Step 5 — Subjects
  final Set<String> _subjects = {};

  // Step 6 — How did you find us
  String? _source;

  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  double _progressTarget = 0;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim =
        CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _slideCtrl.dispose();
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int next) {
    setState(() => _step = next);
    _progressTarget = (next + 1) / _totalSteps;
    _progressCtrl.animateTo(_progressTarget);
    _slideCtrl
      ..reset()
      ..forward();
  }

  void _next() {
    if (_step < _totalSteps - 1) _goToStep(_step + 1);
  }

  void _back() {
    if (_step > 0) {
      _goToStep(_step - 1);
    } else {
      context.pop();
    }
  }

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _accountType != null;
      case 1:
        return _nombreCtrl.text.trim().isNotEmpty &&
            _apellidoCtrl.text.trim().isNotEmpty &&
            _emailCtrl.text.trim().contains('@');
      case 2:
        return _passCtrl.text.length >= 6 &&
            _passCtrl.text == _confirmCtrl.text;
      case 3:
        return _birthDate != null;
      case 4:
        return _subjects.isNotEmpty;
      case 5:
        return _source != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildProgressBar(),
              Expanded(
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: _buildStep(),
                  ),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final labels = [
      'Tipo de cuenta',
      'Datos personales',
      'Contraseña',
      'Fecha de nacimiento',
      'Materias',
      'Como nos conociste',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _back,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DS.cardSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DS.divider),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: DS.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paso ${_step + 1} de $_totalSteps',
                  style: DS.poppins(
                    size: 12,
                    color: DS.textSecondary,
                  ),
                ),
                Text(
                  labels[_step],
                  style: DS.poppins(
                    size: 16,
                    weight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress bar ────────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AnimatedBuilder(
          animation: _progressAnim,
          builder: (_, __) => LinearProgressIndicator(
            value: (_step + 1) / _totalSteps,
            backgroundColor: DS.divider,
            valueColor: const AlwaysStoppedAnimation(DS.purple),
            minHeight: 5,
          ),
        ),
      ),
    );
  }

  // ─── Step router ─────────────────────────────────────────────────────────────

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return const SizedBox();
    }
  }

  // ─── Step 0: Account type ─────────────────────────────────────────────────

  Widget _buildStep0() {
    final types = [
      {
        'value': 'presencial',
        'label': 'Estudiante presencial',
        'subtitle': 'Asisto a clases en el centro',
        'icon': Icons.school_rounded,
        'color': DS.purple,
      },
      {
        'value': 'online',
        'label': 'Estudiante online',
        'subtitle': 'Tomo clases de forma virtual',
        'icon': Icons.laptop_rounded,
        'color': DS.cyan,
      },
      {
        'value': 'profesor',
        'label': 'Profesor',
        'subtitle': 'Soy docente del centro',
        'icon': Icons.person_rounded,
        'color': DS.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Bienvenido a NIC',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona el tipo de cuenta que deseas crear',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        ...types.map((t) => _AccountTypeCard(
              value: t['value'] as String,
              label: t['label'] as String,
              subtitle: t['subtitle'] as String,
              icon: t['icon'] as IconData,
              color: t['color'] as Color,
              selected: _accountType == t['value'],
              onTap: () => setState(() => _accountType = t['value'] as String),
            )),
      ],
    );
  }

  // ─── Step 1: Personal data ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Tus datos',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ingresa tu nombre, apellido y correo electronico',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        _buildField(
          controller: _nombreCtrl,
          label: 'Nombre',
          icon: Icons.person_outline_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _apellidoCtrl,
          label: 'Apellido',
          icon: Icons.badge_outlined,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _emailCtrl,
          label: 'Correo electronico',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ─── Step 2: Password ─────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Crea tu contraseña',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Minimo 6 caracteres',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        _buildPasswordField(
          controller: _passCtrl,
          label: 'Contraseña',
          show: _showPass,
          onToggle: () => setState(() => _showPass = !_showPass),
        ),
        const SizedBox(height: 14),
        _buildPasswordField(
          controller: _confirmCtrl,
          label: 'Confirmar contraseña',
          show: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
        ),
        if (_confirmCtrl.text.isNotEmpty &&
            _passCtrl.text != _confirmCtrl.text) ...[
          const SizedBox(height: 10),
          Text(
            'Las contraseñas no coinciden',
            style: DS.poppins(size: 12, color: DS.error),
          ),
        ],
      ],
    );
  }

  // ─── Step 3: Birth date ───────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Fecha de nacimiento',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Necesitamos saber tu edad para personalizar tu experiencia',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: DS.cardSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _birthDate != null ? DS.purple : DS.divider,
                width: _birthDate != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DS.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.cake_rounded,
                    color: DS.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _birthDate == null
                        ? 'Seleccionar fecha'
                        : '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}',
                    style: DS.poppins(
                      size: 15,
                      color: _birthDate == null
                          ? DS.textSecondary
                          : DS.textPrimary,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_month_rounded,
                  color: DS.textSecondary.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (_birthDate != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DS.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: DS.purple.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: DS.purple, size: 20),
                const SizedBox(width: 10),
                Text(
                  _calcAge(),
                  style: DS.poppins(
                    size: 13,
                    color: DS.purple,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _calcAge() {
    if (_birthDate == null) return '';
    final now = DateTime.now();
    int age = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      age--;
    }
    return '$age años';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 6, 15),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: DS.purple,
            onPrimary: Colors.white,
            surface: DS.card,
            onSurface: DS.textPrimary,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: DS.card,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  // ─── Step 4: Subjects ─────────────────────────────────────────────────────

  Widget _buildStep4() {
    final subjectData = [
      {'label': 'Biologia', 'icon': Icons.biotech_rounded, 'color': DS.green},
      {
        'label': 'Literatura',
        'icon': Icons.menu_book_rounded,
        'color': DS.orange
      },
      {
        'label': 'Quimica',
        'icon': Icons.science_rounded,
        'color': DS.cyan
      },
      {
        'label': 'Matematica',
        'icon': Icons.functions_rounded,
        'color': DS.blue
      },
      {'label': 'Ingles', 'icon': Icons.language_rounded, 'color': DS.purple},
      {
        'label': 'Informatica',
        'icon': Icons.computer_rounded,
        'color': DS.pink
      },
      {
        'label': 'Musica',
        'icon': Icons.music_note_rounded,
        'color': DS.yellow
      },
      {
        'label': 'Artistica',
        'icon': Icons.palette_rounded,
        'color': DS.red
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Que deseas aprender?',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Selecciona una o mas materias de tu interes',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: subjectData.map((s) {
            final label = s['label'] as String;
            final icon = s['icon'] as IconData;
            final color = s['color'] as Color;
            final selected = _subjects.contains(label);
            return GestureDetector(
              onTap: () => setState(() {
                if (selected) {
                  _subjects.remove(label);
                } else {
                  _subjects.add(label);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.12)
                      : DS.cardSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : DS.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: DS.poppins(
                        size: 13,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? color : DS.textPrimary,
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 20,
                        height: 3,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Step 5: How did you find us ──────────────────────────────────────────

  Widget _buildStep5() {
    final sources = [
      {
        'value': 'facebook',
        'label': 'Facebook',
        'icon': Icons.facebook_rounded,
        'color': const Color(0xFF1877F2),
      },
      {
        'value': 'instagram',
        'label': 'Instagram',
        'icon': Icons.camera_alt_rounded,
        'color': DS.pink,
      },
      {
        'value': 'youtube',
        'label': 'YouTube',
        'icon': Icons.play_circle_rounded,
        'color': DS.red,
      },
      {
        'value': 'google',
        'label': 'Google',
        'icon': Icons.search_rounded,
        'color': DS.blue,
      },
      {
        'value': 'amigos',
        'label': 'Amigos / familia',
        'icon': Icons.group_rounded,
        'color': DS.green,
      },
      {
        'value': 'otros',
        'label': 'Otros',
        'icon': Icons.more_horiz_rounded,
        'color': DS.textSecondary,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          'Como nos conociste?',
          style: DS.poppins(
            size: 26,
            weight: FontWeight.w800,
            color: DS.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Esto nos ayuda a mejorar nuestra comunicacion',
          style: DS.poppins(size: 14, color: DS.textSecondary),
        ),
        const SizedBox(height: 28),
        ...sources.map((s) {
          final value = s['value'] as String;
          final label = s['label'] as String;
          final icon = s['icon'] as IconData;
          final color = s['color'] as Color;
          final selected = _source == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => setState(() => _source = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.1) : DS.cardSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? color : DS.divider,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: DS.poppins(
                          size: 15,
                          weight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color:
                              selected ? DS.textPrimary : DS.textSecondary,
                        ),
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── Bottom button ────────────────────────────────────────────────────────

  Widget _buildBottomButton() {
    final isLast = _step == _totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: AnimatedOpacity(
        opacity: _canProceed ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: _canProceed ? (isLast ? _finish : _next) : null,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: DS.nicGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: DS.purple.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLast ? 'Crear cuenta' : 'Continuar',
                    style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    // Show success sheet and redirect to login
    await showModalBottomSheet(
      context: context,
      backgroundColor: DS.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      isDismissible: false,
      builder: (_) => _SuccessSheet(
        nombre: _nombreCtrl.text.trim(),
        onContinue: () {
          Navigator.pop(context);
          context.go('/login');
        },
      ),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: DS.poppins(size: 14, color: DS.textPrimary),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DS.poppins(size: 13, color: DS.textSecondary),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, color: DS.textSecondary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: DS.cardSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DS.purple, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool show,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !show,
      style: DS.poppins(size: 14, color: DS.textPrimary),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: DS.poppins(size: 13, color: DS.textSecondary),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child:
              Icon(Icons.lock_outline_rounded, color: DS.textSecondary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: DS.textSecondary,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: DS.cardSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: DS.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: DS.purple, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Account Type Card ────────────────────────────────────────────────────────

class _AccountTypeCard extends StatelessWidget {
  const _AccountTypeCard({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : DS.cardSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? color : DS.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: DS.poppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: DS.poppins(size: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : DS.divider,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Success bottom sheet ──────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({
    required this.nombre,
    required this.onContinue,
  });

  final String nombre;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                gradient: DS.nicGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Cuenta creada!',
              style: DS.poppins(
                size: 22,
                weight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bienvenido, $nombre. Tu cuenta ha sido creada exitosamente. Por favor inicia sesion para continuar.',
              style: DS.poppins(size: 14, color: DS.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: DS.nicGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'Iniciar sesion',
                    style: DS.poppins(
                      size: 16,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
