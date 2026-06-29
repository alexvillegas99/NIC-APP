import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _breathCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Slide del splash hacia arriba
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Mascota idle
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _run();
  }

  Future<void> _run() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    _bounceCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        children: [
          // ═══ WELCOME (siempre debajo, listo) ═══
          _Welcome(
            bounceCtrl: _bounceCtrl,
            breathCtrl: _breathCtrl,
            bottomPad: bottomPad,
            onStart: () {
              HapticFeedback.lightImpact();
              context.go('/onboarding/flow');
            },
            onLogin: () {
              HapticFeedback.lightImpact();
              context.go('/login');
            },
          ),

          // ═══ SPLASH (encima, se desliza hacia arriba) ═══
          AnimatedBuilder(
            animation: _slideCtrl,
            builder: (_, child) {
              final t = Curves.easeInCubic.transform(_slideCtrl.value);
              return Transform.translate(
                offset: Offset(0, -MediaQuery.of(context).size.height * t),
                child: child,
              );
            },
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle.light,
                child: Container(
                  color: const Color(0xFF1F2147),
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: Transform.scale(
                      scale: Tween(
                        begin: 1.0,
                        end: 1.05,
                      ).transform(Curves.easeInOut.transform(_pulseCtrl.value)),
                      child: Image.asset(
                        'assets/imagenes/logonic.png',
                        width: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  Welcome — siempre renderizado debajo del splash
// ═══════════════════════════════════════════════════════════
class _Welcome extends StatelessWidget {
  final AnimationController bounceCtrl;
  final AnimationController breathCtrl;
  final double bottomPad;
  final VoidCallback onStart;
  final VoidCallback onLogin;

  const _Welcome({
    required this.bounceCtrl,
    required this.breathCtrl,
    required this.bottomPad,
    required this.onStart,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final bounceY = Tween(
      begin: 0.0,
      end: -8.0,
    ).transform(Curves.easeInOut.transform(bounceCtrl.value));
    final breathSc = Tween(
      begin: 1.0,
      end: 1.04,
    ).transform(Curves.easeInOut.transform(breathCtrl.value));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Container(
        color: DS.bg,
        width: double.infinity,
        height: double.infinity,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 28,
              right: 28,
              bottom: bottomPad + 24,
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),

                Image.asset(
                  'assets/imagenes/logonic.png',
                  height: 28,
                  fit: BoxFit.contain,
                ),

                const Spacer(flex: 2),

                // Mascota
                Transform.translate(
                  offset: Offset(0, bounceY),
                  child: Transform.scale(
                    scale: breathSc,
                    child: CachedNetworkImage(
                      imageUrl: DS.mascot,
                      height: 250,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => Image.asset(
                        'assets/imagenes/mascota_nic.png',
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/imagenes/mascota_nic.png',
                        height: 250,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                Text(
                  '¡Bienvenido a\nNIC Academy!',
                  textAlign: TextAlign.center,
                  style: DS.poppins(
                    size: 32,
                    weight: FontWeight.w800,
                    color: DS.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Aprende, crece y diviértete.\nTu aventura educativa comienza aquí.',
                  textAlign: TextAlign.center,
                  style: DS.poppins(
                    size: 15,
                    color: DS.textSecondary,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 2),

                NicButton(
                  text: 'Empezar ahora',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onStart,
                ),
                const SizedBox(height: 12),
                NicOutlineButton(
                  text: 'Ya tengo una cuenta',
                  onPressed: onLogin,
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
