import 'package:flutter/material.dart';
import '../widgets/main_drawer.dart';
import 'staff_page.dart'; // Assicurati che il nome del file sia corretto

class ImpostazioniPage extends StatefulWidget {
  const ImpostazioniPage({super.key});

  @override
  State<ImpostazioniPage> createState() => _ImpostazioniPageState();
}

class _ImpostazioniPageState extends State<ImpostazioniPage> {
  // Liste temporanee (saranno poi lette da Firebase)
  List<String> tipologie = ["Installazione Caldaia", "Sopralluogo Clima", "Riparazione", "Manutenzione"];
  List<String> tags = ["Clima", "Caldaia", "Boiler", "Pronto Intervento"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Impostazioni Gestionale"),
        backgroundColor: Colors.blue[100],
        elevation: 0,
      ),
      drawer: const MainDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // SEZIONE STAFF (Sbloccata e collegata)
          const Text("Organizzazione Staff", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 10),
          Card(
            elevation: 2,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.people, color: Colors.white),
              ),
              title: const Text("Gestione Staff e Operatori"),
              subtitle: const Text("Modifica colori, foto e permessi di Luciano, Luca e Mirko"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Navigazione verso la pagina Staff che abbiamo creato
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StaffPage()),
                );
              },
            ),
          ),

          const Divider(height: 50),

          // SEZIONE TIPOLOGIE
          _sezioneLista("Tipologie Intervento", tipologie, Icons.assignment_outlined),
          
          const Divider(height: 50),

          // SEZIONE TAG
          _sezioneLista("Tag Intervento", tags, Icons.sell_outlined),
          
          const SizedBox(height: 40),
          
          // INFO VERSIONE
          const Center(
            child: Text("Idrocostruzioni App v 1.0.2", 
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          )
        ],
      ),
    );
  }

  // Widget riutilizzabile per le liste (Tipologie e Tag)
  Widget _sezioneLista(String titolo, List<String> lista, IconData icona) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icona, color: Colors.blue[900]),
            const SizedBox(width: 10),
            Text(titolo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ...lista.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {
                // Logica per eliminare (da implementare con Firebase)
                setState(() {
                  lista.remove(item);
                });
              },
            ),
          ),
        )),
        TextButton.icon(
          onPressed: () => _mostraDialogAggiungi(titolo, lista),
          icon: const Icon(Icons.add),
          label: Text("Aggiungi nuova voce a $titolo"),
        ),
      ],
    );
  }

  // Finestra di dialogo per aggiungere nuove voci
  void _mostraDialogAggiungi(String titolo, List<String> lista) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Aggiungi $titolo"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Esempio: Installazione Clima"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annulla")),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  lista.add(controller.text);
                });
                Navigator.pop(context);
              }
            },
            child: const Text("Salva"),
          ),
        ],
      ),
    );
  }
}