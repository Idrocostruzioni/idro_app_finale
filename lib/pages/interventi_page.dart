import 'package:logging/logging.dart';

// ignore_for_file: unused_import

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../widgets/main_drawer.dart';
import 'clienti_page.dart'; // Importato per usare il modulo cliente
import 'package:intl/date_symbol_data_local.dart';
import 'interventi_page.dart'
    show mostraModuloCliente;

final _log = Logger('InterventiPage');

class InterventiPage extends StatefulWidget {
  const InterventiPage({super.key});

  @override
  State<InterventiPage> createState() => _InterventiPageState();
}

class _InterventiPageState extends State<InterventiPage> {
  // --- STATO PER IL CALENDARIO E L'UTENTE ---
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;

  // Dati utente corrente caricati da Firebase
  Map<String, dynamic>? _currentUser;

  // Mappa per le icone/foto dei tecnici (da caricare da Firestore/Storage)
  final Map<String, String> _fotoTecnici = {
    'Luca': 'https://example.com/luca.jpg', // Sostituire con URL reali
    'Luciano': 'https://example.com/luciano.jpg',
    'Mirko': 'https://example.com/mirko.jpg',
  };

  final ImagePicker _picker = ImagePicker();

  // Carica le impostazioni degli stati da Firestore
  List<Map<String, dynamic>> _stati = [];
  List<Map<String, dynamic>> _staff = [];

  @override
  void initState() {
    super.initState();
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      print('${record.level.name}: ${record.time}: ${record.message}');
    });
    initializeDateFormatting('it_IT', null);
    _caricaStati();
    _caricaStaff();
    _caricaUtenteCorrente();
  }

  static Future<void> _faiAzione(String schema, String path) async {
    final Uri url = Uri(scheme: schema, path: path);
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _caricaUtenteCorrente() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _log.warning("Nessun utente autenticato. Utilizzo utente Ospite di fallback.");
      if (mounted) {
        setState(() {
          _currentUser = {'nome': 'Ospite', 'ruolo': 'tecnico'};
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('staff').where('email', isEqualTo: user.email).limit(1).get();
      if (doc.docs.isNotEmpty && mounted) {
        setState(() {
          _currentUser = doc.docs.first.data();
        });
      } else if (mounted) {
        _log.warning("Utente ${user.email} non trovato nella collezione 'staff'. Utilizzo utente Ospite di fallback.");
        setState(() => _currentUser = {'nome': 'Ospite', 'ruolo': 'tecnico'});
      }
    } catch (e) {
      _log.severe("Errore nel caricamento dello staff: $e");
      setState(() { _currentUser = {'nome': 'Ospite', 'ruolo': 'tecnico'}; });
    }
  }

  Future<void> _caricaStati() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('impostazioni').doc('commesse').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _stati = List<Map<String, dynamic>>.from(doc.data()!['stati'] ?? []);
        });
      }
    } catch (e) {
      _log.severe("Errore caricamento stati: $e");
    }
  }

  Future<void> _caricaStaff() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('staff').get();
      setState(() {
        _staff = snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      _log.severe("Errore caricamento staff: $e");
    }
  }

  Color _getColoreStato(String? statoNome) {
    if (statoNome == null) return Colors.blueGrey;
    final stato = _stati.firstWhere((s) => s['nome'] == statoNome, orElse: () => {'colore': Colors.blueGrey.value});
    return Color(stato['colore']);
  }

  @override
  Widget build(BuildContext context) {
    // --- CONTROLLO PIATTAFORMA ---
    // Mostra questa pagina solo su mobile. Su web/desktop mostra un messaggio.
    final bool isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    if (!isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text("Gestione Interventi"), backgroundColor: Colors.blue[100]),
        drawer: const MainDrawer(),
        body: const Center(
          child: Text("Questa visualizzazione a lista è disponibile solo su smartphone.\nUsa l'Agenda Interventi da desktop.", textAlign: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Gestione Interventi"), backgroundColor: Colors.blue[100]),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(height: 1, thickness: 1),
          Expanded(child: _buildInterventiList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _moduloModifica(null, {}, false),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      locale: 'it_IT',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonShowsNext: false,
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() {
            _calendarFormat = format;
          });
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
    );
  }

  Widget _buildInterventiList() {
    final startOfDay = Timestamp.fromDate(DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day));
    final endOfDay = Timestamp.fromDate(DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 23, 59, 59));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('interventi')
          .where('dataInizio', isGreaterThanOrEqualTo: startOfDay)
          .where('dataInizio', isLessThanOrEqualTo: endOfDay)
          .orderBy('dataInizio')
          .snapshots(),
      builder: (context, snapshot) {
        _log.info("StreamBuilder interventi: connectionState=${snapshot.connectionState}, hasError=${snapshot.hasError}, hasData=${snapshot.hasData}");
        if (_currentUser == null) {
          // Mostra un caricamento finché i dati dell'utente non sono pronti.
          return const Center(child: CircularProgressIndicator());
        }
        
        // TEST 3: Verifica Permessi e Indici Firestore
        if (snapshot.hasError) {
          _log.severe("--- ERRORE STREAM INTERVENTI ---");
          _log.severe(snapshot.error.toString());
          return Center(child: Text("Errore nel caricamento: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nessun intervento programmato per oggi."));
        }
        
        final allDocs = snapshot.data!.docs;

        // TEST 1: Verifica il Blocco Logico di _currentUser
        final mioNome = _currentUser!['nome'];
        final mioRuolo = _currentUser!['ruolo'];

        // Filtra in base al ruolo
        final List<DocumentSnapshot> mieiInterventi;
        final List<DocumentSnapshot> altriInterventi;

        if (mioRuolo == 'tecnico') {
          mieiInterventi = allDocs.where((doc) => (doc.data() as Map)['tecnico'] == mioNome).toList();
          altriInterventi = []; // I tecnici non vedono gli altri
        } else { // 'impiegata' o altri ruoli vedono tutto
          mieiInterventi = allDocs.where((doc) => (doc.data() as Map)['tecnico'] == mioNome).toList();
          altriInterventi = allDocs.where((doc) => (doc.data() as Map)['tecnico'] != mioNome).toList();
        }

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            if (mieiInterventi.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("LE MIE ATTIVITÀ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
              ),
              ...mieiInterventi.map((doc) => _buildInterventoCard(doc)).toList(),
            ],
            if (altriInterventi.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("ATTIVITÀ ALTRI TECNICI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
              ),
              ...altriInterventi.map((doc) => _buildInterventoCard(doc)).toList(),
            ],
          ],
        );
      },
    );
  }
  Widget _buildInterventoCard(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final dataInizio = (d['dataInizio'] as Timestamp?)?.toDate();
    final dataFine = (d['dataFine'] as Timestamp?)?.toDate();
    final tecnico = d['tecnico'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _mostraFascicolo(context, doc.id, d),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _interventoCardContent(d, dataInizio, dataFine, tecnico),
        ),
      ),
    );
  }

  void _mostraFascicolo(BuildContext context, String idDoc, Map<String, dynamic> d) {
    final TextEditingController commentoC = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        expand: false, // Permette di chiudere con uno swipe verso il basso
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['tipo']?.toUpperCase() ?? "INTERVENTO", style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(d['cliente']?.toUpperCase() ?? "N/D", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  )),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _moduloModifica(idDoc, d, false)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confermaEliminazione(context, idDoc)),
                  ]),
                ],
              ),
              const Divider(),
              
              const Text("DESCRIZIONE LAVORO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11)),
              Container(
                width: double.infinity, 
                padding: const EdgeInsets.all(15),
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                child: Text(d['descrizione'] ?? "Nessuna nota.", style: const TextStyle(fontSize: 16)),
              ),

              _rowInfo(Icons.flag, "Stato", d['stato'] ?? "Programmato", _getColoreStato(d['stato'])),
              _rowInfo(Icons.engineering, "Tecnico", d['tecnico'] ?? "N/D", Colors.black),
              _rowInfo(Icons.location_on, "Indirizzo", "${d['via'] ?? ''}, ${d['citta'] ?? ''}", Colors.black),
              _rowInfo(Icons.phone, "Telefono", d['tel'] ?? "N/D", Colors.black),
              _rowInfo(Icons.email, "Email", d['mail'] ?? "N/D", Colors.black), // Corretto da 'email' a 'mail'
              _rowInfo(Icons.tag, "Tag / Riferimento", d['tag'] ?? "Nessuno", Colors.black),
              _rowInfo(Icons.access_time, "Data/Ora", d['dataInizio'] != null
                ? DateFormat('dd/MM/yyyy HH:mm').format((d['dataInizio'] as Timestamp).toDate()) : "N/D", Colors.black),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btnRound(Icons.phone, "Chiama", Colors.green, () => _faiAzione('tel', d['tel'] ?? '')),
                  _btnRound(Icons.chat, "WA", const Color(0xFF25D366), () => _faiAzione('https', "wa.me/39${d['tel']}")),
                  _btnRound(Icons.mail, "Email", Colors.redAccent, () => _faiAzione('mailto', d['mail'] ?? '')),
                  _btnRound(Icons.directions, "Mappe", Colors.blue, () => _faiAzione('google.navigation', "q=${Uri.encodeComponent('${d['via']}, ${d['citta']}')}")),
                ],
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon( // --- BOTTONE PER PIANIFICARE SEGUITO ---
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[800], padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.next_plan, color: Colors.white),
                  label: const Text("PIANIFICA SEGUITO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _moduloModifica(idDoc, d, true),
                ),
              ),

              const Divider(height: 50),

              const Text("DIARIO DI CANTIERE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(30)),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.add_a_photo, color: Colors.orange), onPressed: () => _scattaEPosta(idDoc, d['tecnico'] ?? "Admin")),
                    Expanded(child: TextField(controller: commentoC, decoration: const InputDecoration(hintText: "Scrivi un aggiornamento...", border: InputBorder.none))),
                    IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: () async {
                      if (commentoC.text.isEmpty) return;
                      await _aggiungiPost(idDoc, d['tecnico'] ?? "Admin", testo: commentoC.text);
                      commentoC.clear();
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('interventi').doc(idDoc).collection('feed').orderBy('data', descending: true).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return Column(
                    children: snap.data!.docs.map((docPost) {
                      var post = docPost.data() as Map<String, dynamic>;
                      DateTime dt = post['data'] != null ? (post['data'] as Timestamp).toDate() : DateTime.now();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 15),
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              dense: true,
                              leading: CircleAvatar(child: Text(post['autore']?[0] ?? "U")),
                              title: Text(post['autore'] ?? "Utente", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(DateFormat('dd/MM HH:mm').format(dt)),
                            ),
                            if (post['tipo'] == 'FOTO') Image.network(post['url'], fit: BoxFit.cover, width: double.infinity, height: 250),
                            if (post['messaggio'] != "") Padding(padding: const EdgeInsets.all(12), child: Text(post['messaggio'] ?? "")),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // BLOCCO CORRETTO: MODIFICA E SALVATAGGIO TOTALE
  // ==========================================
  void _moduloModifica(String? idDoc, Map<String, dynamic> d, bool isDuplicazione) {
    // Naviga a una pagina dedicata per la modifica/creazione
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ModuloInterventoPage(
          idDoc: idDoc,
          datiIniziali: d,
          isDuplicazione: isDuplicazione,
          dataSelezionata: _selectedDay,
        ),
      ),
    );
  }

  // --- FUNZIONI DI SUPPORTO ---
  Future<void> _aggiungiPost(String idDoc, String autore, {String? testo, String? tipo, String? url}) async {
    await FirebaseFirestore.instance.collection('interventi').doc(idDoc).collection('feed').add({
      'autore': autore, 'data': FieldValue.serverTimestamp(), 'tipo': tipo ?? 'NOTA', 'messaggio': testo ?? '', 'url': url ?? '',
    });
  }

  Future<void> _scattaEPosta(String idDoc, String tecnico) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
      if (image == null) return;
      String fileName = "post_${DateTime.now().millisecondsSinceEpoch}.jpg";
      Reference ref = FirebaseStorage.instance.ref().child('interventi/$idDoc/feed/$fileName');
      await ref.putFile(File(image.path));
      String url = await ref.getDownloadURL();
      await _aggiungiPost(idDoc, tecnico, tipo: 'FOTO', url: url, testo: 'Foto dal cantiere');
    } catch (e) { _log.severe(e.toString()); }
  }

  void _confermaEliminazione(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Conferma Eliminazione"),
        content: const Text("Sei sicuro di voler eliminare questo intervento? L'azione non è reversibile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annulla")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Chiude il dialog
              Navigator.pop(context); // Chiude la scheda
              await FirebaseFirestore.instance.collection('interventi').doc(id).delete();
            },
            child: const Text("ELIMINA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _interventoCardContent(Map<String, dynamic> d, DateTime? dataInizio, DateTime? dataFine, String? tecnico) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(d['cliente'] ?? 'N/D', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
            ),
            if (tecnico != null && _fotoTecnici.containsKey(tecnico))
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                // backgroundImage: NetworkImage(_fotoTecnici[tecnico]!), // Abilitare con URL reali
                child: Text(tecnico.substring(0,1)), // Fallback con iniziale
              ),
          ],
        ),
        const SizedBox(height: 8),
        _cardInfoRow(Icons.construction, d['tipo'] ?? 'Non specificato'),
        const SizedBox(height: 4),
        _cardInfoRow(Icons.location_on_outlined, "${d['via'] ?? ''}, ${d['citta'] ?? ''}"),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getColoreStato(d['stato']).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _cardInfoRow(
            Icons.access_time_filled,
            "Dalle ${dataInizio != null ? DateFormat('HH:mm').format(dataInizio) : '--:--'} alle ${dataFine != null ? DateFormat('HH:mm').format(dataFine) : '--:--'}",
            color: _getColoreStato(d['stato']),
          ),
        ),
      ],
    );
  }

  Widget _rowInfo(IconData i, String l, String v, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [Icon(i, size: 18, color: c), const SizedBox(width: 10), Text("$l:", style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 5), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))]),
  );

  Widget _btnRound(IconData i, String l, Color c, VoidCallback o) => Column(
    children: [CircleAvatar(radius: 25, backgroundColor: c, child: IconButton(icon: Icon(i, color: Colors.white), onPressed: o)), const SizedBox(height: 5), Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))]);
}

Widget _cardInfoRow(IconData icon, String text, {Color? color}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: color ?? Colors.grey[700]),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: color ?? Colors.black87))),
    ],
  );
}

// =======================================================================
// PAGINA DEDICATA PER CREAZIONE/MODIFICA INTERVENTO
// =======================================================================
class ModuloInterventoPage extends StatefulWidget {
  final String? idDoc;
  final Map<String, dynamic> datiIniziali;
  final bool isDuplicazione;
  final DateTime dataSelezionata;

  const ModuloInterventoPage({
    super.key,
    this.idDoc,
    required this.datiIniziali,
    required this.isDuplicazione,
    required this.dataSelezionata,
  });

  @override
  _ModuloInterventoPageState createState() => _ModuloInterventoPageState();
}

class _ModuloInterventoPageState extends State<ModuloInterventoPage> {
  late TextEditingController clienteC;
  late TextEditingController viaC;
  late TextEditingController cittaC;
  late TextEditingController telC;
  late TextEditingController emailC;
  late TextEditingController descC;

  late String tecnicoS;
  late String tipoS;
  late String statoS;
  late DateTime dataInizio;
  late DateTime dataFine;

  List<Map<String, dynamic>> _stati = [];
  List<String> _tipologie = [];
  List<String> nomiTecnici = [];

  bool isClienteSelezionato = false;
  bool isLoading = true;
  bool isSaving = false;
  late bool isNew;

  @override
  void initState() {
    super.initState();
    _caricaDatiSupporto();
    isNew = widget.idDoc == null && !widget.isDuplicazione;
    final d = widget.datiIniziali;

    clienteC = TextEditingController(text: d['cliente']);
    viaC = TextEditingController(text: d['via'] ?? '');
    cittaC = TextEditingController(text: d['citta'] ?? '');
    telC = TextEditingController(text: d['tel'] ?? '');
    emailC = TextEditingController(text: d['mail'] ?? '');
    descC = TextEditingController(text: widget.isDuplicazione ? "Seguito di: ${d['tipo']}" : d['descrizione']);

    tecnicoS = (d['tecnico'] as String?) ?? "Non Assegnato";
    tipoS = (d['tipo'] as String?) ?? "Generico";
    statoS = (d['stato'] as String?) ?? "Programmato";

    dataInizio = (d['dataInizio'] as Timestamp?)?.toDate() ?? DateTime.now();
    dataFine = (d['dataFine'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 1));

    if (isNew) {
      final now = DateTime.now();
      dataInizio = DateTime(widget.dataSelezionata.year, widget.dataSelezionata.month, widget.dataSelezionata.day, now.hour, now.minute);
      dataFine = dataInizio.add(const Duration(hours: 1));
    } else if (widget.isDuplicazione) {
      dataInizio = DateTime.now();
      dataFine = dataInizio.add(const Duration(hours: 1));
    }
  }

  Future<void> _caricaDatiSupporto() async {
    try { // FIX: Rimosso _log.severe
      final commesseDoc = await FirebaseFirestore.instance.collection('impostazioni').doc('commesse').get();
      if (commesseDoc.exists && commesseDoc.data() != null) {
        _stati = List<Map<String, dynamic>>.from(commesseDoc.data()!['stati'] ?? []);
        _tipologie = List<String>.from(commesseDoc.data()!['tipologie'] ?? []);
      }
      final staffSnapshot = await FirebaseFirestore.instance.collection('staff').get();
      nomiTecnici = staffSnapshot.docs.map((doc) => doc.data()['nome'] as String).toList();

      // Aggiungi "Non Assegnato" come opzione per i tecnici se non c'è già
      if (!nomiTecnici.contains("Non Assegnato")) {
        nomiTecnici.insert(0, "Non Assegnato");
      }

      // --- Validazione e impostazione valori di default ---
      // Se il valore iniziale non è presente nella lista caricata, imposta un valore di default valido.
      if (!_tipologie.contains(tipoS)) {
        tipoS = _tipologie.isNotEmpty ? _tipologie.first : "Generico";
      }
      if (!nomiTecnici.contains(tecnicoS)) {
        tecnicoS = nomiTecnici.isNotEmpty ? nomiTecnici.first : "Non Assegnato";
      }
      if (_stati.firstWhereOrNull((s) => s['nome'] == statoS) == null) {
        statoS = _stati.isNotEmpty ? _stati.first['nome'] as String : "Programmato";
      }
    } catch (e) { _log.severe("Errore caricamento dati di supporto: $e"); }
    finally { if(mounted) setState(() => isLoading = false); }
  }

  void _precompilaDatiCliente(Map<String, dynamic> cliente) {
    setState(() {
      clienteC.text = "${cliente['cognome'] ?? ''} ${cliente['nome'] ?? ''}".trim();
      viaC.text = _getPrimaryValue(cliente, 'indirizzi', 'via') ?? '';
      cittaC.text = _getPrimaryValue(cliente, 'indirizzi', 'citta') ?? '';
      telC.text = _getPrimaryValue(cliente, 'telefoni', 'numero') ?? '';
      emailC.text = _getPrimaryValue(cliente, 'emails', 'email') ?? '';
      isClienteSelezionato = true;
    });
  }

  Future<void> _salvaIntervento() async {
    setState(() => isSaving = true);
    try {
      Map<String, dynamic> data = {
        'cliente': clienteC.text, 'via': viaC.text, 'citta': cittaC.text,
        'tel': telC.text, 'mail': emailC.text, 'tecnico': tecnicoS,
        'tipo': tipoS, 'stato': statoS, 'descrizione': descC.text,
        'dataInizio': Timestamp.fromDate(dataInizio), 'dataFine': Timestamp.fromDate(dataFine),
      };

      if (isNew || widget.isDuplicazione) {
        await FirebaseFirestore.instance.collection('interventi').add(data);
      } else {
        await FirebaseFirestore.instance.collection('interventi').doc(widget.idDoc).set(data, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.of(context).pop(); // Chiude questa pagina
        if (widget.isDuplicazione && mounted) {
          Navigator.of(context).pop(); // Chiude anche la scheda di dettaglio da cui è partita la duplicazione
        }
      }
    } catch (e) {
      _log.severe("Errore salvataggio intervento: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
      }
    } finally { // FIX: Aggiunto controllo 'mounted'
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _campoM(TextEditingController c, String l, IconData i, {int maxLines = 1, FocusNode? focusNode, Function(String)? onChanged, TextEditingController? controllerPrincipale}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      focusNode: focusNode,
      onChanged: onChanged ?? (value) {
        // Se viene fornito un controller principale, aggiornalo.
        if (controllerPrincipale != null) controllerPrincipale.text = value;
      },
      decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder())
    ),
  );

  Widget _buildDateTimePicker(String label, DateTime initialDate, Function(DateTime) onDateChanged) {
    return Builder(builder: (context) {
      return InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (date == null) return;

          final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initialDate));
          if (time == null) return;

          final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          onDateChanged(newDateTime);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.calendar_today)),
          child: Text(DateFormat('dd/MM/yyyy HH:mm').format(initialDate)),
        ),
      );
    });
  }

  // Funzione helper per ottenere il primo valore da una lista di mappe (versione semplificata)
  String? _getPrimaryValue(Map<String, dynamic> data, String listKey, String valueKey) {
    if (data.containsKey(listKey) && data[listKey] is List) {
      final list = data[listKey] as List;
      if (list.isNotEmpty && list.first is Map) {
        return list.first[valueKey];
      }
    }
    // Fallback per la vecchia struttura dati
    final oldKey = (valueKey == 'numero') ? 'tel' : (valueKey == 'email') ? 'mail' : valueKey;
    return data[oldKey];
  }

  // --- START: Logica suggerimenti indirizzi (copiata da clienti_page.dart) ---
  final String _googleApiKey = "AIzaSyCN0k2Hvyn51Buz7zlkZrqsnllSygQtTuI";

  Future<List<Map<String, dynamic>>> _getSuggestions(String pattern) async {
    if (pattern.isEmpty || isClienteSelezionato) return []; // Non suggerire se un cliente è già stato selezionato
    String url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$pattern&key=$_googleApiKey&language=it&components=country:it';

    // FIX per il web: Aggiunge un proxy CORS per evitare blocchi del browser.
    final String request = kIsWeb ? 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}' : url;

    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') return List<Map<String, dynamic>>.from(data['predictions'] as List);
      }
    } catch (e) { _log.severe("Errore suggerimenti indirizzo: $e"); }
    return [];
  }

  Future<Map<String, String>> _getPlaceDetails(String placeId) async {
    String url = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey&language=it&fields=address_component,name';

    // FIX per il web: Aggiunge un proxy CORS per evitare blocchi del browser.
    final String request = kIsWeb ? 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}' : url;

    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final components = data['result']['address_components'] as List;
          String streetNumber = components.firstWhere((c) => c['types'].contains('street_number'), orElse: () => {'long_name': ''})['long_name'];
          String route = components.firstWhere((c) => c['types'].contains('route'), orElse: () => {'long_name': ''})['long_name'];
          return {'via': '$route, $streetNumber'.replaceAll(RegExp(r'^, |,$'), ''),'citta': components.firstWhere((c) => c['types'].contains('locality'), orElse: () => {'long_name': ''})['long_name']};
        }
      }
    } catch (e) { _log.severe("Errore dettagli luogo: $e"); }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    String titoloPagina = isNew ? "Nuovo Intervento" : (widget.isDuplicazione ? "Pianifica Seguito" : "Modifica Intervento");

    return Scaffold(
      appBar: AppBar(
        title: Text(titoloPagina),
        actions: [
          IconButton(
            icon: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save),
            onPressed: isSaving ? null : _salvaIntervento,
          )
        ],
      ),
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TypeAheadField<DocumentSnapshot>(
                builder: (context, controller, focusNode) => TextField(
                  controller: clienteC,
                  textCapitalization: TextCapitalization.characters,
                  focusNode: focusNode,
                  onChanged: (value) {
                    if (focusNode.hasFocus) setState(() => isClienteSelezionato = false);
                  },
                  decoration: InputDecoration(
                    labelText: "Cerca o seleziona cliente", prefixIcon: const Icon(Icons.person_search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.person_add_alt_1, color: Colors.green),
                      onPressed: () async {
                        // FIX: Usa il modulo unificato per creare il cliente
                        final nuovoCliente = await ClientiPage.mostraModuloCliente(context);
                        if (nuovoCliente != null && mounted) {
                          _precompilaDatiCliente(nuovoCliente);
                        }
                      },
                    ),
                  ),
                ),
                suggestionsCallback: (pattern) async {
                  if (pattern.isEmpty) return const <DocumentSnapshot>[];
                  final lowerPattern = pattern.toLowerCase();
                  try {
                    final cognomeQuery = FirebaseFirestore.instance.collection('clienti').where('cognome_lowercase', isGreaterThanOrEqualTo: lowerPattern).where('cognome_lowercase', isLessThanOrEqualTo: '$lowerPattern\uf8ff').get();
                    final nomeQuery = FirebaseFirestore.instance.collection('clienti').where('nome', isGreaterThanOrEqualTo: pattern).where('nome', isLessThanOrEqualTo: '$pattern\uf8ff').get();
                    final codiceQuery = FirebaseFirestore.instance.collection('clienti').where('codice', isEqualTo: pattern).get();
                    
                    final results = await Future.wait([cognomeQuery, nomeQuery, codiceQuery]);
                    return [...results[0].docs, ...results[1].docs, ...results[2].docs].toSet().toList();
                  } catch (e) {
                    _log.severe("Errore query suggerimenti cliente (verificare indici Firestore): $e");
                    return const <DocumentSnapshot>[];
                  }
                },
                itemBuilder: (context, suggestion) {
                  final cliente = suggestion.data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text("${cliente['cognome'] ?? ''} ${cliente['nome'] ?? ''}".trim()),
                    subtitle: Text("Cod: ${cliente['codice'] ?? ''}"),
                  );
                },
                onSelected: (suggestion) {
                  final cliente = suggestion.data() as Map<String, dynamic>;
                  _precompilaDatiCliente(cliente);
                },
              ),
              TypeAheadField<Map<String, dynamic>>(
                builder: (context, controller, focusNode) {
                  controller.text = viaC.text;
                  return _campoM(controller, "Via e civico", Icons.location_on, focusNode: focusNode, onChanged: (v) => viaC.text = v, controllerPrincipale: viaC);
                },
                suggestionsCallback: _getSuggestions,
                onSelected: (suggestion) async {
                  final placeId = suggestion['place_id'];
                  if (placeId != null) {
                    final details = await _getPlaceDetails(placeId);
                    setState(() {
                      viaC.text = details['via'] ?? '';
                      cittaC.text = details['citta'] ?? '';
                    });
                  }
                },
                itemBuilder: (context, suggestion) => ListTile(title: Text(suggestion['description'])),
              ),
              _campoM(cittaC, "Città", Icons.location_city),
              _campoM(telC, "Telefono", Icons.phone),
              _campoM(emailC, "Email", Icons.email),
              DropdownButtonFormField<String>(
                value: tecnicoS,
                items: nomiTecnici.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => tecnicoS = v);
                  }
                },
                decoration: const InputDecoration(labelText: "Tecnico Assegnato", prefixIcon: Icon(Icons.engineering)),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tipoS,
                items: _tipologie.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => tipoS = v);
                  }
                },
                decoration: const InputDecoration(labelText: "Tipo Lavoro", prefixIcon: Icon(Icons.work)),
              ),
              const SizedBox(height: 10),
              const Divider(),
              DropdownButtonFormField<String>(
                value: statoS,
                items: _stati.map((s) => DropdownMenuItem(value: s['nome'] as String, child: Text(s['nome'] as String))).toList(),
                onChanged: (v) => setState(() => statoS = v!),
                decoration: const InputDecoration(labelText: "Stato"),
              ),
              _campoM(descC, "Descrizione / Note", Icons.note, maxLines: 4),
              const Divider(height: 20),
              _buildDateTimePicker("Inizio", dataInizio, (newDate) => setState(() => dataInizio = newDate)),
              const SizedBox(height: 10),
              _buildDateTimePicker("Fine", dataFine, (newDate) => setState(() => dataFine = newDate)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: isSaving ? const SizedBox.shrink() : const Icon(Icons.save),
                  label: isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isNew ? "CREA INTERVENTO" : "SALVA MODIFICHE"),
                  onPressed: isSaving ? null : _salvaIntervento,
                ),
              )
            ],
          ),
        ),
    );
  }
}

class mostraModuloCliente {
}