import 'package:flutter/material.dart';
import 'package:nic_pre_u/shared/ui/design_system.dart';

/// Política de Privacidad y Protección de Datos
/// Cumple con: LOPDP Ecuador (Ley Orgánica de Protección de Datos Personales)
///             GDPR (Reglamento General de Protección de Datos — UE)
///             Estándares internacionales aplicables
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrivacyPolicyScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: DS.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
              child: Column(
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
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: DS.nicGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shield_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Política de Privacidad',
                              style: DS.poppins(
                                size: 18,
                                weight: FontWeight.w700,
                                color: DS.textPrimary,
                              ),
                            ),
                            Text(
                              'Última actualización: Abril 2025',
                              style: DS.poppins(
                                  size: 11, color: DS.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: DS.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: DS.divider),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  _badge('LOPDP — Ecuador', DS.cyan),
                  const SizedBox(height: 4),
                  _badge('GDPR — Unión Europea', DS.purple),
                  const SizedBox(height: 4),
                  _badge('Estándares Internacionales', DS.green),
                  const SizedBox(height: 24),

                  _section('1. Responsable del Tratamiento',
                      'NIC Academy (en adelante "NIC", "nosotros" o "la Plataforma") es la entidad responsable del tratamiento de sus datos personales. Opera con sede principal en la República del Ecuador, y presta servicios a nivel internacional.\n\nPara contactarnos en materia de protección de datos:\n• Email: privacidad@nicpreu.com\n• Dirección: Ecuador'),

                  _section('2. Marco Legal Aplicable',
                      'El tratamiento de sus datos personales se rige por:\n\n'
                      '▸ Ley Orgánica de Protección de Datos Personales del Ecuador (LOPDP), publicada en el Registro Oficial Suplemento N.° 459, de 26 de mayo de 2021, y su Reglamento.\n\n'
                      '▸ Reglamento General de Protección de Datos (GDPR) — Reglamento (UE) 2016/679, aplicable a usuarios ubicados en el Espacio Económico Europeo o cuando NIC ofrece servicios a residentes en la UE.\n\n'
                      '▸ Demás normativas nacionales e internacionales de privacidad y protección de datos aplicables según la jurisdicción del usuario.'),

                  _section('3. Datos que Recopilamos',
                      'Recopilamos únicamente los datos estrictamente necesarios para la operación de la Plataforma:\n\n'
                      '• Datos de identificación: nombre, apellido, número de cédula o documento de identidad.\n'
                      '• Datos de contacto: dirección de correo electrónico, número de teléfono (opcional).\n'
                      '• Datos académicos: cursos inscritos, calificaciones, asistencia, horarios.\n'
                      '• Datos de uso: registros de actividad dentro de la aplicación, preferencias de aprendizaje.\n'
                      '• Fecha de nacimiento: para verificación de edad y personalización.\n\n'
                      'No recopilamos datos sensibles tales como datos de salud, filiación política, creencias religiosas ni biometría, salvo que sea estrictamente necesario y con consentimiento expreso.'),

                  _section('4. Finalidad del Tratamiento',
                      'Sus datos personales son tratados exclusivamente para:\n\n'
                      '▸ Prestación del servicio educativo: gestión de acceso, cursos, calificaciones, asistencia y comunicación académica.\n'
                      '▸ Comunicaciones institucionales: notificaciones sobre su cuenta, eventos y actividades de NIC Academy.\n'
                      '▸ Mejora del servicio: análisis de uso interno para optimizar la experiencia de la Plataforma.\n'
                      '▸ Fines de marketing y comunicación: envío de información relevante sobre programas y servicios de NIC, a través de nuestros propios canales y herramientas de gestión de relaciones (CRM).'),

                  _highlight(
                    icon: Icons.verified_user_rounded,
                    color: DS.green,
                    title: 'Destino exclusivo de sus datos',
                    body:
                        'Sus datos personales son tratados ÚNICAMENTE dentro de la Plataforma NIC Academy y transferidos exclusivamente a:\n\n'
                        '• Sitio web oficial de NIC Academy (nicpreu.com)\n'
                        '• Bitrix24 (herramienta de CRM y gestión interna)\n\n'
                        'Sus datos NO son vendidos, cedidos ni transferidos a terceros distintos de los mencionados. NIC Academy no comercializa información personal.',
                  ),

                  _section('5. Base Jurídica del Tratamiento',
                      'El tratamiento se fundamenta en:\n\n'
                      '▸ Ejecución de un contrato (Art. 6.1.b GDPR / Art. 7 LOPDP): necesario para la prestación del servicio educativo.\n'
                      '▸ Interés legítimo (Art. 6.1.f GDPR / Art. 9 LOPDP): mejora del servicio, comunicaciones académicas y seguridad de la Plataforma.\n'
                      '▸ Consentimiento (Art. 6.1.a GDPR / Art. 7 LOPDP): para comunicaciones de marketing y uso de datos con fines promocionales. Usted puede retirar su consentimiento en cualquier momento.'),

                  _section('6. Conservación de los Datos',
                      'Sus datos serán conservados durante el tiempo que mantenga una relación activa con NIC Academy y, posteriormente, durante el período legalmente exigido para el cumplimiento de obligaciones legales, contables o fiscales.\n\nUna vez finalizada la relación y vencidos los plazos legales, los datos serán eliminados o anonimizados de forma segura.'),

                  _section('7. Derechos del Titular',
                      'De conformidad con la LOPDP y el GDPR, usted tiene derecho a:\n\n'
                      '▸ Acceso: conocer qué datos personales suyos tratamos.\n'
                      '▸ Rectificación: corregir datos inexactos o incompletos.\n'
                      '▸ Supresión ("derecho al olvido"): solicitar la eliminación de sus datos cuando ya no sean necesarios.\n'
                      '▸ Oposición: oponerse al tratamiento basado en interés legítimo o marketing directo.\n'
                      '▸ Portabilidad: recibir sus datos en formato estructurado y legible.\n'
                      '▸ Limitación: solicitar la restricción del tratamiento en ciertos supuestos.\n'
                      '▸ Retirar el consentimiento: en cualquier momento, sin que ello afecte la licitud del tratamiento anterior.\n\n'
                      'Para ejercer sus derechos, envíe su solicitud a: privacidad@nicpreu.com\n'
                      'Responderemos en un plazo máximo de 15 días hábiles (LOPDP) / 30 días (GDPR).'),

                  _section('8. Seguridad de los Datos',
                      'NIC Academy implementa medidas técnicas y organizativas apropiadas para proteger sus datos personales contra acceso no autorizado, pérdida, destrucción o divulgación. Entre estas medidas se incluyen:\n\n'
                      '• Cifrado de contraseñas (hashing seguro).\n'
                      '• Almacenamiento seguro en servidores con acceso restringido.\n'
                      '• Transmisión de datos mediante protocolos cifrados (HTTPS/TLS).\n'
                      '• Control de acceso basado en roles.\n'
                      '• Revisiones periódicas de seguridad.'),

                  _section('9. Transferencias Internacionales',
                      'En caso de que alguna de las herramientas utilizadas (p. ej. Bitrix24) implique el tratamiento de datos fuera del Ecuador o del Espacio Económico Europeo, NIC Academy garantiza que dicha transferencia se realiza con las salvaguardas adecuadas previstas en la LOPDP y el GDPR, incluyendo cláusulas contractuales tipo o mecanismos equivalentes.'),

                  _section('10. Cookies y Tecnologías de Seguimiento',
                      'La aplicación móvil puede utilizar tecnologías de almacenamiento local (almacenamiento seguro del dispositivo) para mantener su sesión activa y mejorar la experiencia. No se utilizan cookies de rastreo de terceros sin su consentimiento.'),

                  _section('11. Menores de Edad',
                      'NIC Academy puede atender a menores de 18 años en el contexto de servicios educativos. En tales casos, el representante legal deberá otorgar el consentimiento correspondiente. Tomamos medidas adicionales para proteger la privacidad de los menores conforme a la normativa aplicable.'),

                  _section('12. Cambios en esta Política',
                      'NIC Academy se reserva el derecho de actualizar esta Política de Privacidad. Cualquier cambio sustancial será notificado a través de la aplicación con al menos 15 días de anticipación. El uso continuado de la Plataforma tras la notificación implica la aceptación de los cambios.'),

                  _section('13. Autoridad de Control',
                      'Si considera que el tratamiento de sus datos no cumple la normativa aplicable, puede presentar una reclamación ante:\n\n'
                      '▸ Ecuador: Dirección Nacional de Registro de Datos Públicos (DINARDAP) o la autoridad competente designada por la LOPDP.\n'
                      '▸ Unión Europea: Autoridad de protección de datos del Estado miembro correspondiente.'),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DS.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: DS.purple.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Al utilizar NIC Academy usted confirma haber leído, entendido y aceptado esta Política de Privacidad. Si no está de acuerdo con alguna disposición, le rogamos que no use la Plataforma y nos contacte para resolver cualquier inquietud.',
                      style: DS.poppins(
                        size: 12,
                        color: DS.textSecondary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: DS.nicGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Entendido',
                      style: DS.poppins(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  Widget _badge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: DS.poppins(
              size: 11,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: DS.poppins(
              size: 14,
              weight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: DS.poppins(
              size: 13,
              color: DS.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlight({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: DS.poppins(
                    size: 13,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: DS.poppins(
              size: 13,
              color: DS.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
