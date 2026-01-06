import 'package:flutter_test/flutter_test.dart';
import 'package:app_targhe/export_utils.dart' as export_utils;
import 'package:app_targhe/models.dart';
import 'package:excel/excel.dart';

void main() {
  test('export content has headers and rows in order', () {
    final d1 = Dipendente(id: '1', nome: 'Mario', cognome: 'Rossi');
    final d2 = Dipendente(id: '2', nome: 'Anna', cognome: 'Bianchi');

    final m1 = Mezzo(id: 'm1', targa: 'AA111AA', tipo: 'furgone');
    final m2 = Mezzo(id: 'm2', targa: 'BB222BB', tipo: 'motorino');

    final selected = [d1, d2];
    final mezzi = [m1, m2];
    final storico = <String, int>{};
    final usaMotorino = <String, bool>{'1': false, '2': false};

    final result = export_utils.generateExcelBytes(selected, mezzi, storico, usaMotorino);
    final bytes = result['bytes'] as List<int>;

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.tables.keys.first]!;

    // Headers
    final header1 = sheet.rows[0][0]?.value?.toString();
    final header2 = sheet.rows[0][1]?.value?.toString();
    expect(header1, 'Nome Cognome');
    expect(header2, 'Targa');

    // Rows should be alphabetical by name+surname: Anna Bianchi, Mario Rossi
    final firstRowName = sheet.rows[1][0]?.value?.toString();
    final secondRowName = sheet.rows[2][0]?.value?.toString();
    expect(firstRowName, 'Anna Bianchi');
    expect(secondRowName, 'Mario Rossi');
  });
}
