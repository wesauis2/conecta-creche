import 'package:conecta_creche/presence/parecer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parecer defaults', () {
    test('matches SPEC v1 defaults when constructed with no arguments', () {
      const parecer = Parecer();

      expect(parecer.chorou, ParecerChorou.nao);
      expect(parecer.comportamento, ParecerComportamento.tranquilo);
      expect(parecer.comeu, ParecerComeu.bem);
      expect(parecer.dormiu, ParecerDormiu.cochilou);
      expect(parecer.evacuacoes, ParecerEvacuacoes.normal);
      expect(parecer.humor, ParecerHumor.contente);
    });
  });

  group('Parecer.toMap / Parecer.fromMap', () {
    test('round-trips every field through a Firestore-friendly map', () {
      const parecer = Parecer(
        chorou: ParecerChorou.muito,
        comportamento: ParecerComportamento.precisouDeAtencao,
        comeu: ParecerComeu.pouco,
        dormiu: ParecerDormiu.sim,
        evacuacoes: ParecerEvacuacoes.atencao,
        humor: ParecerHumor.irritado,
      );

      final map = parecer.toMap();
      final restored = Parecer.fromMap(map);

      expect(restored, parecer);
    });

    test('toMap only contains plain strings (no enum instances)', () {
      const parecer = Parecer();

      final map = parecer.toMap();

      expect(map.values, everyElement(isA<String>()));
    });

    test('fromMap falls back to defaults for missing/unknown fields', () {
      final restored = Parecer.fromMap(const {'chorou': 'nonsense'});

      expect(restored, const Parecer());
    });
  });

  test('Parecer supports value equality', () {
    expect(const Parecer(), const Parecer());
    expect(
      const Parecer(chorou: ParecerChorou.muito),
      isNot(const Parecer()),
    );
  });
}
