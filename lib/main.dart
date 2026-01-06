// pubspec.yaml dependencies necessarie:
// dependencies:
//   flutter:
//     sdk: flutter
//   shared_preferences: ^2.2.2
//   path_provider: ^2.1.1
//   permission_handler: ^11.0.1
//   syncfusion_flutter_xlsio: ^24.1.41

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'export_utils.dart' as export_utils;
import 'models.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sync_manager.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase not configured or failed to initialize; continue without cloud sync
    // SyncManager.init will also attempt to initialize Firebase lazily when needed.
  }
  runApp(const AppTarghe());
}

class AppTarghe extends StatelessWidget {
  const AppTarghe({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Targhe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Storage Manager
class StorageManager {
  static const String keyDipendenti = 'dipendenti';
  static const String keyMezzi = 'mezzi';
  static const String keyAssegnazioni = 'assegnazioni';

  static Future<List<Dipendente>> caricaDipendenti() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyDipendenti);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Dipendente.fromJson(json)).toList();
  }

  static Future<void> salvaDipendenti(List<Dipendente> dipendenti) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(dipendenti.map((d) => d.toJson()).toList());
    await prefs.setString(keyDipendenti, data);

    // Notify SyncManager if enabled
    try {
      await SyncManager.instance.onLocalDipendentiChanged(dipendenti);
    } catch (_) {}
  }

  static Future<List<Mezzo>> caricaMezzi() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyMezzi);
    if (data == null) return [];
    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => Mezzo.fromJson(json)).toList();
  }

  static Future<void> salvaMezzi(List<Mezzo> mezzi) async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(mezzi.map((m) => m.toJson()).toList());
    await prefs.setString(keyMezzi, data);

    // Notify SyncManager
    try {
      await SyncManager.instance.onLocalMezziChanged(mezzi);
    } catch (_) {}
  }

  static Future<Map<String, int>> caricaAssegnazioni() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(keyAssegnazioni);
    if (data == null) return {};
    final Map<String, dynamic> jsonMap = jsonDecode(data);
    return jsonMap.map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> salvaAssegnazioni(Map<String, int> assegnazioni) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyAssegnazioni, jsonEncode(assegnazioni));

    // Notify SyncManager
    try {
      await SyncManager.instance.onLocalAssegnazioniChanged(assegnazioni);
    } catch (_) {}
  }
}

// HOME PAGE
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Dipendente> dipendenti = [];
  List<Mezzo> mezzi = [];
  Set<String> dipendentiSelezionati = {};
  Map<String, bool> usaMotorinoPerId = {};
  Map<String, int> assegnazioniStorico = {};
  bool isLoading = true;

  // Sync manager and flag
  final syncManager = SyncManager.instance;
  bool isSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    caricaDati();
    // Initialize SyncManager scaffold
    syncManager.init();
  }

  Future<void> caricaDati() async {
    dipendenti = await StorageManager.caricaDipendenti();
    mezzi = await StorageManager.caricaMezzi();
    assegnazioniStorico = await StorageManager.caricaAssegnazioni();
    setState(() {
      isLoading = false;
    });
  }

  String? assegnaTarga(Dipendente dip, bool usaMotorino) {
    final tipoRichiesto = usaMotorino ? 'motorino' : 'furgone';

    // Se ha targa fissa corrispondente al tipo richiesto
    final fixedTarga = tipoRichiesto == 'motorino' ? dip.targaFissaMotorino : dip.targaFissaFurgone;
    if (fixedTarga != null) {
      final mezzoFisso =
          mezzi.firstWhere((m) => m.targa == fixedTarga, orElse: () => Mezzo(id: '', targa: '', tipo: ''));
      if (mezzoFisso.targa.isNotEmpty && mezzoFisso.tipo == tipoRichiesto && !mezzoFisso.fuoriUso) {
        return fixedTarga;
      }
    }

    // Mezzi disponibili del tipo richiesto
    final mezziDisponibili = mezzi.where((m) => m.tipo == tipoRichiesto && !m.fuoriUso).toList();

    if (mezziDisponibili.isEmpty) return null;

    // Ordina per numero di assegnazioni (meno usato prima)
    mezziDisponibili.sort((a, b) {
      final countA = assegnazioniStorico[a.targa] ?? 0;
      final countB = assegnazioniStorico[b.targa] ?? 0;
      return countA.compareTo(countB);
    });

    return mezziDisponibili.first.targa;
  }

  // Genera i bytes dell'Excel in funzione top-level (visibile ai test)



  Future<void> generaExcel() async {
    if (dipendentiSelezionati.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un dipendente')),
      );
      return;
    }

    final selected = dipendenti.where((d) => dipendentiSelezionati.contains(d.id)).toList();
    final result = export_utils.generateExcelBytes(selected, mezzi, assegnazioniStorico, usaMotorinoPerId);

    Map<String, int> nuoveAssegnazioni = Map.from(result['nuoveAssegnazioni'] as Map<String, int>);
    await StorageManager.salvaAssegnazioni(nuoveAssegnazioni);

    final List<int> bytes = result['bytes'] as List<int>;

    // Richiedi permessi e scegli cartella Download
    Directory? directory;
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      directory = (dirs != null && dirs.isNotEmpty) ? dirs.first : await getExternalStorageDirectory();
    } else {
      final downloads = await getDownloadsDirectory();
      directory = downloads ?? await getApplicationDocumentsDirectory();
    }

    final fileName = 'turni_${DateTime.now().toString().split(' ')[0]}.xlsx';
    final filePath = '${directory!.path}/$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File salvato: $filePath')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Targhe'),
        actions: [
          // Sync toggle
          IconButton(
            icon: Icon(isSyncEnabled ? Icons.cloud_done : Icons.cloud_off),
            onPressed: () async {
              setState(() => isSyncEnabled = !isSyncEnabled);
              if (isSyncEnabled) {
                await syncManager.enable();
                syncManager.listenRemoteChanges();
              } else {
                await syncManager.disable();
              }
            },
            tooltip: 'Sync',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GestioneDipendentiPage()),
              );
              caricaDati();
            },
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GestioneMezziPage()),
              );
              caricaDati();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Seleziona i dipendenti in turno',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: dipendenti.isEmpty
                ? const Center(child: Text('Nessun dipendente. Aggiungine dalla pagina Dipendenti.'))
                : ListView.builder(
                    itemCount: dipendenti.length,
                    itemBuilder: (context, index) {
                      final dip = dipendenti[index];
                      final isSelected = dipendentiSelezionati.contains(dip.id);
                      final usaMotorino = usaMotorinoPerId[dip.id] ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        color: isSelected ? Colors.blue.shade100 : null,
                        child: ListTile(
                          title: Text('${dip.nome} ${dip.cognome}'),
                          subtitle: Text('Furgone: ${dip.targaFissaFurgone ?? "casuale"}, Motorino: ${dip.targaFissaMotorino ?? "casuale"}'),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                dipendentiSelezionati.remove(dip.id);
                              } else {
                                dipendentiSelezionati.add(dip.id);
                              }
                            });
                          },
                          trailing: isSelected
                              ? IconButton(
                                  icon: Icon(
                                    Icons.two_wheeler,
                                    color: usaMotorino ? Colors.green : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      usaMotorinoPerId[dip.id] = !usaMotorino;
                                    });
                                  },
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: generaExcel,
              icon: const Icon(Icons.file_download),
              label: const Text('Genera Excel'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// GESTIONE DIPENDENTI PAGE
class GestioneDipendentiPage extends StatefulWidget {
  const GestioneDipendentiPage({super.key});

  @override
  State<GestioneDipendentiPage> createState() => _GestioneDipendentiPageState();
}

class _GestioneDipendentiPageState extends State<GestioneDipendentiPage> {
  List<Dipendente> dipendenti = [];
  List<Mezzo> mezzi = [];

  @override
  void initState() {
    super.initState();
    caricaDati();
  }

  Future<void> caricaDati() async {
    dipendenti = await StorageManager.caricaDipendenti();
    mezzi = await StorageManager.caricaMezzi();
    setState(() {});
  }

  Future<void> mostraDialogDipendente([Dipendente? dip]) async {
    final nomeController = TextEditingController(text: dip?.nome ?? '');
    final cognomeController = TextEditingController(text: dip?.cognome ?? '');
    String tipoMezzo = dip?.tipoMezzo ?? 'furgone';
    String? targaFissaFurgone = dip?.targaFissaFurgone;
    String? targaFissaMotorino = dip?.targaFissaMotorino;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(dip == null ? 'Nuovo Dipendente' : 'Modifica Dipendente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: cognomeController,
                  decoration: const InputDecoration(labelText: 'Cognome'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: tipoMezzo,
                  decoration: const InputDecoration(labelText: 'Tipo Mezzo Default'),
                  items: const [
                    DropdownMenuItem(value: 'furgone', child: Text('Furgone')),
                    DropdownMenuItem(value: 'motorino', child: Text('Motorino')),
                  ],
                  onChanged: (val) => setDialogState(() => tipoMezzo = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: targaFissaFurgone,
                  decoration: const InputDecoration(labelText: 'Targa Fissa Furgone (opzionale)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Casuale')),
                    ...mezzi
                        .where((m) => m.tipo == 'furgone')
                        .map((m) => DropdownMenuItem(value: m.targa, child: Text(m.targa))),
                  ],
                  onChanged: (val) => setDialogState(() => targaFissaFurgone = val),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: targaFissaMotorino,
                  decoration: const InputDecoration(labelText: 'Targa Fissa Motorino (opzionale)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Casuale')),
                    ...mezzi
                        .where((m) => m.tipo == 'motorino')
                        .map((m) => DropdownMenuItem(value: m.targa, child: Text(m.targa))),
                  ],
                  onChanged: (val) => setDialogState(() => targaFissaMotorino = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeController.text.isEmpty || cognomeController.text.isEmpty) return;

                if (dip == null) {
                  dipendenti.add(Dipendente(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nome: nomeController.text,
                    cognome: cognomeController.text,
                    tipoMezzo: tipoMezzo,
                    targaFissaFurgone: targaFissaFurgone,
                    targaFissaMotorino: targaFissaMotorino,
                  ));
                } else {
                  dip.nome = nomeController.text;
                  dip.cognome = cognomeController.text;
                  dip.tipoMezzo = tipoMezzo;
                  dip.targaFissaFurgone = targaFissaFurgone;
                  dip.targaFissaMotorino = targaFissaMotorino;
                }

                await StorageManager.salvaDipendenti(dipendenti);
                setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Dipendenti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            },
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GestioneMezziPage()),
              );
            },
            tooltip: 'Gestione Mezzi',
          ),
        ],
      ),      body: ListView.builder(
        itemCount: dipendenti.length,
        itemBuilder: (context, index) {
          final dip = dipendenti[index];
          return ListTile(
            title: Text('${dip.nome} ${dip.cognome}'),
            subtitle: Text('${dip.tipoMezzo} - Furgone: ${dip.targaFissaFurgone ?? "casuale"}, Motorino: ${dip.targaFissaMotorino ?? "casuale"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => mostraDialogDipendente(dip),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    dipendenti.removeAt(index);
                    await StorageManager.salvaDipendenti(dipendenti);
                    setState(() {});
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostraDialogDipendente(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// GESTIONE MEZZI PAGE
class GestioneMezziPage extends StatefulWidget {
  const GestioneMezziPage({super.key});

  @override
  State<GestioneMezziPage> createState() => _GestioneMezziPageState();
}

class _GestioneMezziPageState extends State<GestioneMezziPage> {
  List<Mezzo> mezzi = [];

  @override
  void initState() {
    super.initState();
    caricaDati();
  }

  Future<void> caricaDati() async {
    mezzi = await StorageManager.caricaMezzi();
    setState(() {});
  }

  Future<void> mostraDialogMezzo([Mezzo? mezzo]) async {
    final targaController = TextEditingController(text: mezzo?.targa ?? '');
    String tipo = mezzo?.tipo ?? 'furgone';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(mezzo == null ? 'Nuovo Mezzo' : 'Modifica Mezzo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: targaController,
                decoration: const InputDecoration(labelText: 'Targa'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'furgone', child: Text('Furgone')),
                  DropdownMenuItem(value: 'motorino', child: Text('Motorino')),
                ],
                onChanged: (val) => setDialogState(() => tipo = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (targaController.text.isEmpty) return;

                if (mezzo == null) {
                  mezzi.add(Mezzo(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    targa: targaController.text.toUpperCase(),
                    tipo: tipo,
                  ));
                } else {
                  mezzo.targa = targaController.text.toUpperCase();
                  mezzo.tipo = tipo;
                }

                await StorageManager.salvaMezzi(mezzi);
                setState(() {});
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Mezzi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () async {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            },
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GestioneDipendentiPage()),
              );
            },
            tooltip: 'Gestione Dipendenti',
          ),
        ],
      ),      body: ListView.builder(
        itemCount: mezzi.length,
        itemBuilder: (context, index) {
          final mezzo = mezzi[index];
          return ListTile(
            title: Text(mezzo.targa),
            subtitle: Text(mezzo.tipo),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: !mezzo.fuoriUso,
                  onChanged: (val) async {
                    mezzo.fuoriUso = !val;
                    await StorageManager.salvaMezzi(mezzi);
                    setState(() {});
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => mostraDialogMezzo(mezzo),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    mezzi.removeAt(index);
                    await StorageManager.salvaMezzi(mezzi);
                    setState(() {});
                  },
                ),
              ],
            ),
            tileColor: mezzo.fuoriUso ? Colors.red.shade100 : null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => mostraDialogMezzo(),
        child: const Icon(Icons.add),
      ),
    );
  }
}