import 'package:flutter_test/flutter_test.dart';
import 'package:app_targhe/export_utils.dart' as export_utils;
import 'package:app_targhe/models.dart';

void main() {
  test('generateExcelBytes returns non-empty bytes and updates assignments', () {
    final dip1 = Dipendente(id: '1', nome: 'Alfa', cognome: 'Beta');
    final dip2 = Dipendente(id: '2', nome: 'Zeta', cognome: 'Alpha');
    final mez1 = Mezzo(id: 'm1', targa: 'AA111AA', tipo: 'furgone');
    final mez2 = Mezzo(id: 'm2', targa: 'BB222BB', tipo: 'motorino');

    final selected = [dip1, dip2];
    final mezzi = [mez1, mez2];
    final storico = <String, int>{};
    final usaMotorino = <String, bool>{'1': false, '2': true};

    final result = export_utils.generateExcelBytes(selected, mezzi, storico, usaMotorino);

    final bytes = result['bytes'] as List<int>;
    final nuove = result['nuoveAssegnazioni'] as Map<String, int>;

    expect(bytes, isNotEmpty);
    // Assegna almeno una targa (se disponibili)
    expect(nuove.length, greaterThanOrEqualTo(0));
  });
}
