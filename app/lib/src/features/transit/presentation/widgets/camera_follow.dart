/// Decide quando a câmera segue o ônibus.
///
/// O maplibre_gl 0.27.1 não informa se um movimento de câmera veio de gesto
/// (o Android manda `isGesture`, mas a camada Dart o descarta; iOS e Web nem
/// mandam). Por isso:
/// - todo movimento que o próprio app dispara abre uma janela "programática";
/// - qualquer início/movimento de câmera fora dessa janela é do usuário;
/// - um toque direto no mapa (quando a plataforma o entrega ao Flutter)
///   também suspende, inclusive durante uma animação nossa.
class CameraFollow {
  CameraFollow({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  /// Folga para o evento nativo de início/fim chegar pelo canal de plataforma.
  static const grace = Duration(milliseconds: 700);

  final DateTime Function() _clock;
  DateTime? _programmaticUntil;
  bool _following = true;

  bool get following => _following;

  bool get _inProgrammaticWindow {
    final until = _programmaticUntil;
    return until != null && _clock().isBefore(until);
  }

  /// Chamar imediatamente antes de animar/mover a câmera ou mudar insets.
  void beginProgrammaticMove(Duration duration) {
    final until = _clock().add(duration + grace);
    final current = _programmaticUntil;
    if (current == null || until.isAfter(current)) _programmaticUntil = until;
  }

  /// Início ou atualização de movimento observada no mapa. Retorna `true`
  /// quando isso suspendeu o follow.
  bool onCameraMovement() {
    if (_inProgrammaticWindow) return false;
    return _suspend();
  }

  /// Toque/scroll direto do usuário sobre o mapa.
  bool onUserInteraction() {
    _programmaticUntil = null;
    return _suspend();
  }

  /// Novo ônibus ou "Centralizar ônibus": volta a seguir.
  void resume() => _following = true;

  bool _suspend() {
    if (!_following) return false;
    _following = false;
    return true;
  }
}
