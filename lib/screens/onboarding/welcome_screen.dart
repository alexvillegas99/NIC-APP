import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';
import 'package:cached_network_image/cached_network_image.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _breathCtrl;

  late final Animation<double> _mascotScale;
  late final Animation<double> _mascotOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _btn1Opacity;
  late final Animation<Offset> _btn1Slide;
  late final Animation<double> _btn2Opacity;
  late final Animation<Offset> _btn2Slide;
  late final Animation<double> _bounceY;
  late final Animation<double> _breathScale;

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _mascotScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );
    _mascotOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.15, curve: Curves.easeIn),
      ),
    );

    _titleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleOpacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.4, 0.6, curve: Curves.easeOut),
      ),
    );

    _btn1Opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
      ),
    );
    _btn1Slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.55, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _btn2Opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );
    _btn2Slide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.65, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Bounce idle
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bounceY = Tween(
      begin: 0.0,
      end: -8.0,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));

    // Respiración
    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _breathScale = Tween(
      begin: 1.0,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _bounceCtrl.dispose();
    _breathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
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

                // ── Logo pequeño arriba ──
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) =>
                      Opacity(opacity: _mascotOpacity.value, child: child),
                  child: Image.asset(
                    'assets/imagenes/logonic.png',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),

                const Spacer(flex: 2),

                // ═══ MASCOTA GRANDE ═══
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _entranceCtrl,
                    _bounceCtrl,
                    _breathCtrl,
                  ]),
                  builder: (_, child) => Opacity(
                    opacity: _mascotOpacity.value,
                    child: Transform.translate(
                      offset: Offset(0, _bounceY.value),
                      child: Transform.scale(
                        scale: _mascotScale.value * _breathScale.value,
                        child: child,
                      ),
                    ),
                  ),
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: DS.blue.withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CachedNetworkImage(
                      imageUrl: DS.logoAvatar,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.white,
                        child: Center(
                          child: Image.asset(
                            'assets/imagenes/logo.png',
                            width: 80,
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white,
                        child: Center(
                          child: Image.asset(
                            'assets/imagenes/logo.png',
                            width: 80,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // ═══ TÍTULO ═══
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) => SlideTransition(
                    position: _titleSlide,
                    child: Opacity(opacity: _titleOpacity.value, child: child),
                  ),
                  child: Text(
                    '¡Bienvenido a\nNIC Academy!',
                    textAlign: TextAlign.center,
                    style: DS.poppins(
                      size: 32,
                      weight: FontWeight.w800,
                      color: DS.textPrimary,
                      height: 1.15,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ═══ SUBTÍTULO ═══
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) =>
                      Opacity(opacity: _subtitleOpacity.value, child: child),
                  child: Text(
                    'Aprende, crece y diviértete.\nTu aventura educativa comienza aquí.',
                    textAlign: TextAlign.center,
                    style: DS.poppins(
                      size: 15,
                      color: DS.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ═══ BOTÓN PRINCIPAL ═══
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) => SlideTransition(
                    position: _btn1Slide,
                    child: Opacity(opacity: _btn1Opacity.value, child: child),
                  ),
                  child: NicButton(
                    text: 'Empezar ahora',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.go('/onboarding/flow');
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ═══ BOTÓN SECUNDARIO ═══
                AnimatedBuilder(
                  animation: _entranceCtrl,
                  builder: (_, child) => SlideTransition(
                    position: _btn2Slide,
                    child: Opacity(opacity: _btn2Opacity.value, child: child),
                  ),
                  child: NicOutlineButton(
                    text: 'Ya tengo una cuenta',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.go('/login');
                    },
                  ),
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
