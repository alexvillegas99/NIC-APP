import 'dart:async';
import 'dart:io';

/// Servicio singleton que monitorea conectividad de red.
/// Hace ping a la API cada 10s y expone [isOnline] + stream [onChanged].
class ConnectivityService {
  static final ConnectivityService _i = ConnectivityService._();
  static ConnectivityService get instance => _i;
  ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  final _ctrl = StreamController<bool>.broadcast();
  Stream<bool> get onChanged => _ctrl.stream;

  Timer? _timer;
  bool _monitoring = false;

  /// Inicia el monitoreo periódico (llamar en main o initState de HomeScreen).
  void startMonitoring() {
    if (_monitoring) return;
    _monitoring = true;
    check(); // check inmediato
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => check());
  }

  void stopMonitoring() {
    _timer?.cancel();
    _monitoring = false;
  }

  /// Verifica conectividad ahora. Retorna true si hay internet.
  Future<bool> check() async {
    bool online;
    try {
      final result = await InternetAddress.lookup('nicpreu.com')
          .timeout(const Duration(seconds: 4));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }
    if (online != _isOnline) {
      _isOnline = online;
      _ctrl.add(_isOnline);
    }
    return _isOnline;
  }
}
