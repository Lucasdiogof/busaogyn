import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Ponte entre o mapa e os controles fora dele (botão "Centralizar" do
/// painel de acompanhamento). O mapa continua dono da decisão de seguir
/// ([CameraFollow]); aqui só se publica o estado e se pede a centralização.
class MapFollowController extends ChangeNotifier {
  bool _following = true;
  bool _hasVehicle = false;
  VoidCallback? _recenter;

  /// A câmera está seguindo o ônibus acompanhado.
  bool get following => _following;

  /// Há uma posição real do ônibus no mapa.
  bool get hasVehicle => _hasVehicle;

  /// Volta a seguir e centraliza no ônibus.
  void recenter() => _recenter?.call();

  /// Usado pelo mapa ao montar/desmontar.
  void attach(VoidCallback? recenter) => _recenter = recenter;

  /// Usado pelo mapa a cada mudança de follow ou de posição.
  void report({required bool following, required bool hasVehicle}) {
    if (following == _following && hasVehicle == _hasVehicle) return;
    _following = following;
    _hasVehicle = hasVehicle;
    // O mapa reporta também de didUpdateWidget (fase de build); quem escuta
    // é reconstruído no fim do frame.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) => _notify());
    } else {
      _notify();
    }
  }

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
