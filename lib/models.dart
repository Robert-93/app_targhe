class Dipendente {
  String id;
  String nome;
  String cognome;
  String tipoMezzo; // 'furgone' o 'motorino' (default/preferito)
  String? targaFissaFurgone;
  String? targaFissaMotorino;

  Dipendente({
    required this.id,
    required this.nome,
    required this.cognome,
    this.tipoMezzo = 'furgone',
    this.targaFissaFurgone,
    this.targaFissaMotorino,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'cognome': cognome,
        'tipoMezzo': tipoMezzo,
        'targaFissaFurgone': targaFissaFurgone,
        'targaFissaMotorino': targaFissaMotorino,
      };

  // backward compatible: support old 'targaFissa' key
  factory Dipendente.fromJson(Map<String, dynamic> json) => Dipendente(
        id: json['id'],
        nome: json['nome'],
        cognome: json['cognome'],
        tipoMezzo: json['tipoMezzo'] ?? 'furgone',
        targaFissaFurgone: json['targaFissaFurgone'] ?? json['targaFissa'],
        targaFissaMotorino: json['targaFissaMotorino'],
      );
}

class Mezzo {
  String id;
  String targa;
  String tipo; // 'furgone' o 'motorino'
  bool fuoriUso;

  Mezzo({
    required this.id,
    required this.targa,
    required this.tipo,
    this.fuoriUso = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'targa': targa,
        'tipo': tipo,
        'fuoriUso': fuoriUso,
      };

  factory Mezzo.fromJson(Map<String, dynamic> json) => Mezzo(
        id: json['id'],
        targa: json['targa'],
        tipo: json['tipo'],
        fuoriUso: json['fuoriUso'] ?? false,
      );
}
