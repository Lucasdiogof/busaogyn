import 'package:busaogyn/src/features/transit/presentation/widgets/camera_follow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late CameraFollow follow;

  setUp(() {
    now = DateTime(2026, 10, 7, 8);
    follow = CameraFollow(clock: () => now);
  });

  test('começa seguindo', () {
    expect(follow.following, isTrue);
  });

  test('animação do próprio app não suspende o follow', () {
    follow.beginProgrammaticMove(const Duration(milliseconds: 700));
    now = now.add(const Duration(milliseconds: 100));

    expect(follow.onCameraMovement(), isFalse);
    now = now.add(const Duration(milliseconds: 1000));
    expect(follow.onCameraMovement(), isFalse);
    expect(follow.following, isTrue);
  });

  test('movimento fora da janela programática é do usuário', () {
    follow.beginProgrammaticMove(const Duration(milliseconds: 700));
    now = now.add(const Duration(seconds: 2));

    expect(follow.onCameraMovement(), isTrue);
    expect(follow.following, isFalse);
    // Movimentos seguintes não "suspendem de novo".
    expect(follow.onCameraMovement(), isFalse);
  });

  test('toque direto suspende mesmo durante animação do app', () {
    follow.beginProgrammaticMove(const Duration(milliseconds: 700));

    expect(follow.onUserInteraction(), isTrue);
    expect(follow.following, isFalse);
  });

  test('Centralizar reativa o follow', () {
    follow.onUserInteraction();
    follow.resume();

    expect(follow.following, isTrue);
  });

  test('janela mais longa não é encurtada por uma mais curta', () {
    follow.beginProgrammaticMove(const Duration(seconds: 2));
    follow.beginProgrammaticMove(Duration.zero);
    now = now.add(const Duration(milliseconds: 1500));

    expect(follow.onCameraMovement(), isFalse);
  });
}
