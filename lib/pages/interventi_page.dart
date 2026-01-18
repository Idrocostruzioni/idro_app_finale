import 'package:flutter/material.dart';

// Questa è la pagina della lista degli interventi
class ListaInterventiPage extends StatelessWidget {
  const ListaInterventiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Lista Interventi"), backgroundColor: Colors.green),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedaIntervento())),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.build, color: Colors.green),
            title: const Text("Intervento Esempio"),
            subtitle: const Text("Oggi - Ore 10:00"),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedaIntervento())),
          ),
        ],
      ),
    );
  }
}

// Questa è la SCHEDA DETTAGLIATA che mancava o dava errore
class SchedaIntervento extends StatefulWidget {
  const SchedaIntervento({super.key});

  @override
  State<SchedaIntervento> createState() => _SchedaInterventoState();
}

class _SchedaInterventoState extends State<SchedaIntervento> {
  TimeOfDay oraInizio = const TimeOfDay(hour: 08, minute: 30);
  TimeOfDay oraFine = const TimeOfDay(hour: 10, minute: 30);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dettaglio Intervento")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // SEZIONE ORARIO
          const Text("PROGRAMMAZIONE ORARIA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: const Text("Inizio"),
                  subtitle: Text(oraInizio.format(context)),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: oraInizio);
                    if (picked != null) setState(() => oraInizio = picked);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  title: const Text("Fine"),
                  subtitle: Text(oraFine.format(context)),
                  leading: const Icon(Icons.access_time_filled),
                  onTap: () async {
                    TimeOfDay? picked = await showTimePicker(context: context, initialTime: oraFine);
                    if (picked != null) setState(() => oraFine = picked);
                  },
                ),
              ),
            ],
          ),
          const Divider(),
          
          // CAMPI TIPOLOGIA E DESCRIZIONE
          const SizedBox(height: 10),
          const TextField(decoration: InputDecoration(labelText: "Tipologia Intervento", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          const TextField(decoration: InputDecoration(labelText: "Cliente", border: OutlineInputBorder())),
          const SizedBox(height: 15),
          const TextField(maxLines: 3, decoration: InputDecoration(labelText: "Note Tecniche / Descrizione", border: OutlineInputBorder())),
          
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
            icon: const Icon(Icons.save),
            label: const Text("SALVA INTERVENTO"),
          ),
        ],
      ),
    );
  }
}