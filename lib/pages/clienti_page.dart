import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/main_drawer.dart';

class ClientiPage extends StatefulWidget {
  const ClientiPage({super.key});

  @override
  State<ClientiPage> createState() => _ClientiPageState();
}

class _ClientiPageState extends State<ClientiPage> {
  String queryRicerca = "";

  Future<void> _faiAzione(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anagrafica Clienti"),
        backgroundColor: Colors.blue[100],
        // ---------------------------------------------------------
        // BARRA DI RICERCA SUPERIORE
        // ---------------------------------------------------------
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (val) => setState(() => queryRicerca = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Cerca nome, tel o mail...",
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        // ---------------------------------------------------------
      ),
      
      drawer: const MainDrawer(),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostraModulo(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),

      // ---------------------------------------------------------
      // LISTA CLIENTI DAL DATABASE
      // ---------------------------------------------------------
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clienti').orderBy('nome').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Errore di connessione"));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nome = (data['nome'] ?? "").toString().toLowerCase();
            final tel = (data['tel'] ?? "").toString().toLowerCase();
            return nome.contains(queryRicerca) || tel.contains(queryRicerca);
          }).toList();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final idDoc = docs[index].id;
              final cliente = docs[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(cliente['nome'] ?? "Senza nome", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Cod: ${cliente['codice'] ?? '-'} | ${cliente['tel'] ?? ''}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _mostraModulo(context, dati: cliente, idDocumento: idDoc),
                ),
              );
            },
          );
        },
      ),
      // ---------------------------------------------------------
    );
  }

  void _mostraModulo(BuildContext context, {Map<String, dynamic>? dati, String? idDocumento}) {
    final codController = TextEditingController(text: dati?['codice']);
    final nomeController = TextEditingController(text: dati?['nome']);
    final telController = TextEditingController(text: dati?['tel']);
    final mailController = TextEditingController(text: dati?['mail']);
    final cittaController = TextEditingController(text: dati?['citta']);
    final cfController = TextEditingController(text: dati?['cf']);
    final tagController = TextEditingController(text: dati?['tag']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(idDocumento == null ? "NUOVO CLIENTE" : "SCHEDA CLIENTE", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  
                  // ---------------------------------------------------------
                  // BOTTONE ELIMINA CLIENTE
                  // ---------------------------------------------------------
                  if (idDocumento != null)
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _confermaEliminazione(context, idDocumento),
                    )
                  // ---------------------------------------------------------
                ],
              ),
              const SizedBox(height: 15),
              
              if (idDocumento != null) ...[
                // ---------------------------------------------------------
                // BLOCCO BOTTONI AZIONE (CHIAMA, WHATSAPP, MAIL, MAPPE)
                // ---------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _btnTondo(Icons.phone, Colors.green, () => _faiAzione(Uri(scheme: 'tel', path: dati?['tel']))),
                    _btnTondo(Icons.chat, Colors.teal, () => _faiAzione(Uri.parse("https://wa.me/${dati?['tel']}"))),
                    _btnTondo(Icons.email, Colors.redAccent, () => _faiAzione(Uri(scheme: 'mailto', path: dati?['mail']))),
                    _btnTondo(Icons.directions, Colors.blue, () {
                      final indirizzo = Uri.encodeComponent(dati?['citta'] ?? '');
                      _faiAzione(Uri.parse("https://www.google.com/maps/search/?api=1&query=$indirizzo"));
                    }),
                  ],
                ),
                // ---------------------------------------------------------

                const SizedBox(height: 15),

                // ---------------------------------------------------------
                // BOTTONE VEDI STORICO INTERVENTI
                // ---------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {}, 
                    icon: const Icon(Icons.history), 
                    label: const Text("VEDI STORICO INTERVENTI")
                  ),
                ),
                // ---------------------------------------------------------

                const Divider(height: 30),
              ],

              // ---------------------------------------------------------
              // CAMPI DI TESTO (INPUT DATI)
              // ---------------------------------------------------------
              _input(codController, "Codice Cliente", Icons.numbers),
              _input(nomeController, "Nome e Cognome", Icons.person),
              _input(telController, "Telefono", Icons.phone),
              _input(mailController, "Email", Icons.email),
              _input(cittaController, "Indirizzo", Icons.location_on),
              Row(
                children: [
                  Expanded(child: _input(cfController, "Cod. Fiscale", Icons.badge)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(tagController, "Tag", Icons.tag)),
                ],
              ),
              // ---------------------------------------------------------

              const SizedBox(height: 20),
              
              // ---------------------------------------------------------
              // BOTTONE SALVA/MODIFICA SU FIREBASE
              // ---------------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                  onPressed: () async {
                    final map = {
                      'codice': codController.text,
                      'nome': nomeController.text,
                      'tel': telController.text,
                      'mail': mailController.text,
                      'citta': cittaController.text,
                      'cf': cfController.text,
                      'tag': tagController.text,
                      'ultima_modifica': FieldValue.serverTimestamp(),
                      if (idDocumento == null) 'data_creazione': FieldValue.serverTimestamp(),
                    };

                    if (idDocumento == null) {
                      await FirebaseFirestore.instance.collection('clienti').add(map);
                    } else {
                      await FirebaseFirestore.instance.collection('clienti').doc(idDocumento).update(map);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(idDocumento == null ? "SALVA CLIENTE" : "MODIFICA CLIENTE"),
                ),
              ),
              // ---------------------------------------------------------
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _confermaEliminazione(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Elimina Cliente"),
        content: const Text("Sei sicuro di voler eliminare questo cliente? L'operazione non è reversibile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clienti').doc(id).delete();
              Navigator.pop(context); 
              Navigator.pop(context); 
            },
            child: const Text("ELIMINA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _btnTondo(IconData i, Color c, VoidCallback a) => CircleAvatar(backgroundColor: c, child: IconButton(icon: Icon(i, color: Colors.white), onPressed: a));
  Widget _input(TextEditingController c, String l, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder())),
  );
}