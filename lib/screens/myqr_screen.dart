import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:nic_pre_u/screens/premium_screen.dart';
import 'package:nic_pre_u/services/asistencia_service.dart';
import 'package:nic_pre_u/services/asistentes_service.dart';
import 'package:nic_pre_u/services/auth_service.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:nic_pre_u/shared/widgets/nic_bottom_nav.dart';

// ─── Data model ───────────────────────────────────────────────────────────────
class _QRData {
  final Map<String, dynamic> user;
  final String qrPayload;
  final List<Map<String, dynamic>> cursos;
  final int porcentajeAsistencia;
  final int diasAsistidos;
  final int diasEsperados;

  const _QRData({
    required this.user,
    required this.qrPayload,
    required this.cursos,
    required this.porcentajeAsistencia,
    required this.diasAsistidos,
    required this.diasEsperados,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class MyQRScreen extends StatefulWidget {
  const MyQRScreen({super.key});

  @override
  State<MyQRScreen> createState() => _MyQRScreenState();
}

class _MyQRScreenState extends State<MyQRScreen>
    with SingleTickerProviderStateMixin {
  final _auth = AuthService();
  final _asist = AsistentesService();
  final _asistSvc = AsistenciaService();

  late Future<_QRData> _future;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _future = _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<_QRData> _load() async {
    final rawUser = await _auth.getUser() ?? {};
    final user = (rawUser['user'] ?? rawUser) as Map<String, dynamic>;

    final cedula = user['cedula']?.toString() ?? '';
    final nombre = user['nombre']?.toString() ?? '';
    final createdAt = user['createdAtEcuador'] ?? _toEcString(user['createdAt']);
    final qrPayload = '$cedula,$nombre,$createdAt';

    final cursos = await _asist.fetchCursosPorCedula();

    // Try to fetch real attendance for first course; fall back gracefully
    int pct = 0, diasA = 0, diasE = 0;
    if (cedula.isNotEmpty && cursos.isNotEmpty) {
      try {
        final cursoId = (cursos.first['_id'] ??
                cursos.first['id'] ??
                cursos.first['cursoId'] ??
                '')
            .toString();
        if (cursoId.isNotEmpty) {
          final reporte = await _asistSvc.getPorCedula(
              cedula: cedula, cursoId: cursoId);
          pct = reporte.resumen.porcentajeAsistencia;
          diasA = reporte.resumen.diasConAsistencia;
          diasE = reporte.resumen.totalDiasEsperados;
        }
      } catch (_) {}
    }

    _fadeCtrl.forward();
    return _QRData(
      user: user,
      qrPayload: qrPayload,
      cursos: cursos,
      porcentajeAsistencia: pct,
      diasAsistidos: diasA,
      diasEsperados: diasE,
    );
  }

  String _toEcString(dynamic v) {
    final base = v != null
        ? (DateTime.tryParse(v.toString()) ?? DateTime.now())
        : DateTime.now();
    return DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(base.toUtc().subtract(const Duration(hours: 5)));
  }

  String _prettyCode(String cedula) {
    final s = cedula.replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return '--';
    final chunks = <String>[];
    for (var i = 0; i < s.length; i += 2) {
      chunks.add(s.substring(i, (i + 2).clamp(0, s.length)));
    }
    return chunks.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<_QRData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: DS.purple, strokeWidth: 2),
                    );
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Color(0xFFEF4444), size: 48),
                          const SizedBox(height: 12),
                          Text('Error al generar el QR',
                              style: DS.poppins(color: DS.textSecondary)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () =>
                                setState(() => _future = _load()),
                            child: Text('Reintentar',
                                style: DS.poppins(
                                    color: DS.purple,
                                    weight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  }
                  return FadeTransition(
                    opacity: _fade,
                    child: _buildContent(snap.data!),
                  );
                },
              ),
            ),
            const NicBottomNav(current: NavTab.qr),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141422),
        border:
            Border(bottom: BorderSide(color: Color(0xFF252535), width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi código QR',
                  style: DS.poppins(
                    size: 20,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
                Text(
                  'Preséntalo para registrar tu asistencia',
                  style: DS.poppins(size: 12, color: DS.textSecondary),
                ),
              ],
            ),
          ),
          // Refresh
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _future = _load());
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DS.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                    color: DS.purple.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: DS.purple, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Main content ────────────────────────────────────────────────────────────
  Widget _buildContent(_QRData data) {
    final nombre = data.user['nombre']?.toString() ?? '';
    final cedula = data.user['cedula']?.toString() ?? '';
    final racha = (data.user['racha'] as num?)?.toInt() ?? 0;
    final puntos = (data.user['puntos'] as num?)?.toInt() ?? 0;
    final isPremium = data.user['premium'] == true ||
        data.user['isPremium'] == true ||
        (data.user['membresia']?.toString() ?? '').toLowerCase() == 'premium';

    final qrSize =
        (MediaQuery.of(context).size.width * 0.74).clamp(240.0, 320.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        children: [
          // ─ Course pills ─────────────────────────────────────────────────
          if (data.cursos.isNotEmpty) ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: data.cursos.take(3).map((c) {
                final name = (c['nombre'] ?? '')
                    .toString()
                    .replaceAll('_', ' ')
                    .replaceAll('-', ' ');
                return _CoursePill(name: name);
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],

          // ─ QR card ──────────────────────────────────────────────────────
          _QRCard(qrData: data.qrPayload, qrSize: qrSize),

          const SizedBox(height: 20),

          // ─ Motivational quote ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✦ ', style: DS.poppins(size: 11, color: DS.purple)),
                Flexible(
                  child: Text(
                    'La inteligencia y la sabiduría es la clave del éxito',
                    textAlign: TextAlign.center,
                    style: DS.poppins(
                      size: 12,
                      weight: FontWeight.w500,
                      color: DS.textSecondary,
                      height: 1.4,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                Text(' ✦', style: DS.poppins(size: 11, color: DS.purple)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─ Name + code ──────────────────────────────────────────────────
          Text(
            nombre,
            style: DS.poppins(
              size: 20,
              weight: FontWeight.w800,
              color: DS.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF252535)),
            ),
            child: Text(
              _prettyCode(cedula),
              style: DS.poppins(
                size: 13,
                weight: FontWeight.w600,
                color: DS.textSecondary,
              ).copyWith(letterSpacing: 1.5),
            ),
          ),

          const SizedBox(height: 28),

          // ─ Stats row ────────────────────────────────────────────────────
          Row(
            children: [
              // Racha
              Expanded(
                child: _StatBox(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF8C42),
                  bgColor: const Color(0xFFFF8C42).withValues(alpha: 0.1),
                  borderColor:
                      const Color(0xFFFF8C42).withValues(alpha: 0.25),
                  value: '$racha',
                  unit: 'días',
                  label: 'Racha activa',
                ),
              ),
              const SizedBox(width: 10),
              // Asistencia %
              Expanded(
                child: _StatBox(
                  icon: Icons.event_available_rounded,
                  iconColor: const Color(0xFF34D399),
                  bgColor: const Color(0xFF34D399).withValues(alpha: 0.1),
                  borderColor:
                      const Color(0xFF34D399).withValues(alpha: 0.25),
                  value: '${data.porcentajeAsistencia}%',
                  unit: data.diasEsperados > 0
                      ? '${data.diasAsistidos}/${data.diasEsperados}'
                      : null,
                  label: 'Asistencia',
                ),
              ),
              const SizedBox(width: 10),
              // Puntos XP
              Expanded(
                child: _StatBox(
                  icon: Icons.stars_rounded,
                  iconColor: DS.purple,
                  bgColor: DS.purple.withValues(alpha: 0.1),
                  borderColor: DS.purple.withValues(alpha: 0.25),
                  value: '$puntos',
                  unit: 'XP',
                  label: 'Puntos',
                ),
              ),
            ],
          ),

          // ─ Attendance bar ────────────────────────────────────────────────
          if (data.diasEsperados > 0) ...[
            const SizedBox(height: 20),
            _AttendanceBar(
              pct: data.porcentajeAsistencia,
              asistidos: data.diasAsistidos,
              esperados: data.diasEsperados,
            ),
          ],

          // ─ Bottom CTA ────────────────────────────────────────────────────
          const SizedBox(height: 24),
          if (isPremium)
            _CtaButton(
              icon: Icons.explore_rounded,
              label: 'Explorar nuevos cursos',
              sublabel: 'Descubre lo que podemos ofrecerte',
              gradient: const LinearGradient(
                colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              glowColor: const Color(0xFF0891B2),
              onTap: () => context.go('/home/explorar'),
            )
          else
            _CtaButton(
              icon: Icons.auto_awesome_rounded,
              label: 'Desbloquea NIC Premium',
              sublabel: 'Accede a todos los cursos y beneficios',
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              glowColor: DS.purple,
              onTap: () => PremiumScreen.show(context),
            ),
        ],
      ),
    );
  }
}

// ─── Course pill ─────────────────────────────────────────────────────────────
class _CoursePill extends StatelessWidget {
  final String name;
  const _CoursePill({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: DS.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DS.purple.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DS.purple,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            name,
            style: DS.poppins(
              size: 12,
              weight: FontWeight.w600,
              color: DS.purple,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── QR Card ─────────────────────────────────────────────────────────────────
class _QRCard extends StatelessWidget {
  final String qrData;
  final double qrSize;

  const _QRCard({required this.qrData, required this.qrSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF9B59F5), Color(0xFF4C1D95), Color(0xFF9B59F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: DS.purple.withValues(alpha: 0.45),
            blurRadius: 32,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: qrData.isEmpty ? 'NIC_ACADEMY' : qrData,
              size: qrSize,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF141422),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF141422),
              ),
            ),
            // Corner brackets overlay
            ..._corners(qrSize),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners(double size) {
    const s = 22.0;
    const t = 3.5;
    const r = 6.0;
    final c = DS.purple;
    Widget corner(AlignmentGeometry align, bool flipH, bool flipV) =>
        Positioned.fill(
          child: Align(
            alignment: align,
            child: Transform.scale(
              scaleX: flipH ? -1 : 1,
              scaleY: flipV ? -1 : 1,
              child: SizedBox(
                width: s,
                height: s,
                child: CustomPaint(
                  painter: _CornerPainter(color: c, thickness: t, radius: r),
                ),
              ),
            ),
          ),
        );

    return [
      corner(Alignment.topLeft, false, false),
      corner(Alignment.topRight, true, false),
      corner(Alignment.bottomLeft, false, true),
      corner(Alignment.bottomRight, true, true),
    ];
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double radius;

  const _CornerPainter(
      {required this.color, required this.thickness, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0),
          radius: Radius.circular(radius), clockwise: true)
      ..lineTo(size.width * 0.55, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ─── Stat box ────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final String value;
  final String? unit;
  final String label;

  const _StatBox({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.value,
    required this.label,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: DS.poppins(
                    size: 17,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: DS.poppins(
                      size: 10,
                      weight: FontWeight.w500,
                      color: DS.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: DS.poppins(size: 9, color: DS.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Attendance bar ───────────────────────────────────────────────────────────
class _AttendanceBar extends StatelessWidget {
  final int pct;
  final int asistidos;
  final int esperados;

  const _AttendanceBar({
    required this.pct,
    required this.asistidos,
    required this.esperados,
  });

  Color get _barColor {
    if (pct >= 80) return const Color(0xFF34D399);
    if (pct >= 60) return const Color(0xFFFBBF24);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final frac = (pct / 100).clamp(0.0, 1.0);
    final color = _barColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C2E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                'Registro de asistencia',
                style: DS.poppins(
                    size: 12,
                    weight: FontWeight.w700,
                    color: DS.textPrimary),
              ),
              const Spacer(),
              Text(
                '$asistidos de $esperados días',
                style: DS.poppins(size: 11, color: DS.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              // Track
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 6)
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pct >= 80
                ? '¡Excelente asistencia! Sigue así 🎯'
                : pct >= 60
                    ? 'Puedes mejorar tu asistencia 💪'
                    : 'Tu asistencia necesita atención ⚠️',
            style: DS.poppins(size: 11, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── CTA Button ───────────────────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Gradient gradient;
  final Color glowColor;
  final VoidCallback onTap;

  const _CtaButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DS.poppins(
                      size: 14,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: DS.poppins(
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}
