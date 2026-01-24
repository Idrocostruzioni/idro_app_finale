import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../widgets/main_drawer.dart';
import 'staff_page.dart';

class ImpostazioniPage extends StatefulWidget {
  const ImpostazioniPage({super.key});

  @override
  State<ImpostazioniPage> createState() => _ImpostazioniPageState();
}

class _ImpostazioniPageState extends State<ImpostazioniPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Funzione per salvare le impostazioni delle commesse (stati, tipi, tag)
  Future<void> _salvaImpostazioniCommesse(String campo, dynamic valore) async {
    try {
      await _db.collection('impostazioni').doc('commesse').set({
        campo: valore,
      }, SetOptions(merge: true));
    } catch (e) {
      _mostraErrore(e);
    }
  }

  // Funzione per salvare le configurazioni delle integrazioni (API Keys, etc.)
  Future<void> _salvaConfigIntegrazioni(String campo, dynamic valore) async {
    try {
      await _db.collection('impostazioni').doc('config').set({
        campo: valore,
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configurazione salvata.")));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore durante il salvataggio: $e")),
        );
      }
    }
  }

  void _mostraErrore(dynamic e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Errore durante il salvataggio: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impostazioni e Staff"),
        backgroundColor: Colors.blue[100],
        elevation: 0,
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('impostazioni').doc('commesse').snapshots(),
        builder: (context, commesseSnapshot) {
          return StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('impostazioni').doc('config').snapshots(),
            builder: (context, configSnapshot) {
              if (commesseSnapshot.connectionState == ConnectionState.waiting ||
                  configSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (commesseSnapshot.hasError || configSnapshot.hasError) {
                return Center(child: Text("Errore di connessione: ${commesseSnapshot.error ?? configSnapshot.error}", textAlign: TextAlign.center));
              }

              var dataCommesse = commesseSnapshot.hasData && commesseSnapshot.data!.exists
                  ? commesseSnapshot.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};
              var dataConfig = configSnapshot.hasData && configSnapshot.data!.exists
                  ? configSnapshot.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

              // Caricamento liste con gestione dei null per evitare errori di tipo
              List<Map<String, dynamic>> stati = List<Map<String, dynamic>>.from(dataCommesse['stati'] ?? []);
              List<String> tipologie = List<String>.from(dataCommesse['tipologie'] ?? []);
              List<String> tags = List<String>.from(dataCommesse['tags'] ?? []);
              List<Map<String, dynamic>> messaggiWhatsapp = List<Map<String, dynamic>>.from(dataConfig['messaggi_preimpostati'] ?? []);
              List<Map<String, dynamic>> messaggiEmail = List<Map<String, dynamic>>.from(dataConfig['email_preimpostate'] ?? []);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- SEZIONE STAFF ---
                  const Text("Organizzazione Staff", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue, 
                        child: Icon(Icons.people, color: Colors.white)
                      ),
                      title: const Text("Gestione Staff e Operatori"),
                      subtitle: const Text("Modifica colori e nomi di Luciano, Luca e Mirko"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const StaffPage())
                      ),
                    ),
                  ),

                  const Divider(height: 40),

                  // --- SEZIONE INTEGRAZIONI ---
                  _buildTitoloSezione("Integrazioni API", Icons.hub_outlined),
                  _itemConfigurazione("VoiSpeed Click-to-Call", dataConfig['voispeed_url'] ?? "Non impostato", 
                    () => _dialogConfigSemplice("URL VoiSpeed", "voispeed_url", dataConfig['voispeed_url'])),
                  _itemConfigurazione("Twilio Account SID", dataConfig['twilio_sid'] ?? "Non impostato", 
                    () => _dialogConfigSemplice("Account SID Twilio", "twilio_sid", dataConfig['twilio_sid'])),
                  _itemConfigurazione("Twilio Auth Token", "******" , // Nascondiamo il token
                    () => _dialogConfigSemplice("Auth Token Twilio", "twilio_token", "")),
                  _itemConfigurazione("Twilio WhatsApp Number", dataConfig['twilio_from_number'] ?? "Non impostato", 
                    () => _dialogConfigSemplice("Numero WhatsApp Twilio", "twilio_from_number", dataConfig['twilio_from_number'])),
                  _itemConfigurazione("Email per invio (Gmail)", dataConfig['gmail_user'] ?? "Non impostato",
                    () => _dialogConfigSemplice("Email per invio (Gmail)", "gmail_user", dataConfig['gmail_user'])),


                  const Divider(height: 40),

                  // --- SEZIONE STATI (CON COLORE) ---
                  _buildTitoloSezione("Stati Avanzamento Commessa", Icons.flag_circle_outlined),
                  if (stati.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text("Nessun colore/stato configurato", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ...stati.map((s) => _itemListaConfig(
                    label: s['nome'] ?? "Senza nome",
                    leading: CircleAvatar(
                      backgroundColor: Color(s['colore'] is int ? s['colore'] : Colors.grey.value), 
                      radius: 12
                    ),
                    onDelete: () {
                      stati.remove(s);
                      _salvaImpostazioniCommesse('stati', stati);
                    },
                  )),
                  _btnAggiungi("Aggiungi nuovo Stato", () => _dialogStato(stati)),

                  const Divider(height: 40),

                  // --- SEZIONE TIPOLOGIE ---
                  _buildTitoloSezione("Tipologie Intervento", Icons.assignment_outlined),
                  ...tipologie.map((t) => _itemListaConfig(
                    label: t,
                    onDelete: () {
                      tipologie.remove(t);
                      _salvaImpostazioniCommesse('tipologie', tipologie);
                    },
                  )),
                  _btnAggiungi("Aggiungi nuova Tipologia", () => _dialogSemplice("Tipologia", tipologie, 'tipologie', _salvaImpostazioniCommesse)),

                  const Divider(height: 40),

                  // --- SEZIONE MESSAGGI PREIMPOSTATI ---
                  _buildTitoloSezione("Modelli Messaggi WhatsApp", Icons.chat_bubble_outline),
                  ...messaggiWhatsapp.map((m) => _itemListaConfig(
                    label: m['titolo'] ?? "Senza titolo",
                    onDelete: () {
                      messaggiWhatsapp.remove(m);
                      _salvaConfigIntegrazioni('messaggi_preimpostati', messaggiWhatsapp);
                    },
                  )),
                  _btnAggiungi("Crea Modello WhatsApp", () => _dialogMessaggio(messaggiWhatsapp, 'messaggi_preimpostati', "WhatsApp")),

                  const Divider(height: 40),

                  // --- SEZIONE EMAIL PREIMPOSTATE ---
                  _buildTitoloSezione("Modelli Email", Icons.email_outlined),
                  ...messaggiEmail.map((m) => _itemListaConfig(
                    label: m['titolo'] ?? "Senza titolo",
                    onDelete: () {
                      messaggiEmail.remove(m);
                      _salvaConfigIntegrazioni('email_preimpostate', messaggiEmail);
                    },
                  )),
                  _btnAggiungi("Crea Modello Email", () => _dialogMessaggio(messaggiEmail, 'email_preimpostate', "Email")),

                  const Divider(height: 40),

                  // --- SEZIONE TAG ---
                  _buildTitoloSezione("Tag Intervento", Icons.sell_outlined),
                  ...tags.map((tag) => _itemListaConfig(
                    label: tag,
                    onDelete: () {
                      tags.remove(tag);
                      _salvaImpostazioniCommesse('tags', tags);
                    },
                  )),
                  _btnAggiungi("Aggiungi nuovo Tag", () => _dialogSemplice("Tag", tags, 'tags', _salvaImpostazioniCommesse)),

                  const SizedBox(height: 60),
                  const Center(
                    child: Text("Idrocostruzioni App v 1.0.4", 
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // --- HELPERS UI ---

  Widget _buildTitoloSezione(String titolo, IconData icona) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icona, color: Colors.blue[900]),
          const SizedBox(width: 10),
          Text(titolo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _itemListaConfig({required String label, Widget? leading, required VoidCallback onDelete}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: leading,
        title: Text(label),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red), 
          onPressed: onDelete
        ),
      ),
    );
  }

  Widget _itemConfigurazione(String titolo, String valore, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(titolo),
        subtitle: Text(valore, style: const TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.edit_note, color: Colors.blue),
        onTap: onTap,
      ),
    );
  }

  Widget _btnAggiungi(String label, VoidCallback onPressed) {
    return TextButton.icon(
      onPressed: onPressed, 
      icon: const Icon(Icons.add), 
      label: Text(label)
    );
  }

  // --- DIALOGS PER AGGIUNTA DATI ---

  void _dialogSemplice(String titolo, List<String> lista, String campoFirebase, Function(String, dynamic) onSave) {
    final ctrl = TextEditingController();
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: Text("Aggiungi $titolo"),
        content: TextField(
          controller: ctrl, 
          decoration: InputDecoration(hintText: "Inserisci $titolo"),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                lista.add(ctrl.text.trim());
                onSave(campoFirebase, lista);
                if (mounted) Navigator.pop(c);
              }
            }, 
            child: const Text("Salva")
          ),
        ],
      ),
    );
  }

  void _dialogConfigSemplice(String titolo, String campoFirebase, String? valoreIniziale) {
    final ctrl = TextEditingController(text: valoreIniziale);
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: Text("Imposta $titolo"),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: "Inserisci valore...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () {
              _salvaConfigIntegrazioni(campoFirebase, ctrl.text.trim());
              if (mounted) Navigator.pop(c);
            }, 
            child: const Text("Salva")
          ),
        ],
      ),
    );
  }

  void _dialogStato(List<Map<String, dynamic>> stati) {
    final ctrl = TextEditingController();
    Color coloreSelezionato = Colors.blue;
    showDialog(
      context: context, 
      builder: (c) => StatefulBuilder(
        builder: (ctx, setInternalState) => AlertDialog(
          title: const Text("Configura Nuovo Stato"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl, 
                  decoration: const InputDecoration(labelText: "Nome dello Stato"),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                const Text("Colore identificativo:", style: TextStyle(fontSize: 12)),
                const SizedBox(height: 10),
                BlockPicker(
                  pickerColor: coloreSelezionato, 
                  onColorChanged: (color) => setInternalState(() => coloreSelezionato = color)
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
            ElevatedButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  stati.add({
                    "nome": ctrl.text.trim(), 
                    "colore": coloreSelezionato.value
                  });
                  _salvaImpostazioniCommesse('stati', stati);
                  if (mounted) Navigator.pop(c);
                }
              }, 
              child: const Text("Salva")
            ),
          ],
        ),
      ),
    );
  }

  void _dialogMessaggio(List<Map<String, dynamic>> listaMessaggi, String campoFirebase, String tipo) {
    final titoloCtrl = TextEditingController();
    final testoCtrl = TextEditingController();
    final oggettoCtrl = TextEditingController(); // Solo per email
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: Text("Crea Modello $tipo"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: titoloCtrl, decoration: const InputDecoration(labelText: "Titolo (es. 'Sollecito Fattura')")),
              if (tipo == "Email") ...[const SizedBox(height: 15), TextField(controller: oggettoCtrl, decoration: const InputDecoration(labelText: "Oggetto dell'email"))],
              const SizedBox(height: 15),
              TextField(controller: testoCtrl, decoration: InputDecoration(labelText: "Testo del $tipo", border: const OutlineInputBorder()), maxLines: 5),
              const SizedBox(height: 15),
              const Text("Puoi usare questi segnaposto:", style: TextStyle(fontWeight: FontWeight.bold)),
              const Text("[NOME_CLIENTE], [COGNOME_CLIENTE], [CODICE_CLIENTE], [VIA_CLIENTE], [CITTA_CLIENTE]", style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () {
              if (titoloCtrl.text.trim().isNotEmpty && testoCtrl.text.trim().isNotEmpty) {
                final nuovoMessaggio = {
                  "titolo": titoloCtrl.text.trim(),
                  "testo": testoCtrl.text.trim(),
                  if (tipo == "Email") "oggetto": oggettoCtrl.text.trim(),
                };
                listaMessaggi.add(nuovoMessaggio);
                _salvaConfigIntegrazioni(campoFirebase, listaMessaggi);
                if (mounted) Navigator.pop(c);
              }
            }, 
            child: const Text("Salva Modello")
          ),
        ],
      ),
    );
  }
}