import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'models.dart';

Map<String, dynamic> generateExcelBytes(List<Dipendente> selectedList, List<Mezzo> mezziList, Map<String, int> storico, Map<String, bool> usaMotorinoMap) {
  final xlsio.Workbook workbook = xlsio.Workbook();
  final xlsio.Worksheet sheet = workbook.worksheets[0];

  // Intestazioni: Nome Cognome | Targa
  sheet.getRangeByIndex(1, 1).setText('Nome Cognome');
  sheet.getRangeByIndex(1, 2).setText('Targa');

  int row = 2;
  Map<String, int> nuoveAssegnazioni = Map.from(storico);

  // Ordina alfabeticamente
  final selected = List<Dipendente>.from(selectedList);
  selected.sort((a, b) {
    final nameA = '${a.nome} ${a.cognome}'.toLowerCase();
    final nameB = '${b.nome} ${b.cognome}'.toLowerCase();
    return nameA.compareTo(nameB);
  });

  for (final dip in selected) {
    final usaMotorino = usaMotorinoMap[dip.id] ?? false;
    final targa = _assegnaTargaStatic(dip, usaMotorino, mezziList, nuoveAssegnazioni);

    sheet.getRangeByIndex(row, 1).setText('${dip.nome} ${dip.cognome}');
    sheet.getRangeByIndex(row, 2).setText(targa ?? 'NON DISPONIBILE');

    if (targa != null) {
      nuoveAssegnazioni[targa] = (nuoveAssegnazioni[targa] ?? 0) + 1;
    }

    row++;
  }

  final List<int> bytes = workbook.saveAsStream();
  workbook.dispose();

  return {'bytes': bytes, 'nuoveAssegnazioni': nuoveAssegnazioni};
}

String? _assegnaTargaStatic(Dipendente dip, bool usaMotorino, List<Mezzo> mezziList, Map<String, int> assegnazioniStorico) {
  final tipoRichiesto = usaMotorino ? 'motorino' : 'furgone';

  final fixedTarga = tipoRichiesto == 'motorino' ? dip.targaFissaMotorino : dip.targaFissaFurgone;
  if (fixedTarga != null) {
    final mezzoFisso = mezziList.firstWhere((m) => m.targa == fixedTarga, orElse: () => Mezzo(id: '', targa: '', tipo: ''));
    if (mezzoFisso.targa.isNotEmpty && mezzoFisso.tipo == tipoRichiesto && !mezzoFisso.fuoriUso) {
      return fixedTarga;
    }
  }

  final mezziDisponibili = mezziList.where((m) => m.tipo == tipoRichiesto && !m.fuoriUso).toList();
  if (mezziDisponibili.isEmpty) return null;

  mezziDisponibili.sort((a, b) {
    final countA = assegnazioniStorico[a.targa] ?? 0;
    final countB = assegnazioniStorico[b.targa] ?? 0;
    return countA.compareTo(countB);
  });

  return mezziDisponibili.first.targa;
}
