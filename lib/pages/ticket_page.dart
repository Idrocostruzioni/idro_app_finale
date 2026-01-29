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
    show mostraModuloCliente, ModuloInterventoPage;

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  // --- STATO PER IL CALENDARIO E L'UTENTE ---
  DateTime _selectedDay = DateTime.now();

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

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('it_IT', null);
    _caricaStati();
    _caricaUtenteCorrente();
  }

  static Future<void> _faiAzione(String schema, String path) async {
    final Uri url = Uri(scheme: schema, path: path);
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _caricaUtenteCorrente() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('staff').where('email', isEqualTo: user.email).limit(1).get();
      if (doc.docs.isNotEmpty) {
        setState(() {
          _currentUser = doc.docs.first.data();
        });
      }
    } catch (e) {
      debugPrint("Errore nel caricamento dello staff: $e");
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
      debugPrint("Errore caricamento stati: $e");
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
        appBar: AppBar(title: const Text("Gestione Ticket"), backgroundColor: Colors.red[100]),
        drawer: const MainDrawer(),
        body: const Center(
          child: Text("Questa visualizzazione a lista è disponibile solo su smartphone.", textAlign: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Gestione Ticket"), backgroundColor: Colors.red[100]),
      drawer: const MainDrawer(),
      body: _buildInterventiList(),
    );
  }

  Widget _buildInterventiList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('interventi')
          .where('stato', isEqualTo: 'Ticket')
          .snapshots(),
      builder: (context, snapshot) {
        // TEST 3: Verifica Permessi e Indici Firestore
        if (snapshot.hasError) {
          debugPrint("--- ERRORE STREAM INTERVENTI ---");
          debugPrint(snapshot.error.toString());
          return Center(child: Text("Errore nel caricamento: ${snapshot.error}"));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Nessun ticket presente."));
        }
        
        final allDocs = snapshot.data!.docs;

        // TEST 1: Verifica il Blocco Logico di _currentUser
        if (_currentUser == null) {
          // Mostra un caricamento finché i dati dell'utente non sono pronti.
          return const Center(child: CircularProgressIndicator());
        }
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
                child: Text("I MIEI TICKET", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16)),
              ),
              ...mieiInterventi.map((doc) => _buildInterventoCard(doc)).toList(),
            ],
            if (altriInterventi.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("TICKET DEGLI ALTRI TECNICI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
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
    } catch (e) { debugPrint(e.toString()); }
  }

  void _confermaEliminazione(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Conferma Eliminazione"),
        content: const Text("Sei sicuro di voler eliminare questo ticket? L'azione non è reversibile."),
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
            "Creato il ${dataInizio != null ? DateFormat('dd/MM/yyyy').format(dataInizio) : '--:--'}",
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
