// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart'; // Per suggerimenti indirizzo
import '../widgets/main_drawer.dart';

class ClientiPage extends StatefulWidget {
  const ClientiPage({super.key});

  @override
  State<ClientiPage> createState() => _ClientiPageState();

  static Future<dynamic> mostraModuloCliente(BuildContext context) async {}
}

class _ClientiPageState extends State<ClientiPage> {
  // --- CHIAVE API DI GOOGLE INSERITA ---
  // Assicurati di aver abilitato "Places API" e di aver limitato la chiave
  // al tuo bundle ID (iOS) e package name (Android).
  // --- ATTENZIONE: CHIAVE API PUBBLICA ---
  // La chiave API è visibile nel codice sorgente. Per la produzione, è FONDAMENTALE
  // proteggerla utilizzando variabili d'ambiente (es. con il pacchetto flutter_dotenv)
  // o un servizio di backend per evitare abusi e costi imprevisti.
  final String _googleApiKey = "AIzaSyCN0k2Hvyn51Buz7zlkZrqsnllSygQtTuI";
  
  // Variabili per le configurazioni caricate da Firestore
  Map<String, dynamic> _configIntegrazioni = {};
  List<Map<String, dynamic>> _messaggiWhatsapp = [];
  List<Map<String, dynamic>> _messaggiEmail = [];

  String queryRicerca = "";

  // -------------------------------------------------------------------------
  // INIZIO BLOCCO 1: FUNZIONE DI LANCIO URL (CHIAMATE, MAPPE)
  // -------------------------------------------------------------------------
  Future<void> _faiAzione(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  // -------------------------------------------------------------------------
  // FINE BLOCCO 1: FUNZIONE 1
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // INIZIO BLOCCO 2: GENERATORE CODICE CLIENTE AUTOMATICO
  // -------------------------------------------------------------------------
  Future<String> _generaCodiceCliente() async {
    final anno = DateTime.now().year.toString().substring(2);
    final snapshot = await FirebaseFirestore.instance.collection('clienti').get();
    int progressivo = snapshot.docs.length + 1;
    String numero = progressivo.toString().padLeft(2, '0');
    return "$numero$anno";
  }
  // -------------------------------------------------------------------------
  // FINE BLOCCO 2: GENERATORE CODICE 2
  // -------------------------------------------------------------------------

  // Funzione per ottenere suggerimenti indirizzi da Google Places API
  Future<List<Map<String, dynamic>>> _getSuggestions(String pattern) async {
    if (pattern.isEmpty) {
      return [];
    }

    String baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String url = '$baseUrl?input=$pattern&key=$_googleApiKey&language=it&components=country:it';

    // FIX per il web: Aggiunge un proxy CORS per evitare blocchi del browser.
    final String request = kIsWeb ? 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}' : url;

    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['predictions'] as List);
        }
      } else {
        
        debugPrint("Errore API Google: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Errore nel recupero dei suggerimenti: $e");
    }
    return [];
  }

  // Funzione per ottenere dettagli di un luogo (via, città, cap)
  Future<Map<String, String>> _getPlaceDetails(String placeId) async {
    String baseUrl = 'https://maps.googleapis.com/maps/api/place/details/json';
    String url = '$baseUrl?place_id=$placeId&key=$_googleApiKey&language=it&fields=address_component,name';

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
          String city = components.firstWhere((c) => c['types'].contains('locality'), orElse: () => {'long_name': ''})['long_name'];
          String postalCode = components.firstWhere((c) => c['types'].contains('postal_code'), orElse: () => {'long_name': ''})['long_name'];
          
          return {
            'via': '$route, $streetNumber'.replaceAll(RegExp(r'^, |,$'), ''), // Pulisce la via se uno dei due è vuoto
            'citta': city,
            'cap': postalCode,
          };
        }
      }
    } catch (e) { debugPrint("Errore nei dettagli del luogo: $e"); }
    return {};
  }

  // Carica le configurazioni all'avvio della pagina
  @override
  void initState() {
    super.initState();
    _caricaConfigurazioni();
  }

  Future<void> _caricaConfigurazioni() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('impostazioni').doc('config').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _configIntegrazioni = doc.data()!;
          _messaggiWhatsapp = List<Map<String, dynamic>>.from(doc.data()!['messaggi_preimpostati'] ?? []);
          _messaggiEmail = List<Map<String, dynamic>>.from(doc.data()!['email_preimpostate'] ?? []);
        });
      }
    } catch (e) { debugPrint("Errore caricamento configurazioni: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // -------------------------------------------------------------------------
      // INIZIO BLOCCO 3: APPBAR E BARRA DI RICERCA
      // -------------------------------------------------------------------------
      appBar: AppBar(
        title: const Text("Anagrafica Clienti"),
        backgroundColor: Colors.blue[100],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (val) => setState(() => queryRicerca = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Cerca per cognome, tel o codice...",
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      // -------------------------------------------------------------------------
      // FINE BLOCCO 3: APPBAR 3
      // -------------------------------------------------------------------------

      drawer: const MainDrawer(),

      // -------------------------------------------------------------------------
      // INIZIO BLOCCO 4: BOTTONE AGGIUNGI CLIENTE (FAB)
      // -------------------------------------------------------------------------
      floatingActionButton: FloatingActionButton( // FIX: Cambiato per usare il metodo statico
        onPressed: () => mostraModuloCliente(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      // -------------------------------------------------------------------------
      // FINE BLOCCO 4: FAB 4
      // -------------------------------------------------------------------------

      // -------------------------------------------------------------------------
      // INIZIO BLOCCO 5: LISTA CLIENTI ORDINATA
      // -------------------------------------------------------------------------
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clienti').orderBy('cognome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Errore di connessione"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final cognome = (data['cognome'] ?? "").toString().toLowerCase();
            final nome = (data['nome'] ?? "").toString().toLowerCase();
            final tel = (data['tel'] ?? "").toString().toLowerCase();
            final cod = (data['codice'] ?? "").toString().toLowerCase();
            return cognome.contains(queryRicerca) || nome.contains(queryRicerca) || tel.contains(queryRicerca) || cod.contains(queryRicerca);
          }).toList();

          if (docs == null || docs.isEmpty) return const Center(child: Text("Nessun cliente trovato."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final idDoc = docs[index].id; // FIX: Aggiunto controllo null
              final cliente = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    // Aggiunto controllo per stringa vuota per evitare RangeError
                    child: Text((cliente['cognome'] != null && cliente['cognome'].isNotEmpty) ? cliente['cognome'].substring(0, 1) : 'C')
                  ),
                  title: Text(
                    "${cliente['cognome']?.toUpperCase() ?? ''} ${cliente['nome']?.toUpperCase() ?? ''}", 
                    style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                    "Cod: ${cliente['codice'] ?? '-'} | Tel: ${_getPrimaryValue(cliente, 'telefoni', 'numero')}\n${_getPrimaryValue(cliente, 'indirizzi', 'via')}, ${_getPrimaryValue(cliente, 'indirizzi', 'citta')}"
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => mostraModuloCliente(context, dati: cliente, idDocumento: idDoc),
                ),
              );
            },
          );
        },
      ),
      // -------------------------------------------------------------------------
      // FINE BLOCCO 5: LISTA 5
      // -------------------------------------------------------------------------
    );
  }

  // Funzione helper per ottenere il primo valore da una lista di mappe
  String _getPrimaryValue(Map<String, dynamic> data, String listKey, String valueKey) {
    if (data.containsKey(listKey) && data[listKey] is List && (data[listKey] as List).isNotEmpty) {
      return (data[listKey] as List).first[valueKey] ?? '';
    }
    // Fallback per la vecchia struttura dati
    final oldKey = (valueKey == 'numero') 
        ? 'tel' 
        : (valueKey == 'email') ? 'mail' 
        : (valueKey == 'via' || valueKey == 'citta') ? valueKey // Gestisce 'via' e 'citta' per il fallback
        : valueKey;
    return data[oldKey] ?? '';
  }

  // -------------------------------------------------------------------------
  // INIZIO BLOCCO 6: MODULO SCHEDA CLIENTE E LOGICA BLOCCO MODIFICA
  // -------------------------------------------------------------------------
  // Trasformato in un metodo statico per essere riutilizzabile da altre pagine
  Future<Map<String, dynamic>?> mostraModuloCliente(BuildContext context, {Map<String, dynamic>? dati, String? idDocumento}) {

    return showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _ModuloCliente(
        dati: dati,
        idDocumento: idDocumento,
        googleApiKey: _googleApiKey,
        // Passa le funzioni helper al costruttore per evitare accessi non sicuri e accoppiamento
        onFaiAzione: _faiAzione,
        onGeneraCodiceCliente: _generaCodiceCliente,
        onGetSuggestions: _getSuggestions,
        onGetPlaceDetails: _getPlaceDetails,
        onConfermaEliminazione: _confermaEliminazione,
        onInviaTramiteTwilio: _inviaTramiteTwilio,
        onInviaTramiteMailto: _inviaTramiteMailto,
        configIntegrazioni: _configIntegrazioni,
        messaggiWhatsapp: _messaggiWhatsapp,
        messaggiEmail: _messaggiEmail,
      ),
    );
  }

  // --- WIDGETS PER SEZIONI DINAMICHE ---

  Widget _buildSezioneDinamica(String titolo, List<Map<String, dynamic>> lista, String chiaveValore, IconData icona, bool abilitato, StateSetter setModalState, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (abilitato) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => setModalState(() => lista.add({'label': '', chiaveValore: ''})),
              ),
            ],
          ),
          ...lista.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> item = entry.value;
            return Row(
              children: [
                Flexible(flex: 2, child: _input(TextEditingController(text: item['label']), "Etichetta", Icons.label_outline, abilitato: abilitato, onChanged: (val) => item['label'] = val)),
                const SizedBox(width: 8),
                Flexible(flex: 3, child: _input(TextEditingController(text: item[chiaveValore]), "Valore", icona, abilitato: abilitato, onChanged: (val) => item[chiaveValore] = val)),
                if (lista.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setModalState(() => lista.removeAt(idx))),
              ],
            );
          }),
        ]
      ],
    );
  }

  Widget _buildSelettoreAttivo(String titolo, Map<String, dynamic>? valoreAttivo, List<Map<String, dynamic>> lista, IconData icona, Function(Map<String, dynamic>?) onChanged) {
    if (lista.length <= 1) return const SizedBox.shrink(); // Non mostrare se c'è solo un'opzione
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<Map<String, dynamic>>( // FIX: 'value' is deprecated.
        value: valoreAttivo,
        isExpanded: true, // FIX: Previene l'overflow con testi lunghi
        decoration: InputDecoration(labelText: titolo, prefixIcon: Icon(icona), border: const OutlineInputBorder()),
        items: lista.map((item) => DropdownMenuItem(
          value: item,
          child: Tooltip(
            message: _getDropdownText(item),
            child: Text(
              _getDropdownText(item),
              overflow: TextOverflow.ellipsis, // Evita l'overflow del testo
              style: const TextStyle(fontSize: 14), // Stile più compatto
            ),
          )
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _getDropdownText(Map<String, dynamic> item) {
    if (item == null) return '';
    final label = item['label'] ?? '';
    if (item.containsKey('numero')) return "$label: ${item['numero'] ?? ''}";
    if (item.containsKey('email')) return "$label: ${item['email'] ?? ''}";
    if (item.containsKey('via')) return "$label: ${item['via']}";
    // Fallback se nessuna delle chiavi attese è presente
    final value = item.values.length > 1 ? item.values.elementAt(1) : '';
    return "$label: $value";
  }

  // Funzione helper per ottenere solo il valore da mostrare nella seconda riga del dropdown
  String _getDropdownValueText(Map<String, dynamic>? item) {
    if (item == null) return '';
    if (item.containsKey('numero')) return item['numero'] ?? '';
    if (item.containsKey('email')) return item['email'] ?? '';
    if (item.containsKey('via')) { // Per gli indirizzi, mostra via, città, cap
      final parts = <String>[];
      if (item['via'] != null && item['via'].isNotEmpty) parts.add(item['via']);
      if (item['citta'] != null && item['citta'].isNotEmpty) parts.add(item['citta']);
      if (item['cap'] != null && item['cap'].isNotEmpty) parts.add(item['cap']);
      return parts.join(', ');
    }
    return ''; // Ritorna stringa vuota se non trova una chiave specifica
  }

  // --- NUOVO BLOCCO: LOGICA MESSAGGISTICA ---

  Widget _menuMessaggi(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic>? telefonoAttivo) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (telefonoAttivo == null) return;
        if (value == 'custom') {
          _dialogInvioMessaggio(context, datiCliente, telefonoAttivo, "Messaggio Personalizzato", "");
        } else {
          // Cerca il template selezionato
          final template = _messaggiWhatsapp.firstWhere((m) => m['titolo'] == value);
          _dialogInvioMessaggio(context, datiCliente, telefonoAttivo, template['titolo'], template['testo']);
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];
        // Aggiungi i messaggi preimpostati
        items.addAll(_messaggiWhatsapp.map((msg) => PopupMenuItem<String>(
          value: msg['titolo'],
          child: Text(msg['titolo']),
        )));
        // Aggiungi separatore e opzione custom
        if (items.isNotEmpty) items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem<String>(value: 'custom', child: Text("Messaggio personalizzato...")));
        return items;
      },
      child: _btnTondoIcona(Icons.chat, Colors.teal), // Usa il bottone passivo
    );
  }

  void _dialogInvioMessaggio(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic> telefono, String titolo, String testoTemplate) {
    // Sostituisci i segnaposto con i dati reali del cliente
    String testoPersonalizzato = testoTemplate
      .replaceAll('[NOME_CLIENTE]', datiCliente['nome'] ?? '')
      .replaceAll('[COGNOME_CLIENTE]', datiCliente['cognome'] ?? '')
      .replaceAll('[CODICE_CLIENTE]', datiCliente['codice'] ?? '')
      .replaceAll('[VIA_CLIENTE]', datiCliente['via'] ?? '')
      .replaceAll('[CITTA_CLIENTE]', datiCliente['citta'] ?? '');

    final testoCtrl = TextEditingController(text: testoPersonalizzato);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titolo),
        content: TextField(
          controller: testoCtrl,
          maxLines: 6,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Invia via WhatsApp"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              _inviaTramiteTwilio(telefono['numero'], testoCtrl.text);
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _inviaTramiteTwilio(String numeroDestinatario, String messaggio) async {
    // Qui andrebbe la vera chiamata API a Twilio
    // Per ora, simuliamo l'azione stampando in console
    final sid = _configIntegrazioni['twilio_sid'];
    final fromNumber = _configIntegrazioni['twilio_from_number'];

    debugPrint("--- SIMULAZIONE INVIO TWILIO ---");
    debugPrint("Account SID: $sid");
    debugPrint("Da: $fromNumber");
    debugPrint("A: whatsapp:+39$numeroDestinatario");
    debugPrint("Messaggio: $messaggio");
    debugPrint("--------------------------------");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Messaggio inviato (simulazione). Controlla la console.")));
  }

  Widget _menuEmail(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic>? emailAttiva) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (emailAttiva == null) return;
        if (value == 'custom') {
          _dialogInvioEmail(context, datiCliente, emailAttiva, "Email Personalizzata", "", "");
        } else {
          final template = _messaggiEmail.firstWhere((m) => m['titolo'] == value);
          _dialogInvioEmail(context, datiCliente, emailAttiva, template['titolo'], template['oggetto'], template['testo']);
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];
        items.addAll(_messaggiEmail.map((msg) => PopupMenuItem<String>(
          value: msg['titolo'],
          child: Text(msg['titolo']),
        )));
        if (items.isNotEmpty) items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem<String>(value: 'custom', child: Text("Email personalizzata...")));
        return items;
      },
      child: _btnTondoIcona(Icons.email, Colors.redAccent), // Usa il bottone passivo
    );
  }

  void _dialogInvioEmail(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic> email, String titolo, String oggettoTemplate, String testoTemplate) {
    String personalizza(String testo) {
      return testo
        .replaceAll('[NOME_CLIENTE]', datiCliente['nome'] ?? '')
        .replaceAll('[COGNOME_CLIENTE]', datiCliente['cognome'] ?? '')
        .replaceAll('[CODICE_CLIENTE]', datiCliente['codice'] ?? '')
        .replaceAll('[VIA_CLIENTE]', datiCliente['via'] ?? '')
        .replaceAll('[CITTA_CLIENTE]', datiCliente['citta'] ?? '');
    }

    final oggettoCtrl = TextEditingController(text: personalizza(oggettoTemplate));
    final testoCtrl = TextEditingController(text: personalizza(testoTemplate));

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titolo),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: oggettoCtrl, decoration: const InputDecoration(labelText: "Oggetto")),
              const SizedBox(height: 15),
              TextField(controller: testoCtrl, maxLines: 8, decoration: const InputDecoration(labelText: "Corpo del messaggio", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Apri e Invia"),
            onPressed: () {
              _inviaTramiteMailto(email['email'], oggettoCtrl.text, testoCtrl.text);
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _inviaTramiteMailto(String emailDestinatario, String oggetto, String corpo) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: emailDestinatario,
      query: 'subject=${Uri.encodeComponent(oggetto)}&body=${Uri.encodeComponent(corpo)}',
    );
    _faiAzione(emailLaunchUri);
  }

  void _confermaEliminazione(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina Cliente"),
        content: const Text("Sei sicuro? L'operazione non è reversibile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clienti').doc(id).delete();
              if (mounted) Navigator.of(context).pop(); // Chiude il dialog
              if (mounted) Navigator.of(context).pop(); // Chiude la scheda cliente
            },
            child: const Text("ELIMINA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // INIZIO BLOCCO 11: FUNZIONI DI SUPPORTO UI (FONT SCURO E BOTTONI TONDI)
  // -------------------------------------------------------------------------
  Widget _input(TextEditingController c, String l, IconData i, {bool abilitato = true, TextCapitalization textCapitalization = TextCapitalization.none, Function(String)? onChanged, FocusNode? focusNode, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: key,
          controller: c,
          textCapitalization: textCapitalization,
          enabled: abilitato,
          focusNode: focusNode,
          onChanged: onChanged,
          style: TextStyle(
            color: Colors.black87, 
            fontWeight: abilitato ? FontWeight.normal : FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: l,
            labelStyle: const TextStyle(color: Colors.blueGrey),
            prefixIcon: Icon(i, color: Colors.blue),
            border: const OutlineInputBorder(),
            filled: !abilitato,
            fillColor: abilitato ? Colors.transparent : Colors.grey[100],
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      );

  Widget _btnTondo(IconData i, Color c, VoidCallback a) => CircleAvatar(
        backgroundColor: c,
        child: IconButton(icon: Icon(i, color: Colors.white), onPressed: a),
      );

  // Bottone tondo "passivo", solo per visualizzazione, da usare dentro i PopupMenuButton
  Widget _btnTondoIcona(IconData i, Color c) => CircleAvatar(
        backgroundColor: c,
        child: Icon(i, color: Colors.white),
      );
  // -------------------------------------------------------------------------
  // FINE BLOCCO 11
  // -------------------------------------------------------------------------
}

// Estensione per singolarizzare una stringa (semplice)
extension StringExtension on String {
  String singularize() {
    if (endsWith('i')) return substring(0, length - 1);
    return this;
  }
}

// =======================================================================
// WIDGET INTERNO PER IL MODULO CLIENTE (RIUTILIZZABILE)
// =======================================================================
class _ModuloCliente extends StatefulWidget {
  final Map<String, dynamic>? dati;
  final String? idDocumento;
  final String googleApiKey;
  final Map<String, dynamic> configIntegrazioni;
  final List<Map<String, dynamic>> messaggiWhatsapp;
  final List<Map<String, dynamic>> messaggiEmail;

  // Funzioni passate come parametri per un accesso sicuro
  final Future<void> Function(Uri) onFaiAzione;
  final Future<String> Function() onGeneraCodiceCliente;
  final Future<List<Map<String, dynamic>>> Function(String) onGetSuggestions;
  final Future<Map<String, String>> Function(String) onGetPlaceDetails;
  final void Function(BuildContext, String) onConfermaEliminazione;
  final Future<void> Function(String, String) onInviaTramiteTwilio;
  final Future<void> Function(String, String, String) onInviaTramiteMailto;


  const _ModuloCliente({this.dati, this.idDocumento, required this.googleApiKey, required this.onFaiAzione, required this.onGeneraCodiceCliente, required this.onGetSuggestions, required this.onGetPlaceDetails, required this.onConfermaEliminazione, required this.onInviaTramiteTwilio, required this.onInviaTramiteMailto, required this.configIntegrazioni, required this.messaggiWhatsapp, required this.messaggiEmail});

  @override
  __ModuloClienteState createState() => __ModuloClienteState();
}

class __ModuloClienteState extends State<_ModuloCliente> {
  // Stato locale del modulo
  late bool siPuoModificare;
  late List<Map<String, dynamic>> telefoni, emails, indirizzi;
  late Map<String, dynamic>? telefonoAttivo, emailAttiva, indirizzoAttivo;
  late TextEditingController nomeController, cognomeController, cfController, pivaController, tagController;

  @override
  void initState() {
    super.initState();
    siPuoModificare = widget.idDocumento == null;
    final dati = widget.dati;

    telefoni = dati?['telefoni'] != null ? List<Map<String, dynamic>>.from(dati!['telefoni']) : (dati?['tel'] != null ? [{'label': 'telefono cliente', 'numero': dati!['tel']}] : []);
    emails = dati?['emails'] != null ? List<Map<String, dynamic>>.from(dati!['emails']) : (dati?['mail'] != null ? [{'label': 'email principale', 'email': dati!['mail']}] : []);
    indirizzi = dati?['indirizzi'] != null ? List<Map<String, dynamic>>.from(dati!['indirizzi']) : (dati?['via'] != null ? [{'label': 'indirizzo intervento', 'via': dati!['via'], 'citta': dati!['citta'] ?? '', 'cap': dati!['cap'] ?? ''}] : []);

    telefonoAttivo = telefoni.isNotEmpty ? telefoni.first : null;
    emailAttiva = emails.isNotEmpty ? emails.first : null;
    indirizzoAttivo = indirizzi.isNotEmpty ? indirizzi.first : null;

    nomeController = TextEditingController(text: dati?['nome']);
    cognomeController = TextEditingController(text: dati?['cognome']);
    cfController = TextEditingController(text: dati?['cf']);
    pivaController = TextEditingController(text: dati?['piva']);
    tagController = TextEditingController(text: dati?['tag']);

    if (widget.idDocumento == null) {
      if (telefoni.isEmpty) telefoni.add({'label': 'telefono cliente', 'numero': ''});
      if (emails.isEmpty) emails.add({'label': 'email principale', 'email': ''});
      if (indirizzi.isEmpty) indirizzi.add({'label': 'indirizzo intervento', 'via': '', 'citta': '', 'cap': ''});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.idDocumento == null ? "NUOVO CLIENTE" : "SCHEDA CLIENTE", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (widget.idDocumento != null)
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: siPuoModificare ? Colors.blue : Colors.black54, size: 26),
                        onPressed: () {
                          if (!siPuoModificare) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Abilita Modifica"),
                                content: const Text("Vuoi sbloccare i campi per modificare i dati del cliente?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ANNULLA")),
                                  TextButton(
                                    onPressed: () {
                                      setState(() => siPuoModificare = true);
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text("SÌ, MODIFICA"),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
                        onPressed: () => widget.onConfermaEliminazione(context, widget.idDocumento!),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 15),
            if (widget.idDocumento != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btnTondo(Icons.phone, Colors.green, () {
                    final numero = telefonoAttivo?['numero'] as String? ?? '';
                    final voipUrl = widget.configIntegrazioni['voispeed_url'] as String? ?? '';
                    if (numero.isNotEmpty && voipUrl.isNotEmpty) widget.onFaiAzione(Uri.parse('$voipUrl$numero'));
                  }),
                  _menuMessaggi(context, widget.dati ?? {}, telefonoAttivo),
                  _menuEmail(context, widget.dati ?? {}, emailAttiva),
                  _btnTondo(Icons.directions, Colors.blue, () {
                    final address = "${indirizzoAttivo?['via'] ?? ''}, ${indirizzoAttivo?['citta'] ?? ''}";
                    widget.onFaiAzione(Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}"));
                  }),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.history), label: Text("VEDI STORICO INTERVENTI (Cod: ${widget.dati?['codice'] ?? ''})")),
              ),
              const Divider(height: 30),
            ],
            _input(cognomeController, "Cognome", Icons.person_outline, abilitato: siPuoModificare, textCapitalization: TextCapitalization.characters),
            _input(nomeController, "Nome", Icons.person, abilitato: siPuoModificare, textCapitalization: TextCapitalization.characters),
            _buildSezioneDinamica("Telefoni", telefoni, 'numero', Icons.phone, siPuoModificare, setState, context),
            _buildSezioneDinamica("Email", emails, 'email', Icons.email, siPuoModificare, setState, context),
            _buildSezioneIndirizzi("Indirizzi", indirizzi, siPuoModificare, setState, context),
            if (!siPuoModificare) ...[
              _buildSelettoreAttivo("Telefono attivo", telefonoAttivo, telefoni, Icons.phone, (newValue) => setState(() => telefonoAttivo = newValue)),
              _buildSelettoreAttivo("Email attiva", emailAttiva, emails, Icons.email, (newValue) => setState(() => emailAttiva = newValue)),
              _buildSelettoreAttivo("Indirizzo attivo", indirizzoAttivo, indirizzi, Icons.location_on, (newValue) => setState(() => indirizzoAttivo = newValue)),
            ],
            Row(
              children: [
                Expanded(child: _input(cfController, "Codice Fiscale", Icons.badge, abilitato: siPuoModificare, textCapitalization: TextCapitalization.characters)),
                const SizedBox(width: 10),
                Expanded(child: _input(pivaController, "Partita IVA", Icons.business, abilitato: siPuoModificare)),
              ],
            ),
            const SizedBox(height: 10),
            _input(tagController, "Tag", Icons.tag, abilitato: siPuoModificare),
            if (siPuoModificare) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    if (widget.idDocumento == null) Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA"))),
                    if (widget.idDocumento == null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                        onPressed: () async {
                          String finalCode = widget.dati?['codice'] ?? await widget.onGeneraCodiceCliente();
                          final map = {
                            'codice': finalCode, 'nome': nomeController.text, 'cognome': cognomeController.text,
                            'cognome_lowercase': cognomeController.text.toLowerCase(),
                            'telefoni': telefoni, 'emails': emails, 'indirizzi': indirizzi,
                            'cf': cfController.text, 'piva': pivaController.text, 'tag': tagController.text,
                            'ultima_modifica': FieldValue.serverTimestamp(),
                            if (widget.idDocumento == null) 'data_creazione': FieldValue.serverTimestamp(),
                          };
                          if (cognomeController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Il cognome è un campo obbligatorio.")));
                            return;
                          }
                          try {
                            if (widget.idDocumento == null) {
                              await FirebaseFirestore.instance.collection('clienti').add(map);
                            } else {
                              await FirebaseFirestore.instance.collection('clienti').doc(widget.idDocumento).set(map, SetOptions(merge: true));
                            }
                            if (mounted) Navigator.of(context).pop(widget.idDocumento == null ? map : null);
                          } catch (e) { debugPrint("Errore Idrocostruzioni: $e"); }
                        },
                        child: Text(widget.idDocumento == null ? "SALVA CLIENTE" : "CONFERMA MODIFICHE"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS PER SEZIONI DINAMICHE (COPIATI DA _ClientiPageState) ---

  Widget _input(TextEditingController c, String l, IconData i, {bool abilitato = true, TextCapitalization textCapitalization = TextCapitalization.none, Function(String)? onChanged, FocusNode? focusNode, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: key,
          controller: c,
          textCapitalization: textCapitalization,
          enabled: abilitato,
          focusNode: focusNode,
          onChanged: onChanged,
          style: TextStyle(
            color: Colors.black87, 
            fontWeight: abilitato ? FontWeight.normal : FontWeight.w500,
          ),
          decoration: InputDecoration(
            labelText: l,
            labelStyle: const TextStyle(color: Colors.blueGrey),
            prefixIcon: Icon(i, color: Colors.blue),
            border: const OutlineInputBorder(),
            filled: !abilitato,
            fillColor: abilitato ? Colors.transparent : Colors.grey[100],
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
      );

  Widget _buildSezioneDinamica(String titolo, List<Map<String, dynamic>> lista, String chiaveValore, IconData icona, bool abilitato, StateSetter setModalState, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (abilitato) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () => setModalState(() => lista.add({'label': '', chiaveValore: ''})),
              ),
            ],
          ),
          ...lista.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> item = entry.value;
            return Row(
              children: [
                Expanded(flex: 2, child: _input(TextEditingController(text: item['label']), "Etichetta", Icons.label_outline, abilitato: abilitato, onChanged: (val) => item['label'] = val)),
                const SizedBox(width: 8),
                Expanded(flex: 3, child: _input(TextEditingController(text: item[chiaveValore]), "Valore", icona, abilitato: abilitato, onChanged: (val) => item[chiaveValore] = val)),
                if (lista.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setModalState(() => lista.removeAt(idx))),
              ],
            );
          }),
        ]
      ],
    );
  }

  Widget _buildSelettoreAttivo(String titolo, Map<String, dynamic>? valoreAttivo, List<Map<String, dynamic>> lista, IconData icona, Function(Map<String, dynamic>?) onChanged) {
    if (lista.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10), // FIX: 'value' is deprecated.
      child: DropdownButtonFormField<Map<String, dynamic>>(
        value: valoreAttivo,
        isExpanded: true, // FIX: Previene l'overflow con testi lunghi
        decoration: InputDecoration(labelText: titolo, prefixIcon: Icon(icona), border: const OutlineInputBorder()),
        items: lista.map((item) => DropdownMenuItem(
          value: item,
          child: Tooltip(
            message: _getDropdownText(item),
            child: Text(
              _getDropdownText(item),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          )
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  String _getDropdownText(Map<String, dynamic> item) {
    final label = item['label'] ?? '';
    if (item.containsKey('numero')) return "$label: ${item['numero'] ?? ''}";
    if (item.containsKey('email')) return "$label: ${item['email'] ?? ''}";
    if (item.containsKey('via')) return "$label: ${item['via']}";
    final value = item.values.length > 1 ? item.values.elementAt(1) : '';
    return "$label: $value";
  }

  // --- LOGICA MESSAGGISTICA (COPIATA DA _ClientiPageState) ---

  Widget _menuMessaggi(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic>? telefonoAttivo) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (telefonoAttivo == null) return;
        if (value == 'custom') {
          _dialogInvioMessaggio(context, datiCliente, telefonoAttivo, "Messaggio Personalizzato", "");
        } else {
          final template = widget.messaggiWhatsapp.firstWhere((m) => m['titolo'] == value);
          _dialogInvioMessaggio(context, datiCliente, telefonoAttivo, template['titolo'], template['testo']);
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];
        items.addAll(widget.messaggiWhatsapp.map((msg) => PopupMenuItem<String>(
          value: msg['titolo'],
          child: Text(msg['titolo']),
        )));
        if (items.isNotEmpty) items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem<String>(value: 'custom', child: Text("Messaggio personalizzato...")));
        return items;
      },
      child: _btnTondoIcona(Icons.chat, Colors.teal),
    );
  }

  void _dialogInvioMessaggio(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic> telefono, String titolo, String testoTemplate) {
    String testoPersonalizzato = testoTemplate.replaceAll('[NOME_CLIENTE]',
        (datiCliente['nome'] as String?) ?? '').replaceAll('[COGNOME_CLIENTE]',
        (datiCliente['cognome'] as String?) ?? '').replaceAll('[CODICE_CLIENTE]',
        (datiCliente['codice'] as String?) ?? '').replaceAll('[VIA_CLIENTE]',
        (datiCliente['via'] as String?) ?? '').replaceAll('[CITTA_CLIENTE]',
        (datiCliente['citta'] as String?) ?? '');

    final testoCtrl = TextEditingController(text: testoPersonalizzato);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titolo),
        content: TextField(controller: testoCtrl, maxLines: 6, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Invia via WhatsApp"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              widget.onInviaTramiteTwilio(telefono['numero'], testoCtrl.text);
              Navigator.pop(c);
            },
          ),
        ],
      ),
    );
  }

  Widget _menuEmail(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic>? emailAttiva) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (emailAttiva == null) return;
        if (value == 'custom') {
          _dialogInvioEmail(context, datiCliente, emailAttiva, "Email Personalizzata", "", "");
        } else {
          final template = widget.messaggiEmail.firstWhere((m) => m['titolo'] == value);
          _dialogInvioEmail(context, datiCliente, emailAttiva, template['titolo'], template['oggetto'], template['testo']);
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [];
        items.addAll(widget.messaggiEmail.map((msg) => PopupMenuItem<String>(value: msg['titolo'], child: Text(msg['titolo']))));
        if (items.isNotEmpty) items.add(const PopupMenuDivider());
        items.add(const PopupMenuItem<String>(value: 'custom', child: Text("Email personalizzata...")));
        return items;
      },
      child: _btnTondoIcona(Icons.email, Colors.redAccent),
    );
  }

  void _dialogInvioEmail(BuildContext context, Map<String, dynamic> datiCliente, Map<String, dynamic> email, String titolo, String oggettoTemplate, String testoTemplate) {
    String personalizza(String testo) => testo.replaceAll('[NOME_CLIENTE]', (datiCliente['nome'] as String?) ?? '').replaceAll('[COGNOME_CLIENTE]', (datiCliente['cognome'] as String?) ?? '').replaceAll('[CODICE_CLIENTE]', (datiCliente['codice'] as String?) ?? '').replaceAll('[VIA_CLIENTE]', (datiCliente['via'] as String?) ?? '').replaceAll('[CITTA_CLIENTE]', (datiCliente['citta'] as String?) ?? '');
    final oggettoCtrl = TextEditingController(text: personalizza(oggettoTemplate));
    final testoCtrl = TextEditingController(text: personalizza(testoTemplate));
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(titolo), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: oggettoCtrl, decoration: const InputDecoration(labelText: "Oggetto")), const SizedBox(height: 15), TextField(controller: testoCtrl, maxLines: 8, decoration: const InputDecoration(labelText: "Corpo del messaggio", border: OutlineInputBorder()))])), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")), ElevatedButton.icon(icon: const Icon(Icons.send), label: const Text("Apri e Invia"), onPressed: () {widget.onInviaTramiteMailto(email['email'], oggettoCtrl.text, testoCtrl.text); Navigator.pop(c);})]));
  }

  // Metodo specifico per questa classe
  Widget _buildSezioneIndirizzi(String titolo, List<Map<String, dynamic>> lista, bool abilitato, StateSetter setModalState, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (abilitato) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => setModalState(() => lista.add({'label': '', 'via': '', 'citta': '', 'cap': ''}))),
            ],
          ),
          ...lista.asMap().entries.map((entry) {
            int idx = entry.key;
            Map<String, dynamic> item = entry.value;
            return Card(
              elevation: 1, margin: const EdgeInsets.symmetric(vertical: 5),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _input(TextEditingController(text: item['label']), "Etichetta", Icons.label_outline, abilitato: abilitato, onChanged: (val) => item['label'] = val)),
                        if (lista.length > 1) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setModalState(() => lista.removeAt(idx))),
                      ],
                    ),
                    TypeAheadField<Map<String, dynamic>>(
                      builder: (context, controller, focusNode) {
                        controller.text = item['via'] ?? '';
                        return _input(controller, "Via e Civico", Icons.home, abilitato: abilitato, onChanged: (value) { if (focusNode.hasFocus) item['via'] = value; }, focusNode: focusNode);
                      },
                      suggestionsCallback: (pattern) => abilitato ? widget.onGetSuggestions(pattern) : Future.value(<Map<String, dynamic>>[]),
                      onSelected: (suggestion) async {
                        final placeId = suggestion['place_id'];
                        if (placeId != null) {
                          final details = await widget.onGetPlaceDetails(placeId);
                          setModalState(() {
                            item['via'] = details['via'] ?? '';
                            item['citta'] = details['citta'] ?? '';
                            item['cap'] = details['cap'] ?? '';
                          });
                        }
                      },
                      itemBuilder: (context, suggestion) => ListTile(title: Text(suggestion['description'])),
                      emptyBuilder: (context) => const SizedBox.shrink(),
                    ),
                    Row(
                      children: [
                        Expanded(child: _input(TextEditingController(text: item['cap']), "CAP", Icons.map_outlined, abilitato: abilitato, onChanged: (val) => item['cap'] = val, key: ValueKey("cap_$idx\_${item['cap']}"))),
                        const SizedBox(width: 8),
                        Expanded(child: _input(TextEditingController(text: item['citta']), "Città", Icons.location_city, abilitato: abilitato, onChanged: (val) => item['citta'] = val, key: ValueKey("citta_$idx\_${item['citta']}"))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ]
      ],
    );
  }

  Widget _btnTondo(IconData i, Color c, VoidCallback a) => CircleAvatar(
        backgroundColor: c,
        child: IconButton(icon: Icon(i, color: Colors.white), onPressed: a),
      );

  Widget _btnTondoIcona(IconData i, Color c) => CircleAvatar(
        backgroundColor: c,
        child: Icon(i, color: Colors.white),
      );
}