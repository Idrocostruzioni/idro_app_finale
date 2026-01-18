import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../widgets/main_drawer.dart';

class InterventiPage extends StatefulWidget {
  const InterventiPage({super.key});

  @override
  State<InterventiPage> createState() => _InterventiPageState();
}

class _InterventiPageState extends State<InterventiPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lista Interventi"),
        backgroundColor: Colors.blue[100],
      ),
      drawer: const MainDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        // ---------------------------------------------------------
        // CARICAMENTO TUTTI GLI INTERVENTI (Ordinati per data)
        // ---------------------------------------------------------
        stream: FirebaseFirestore.instance
            .collection('interventi')
            .orderBy('dataInizio', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              DateTime inizio = (data['dataInizio'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      children: [
                        Text(DateFormat('dd').format(inizio), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(DateFormat('MMM').format(inizio), style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                  title: Text(data['cliente'] ?? "Cliente ignoto", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['tipo']} - Staff: ${data['staff'].join(', ')}"),
                  trailing: const Icon(Icons.chevron_right),
                  // ---------------------------------------------------------
                  // AL CLICK SI APRE IL DETTAGLIO
                  // ---------------------------------------------------------
                  onTap: () => _mostraDettaglioIntervento(context, data),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------
  // FUNZIONE VISUALIZZAZIONE DETTAGLIO (Scheda completa)
  // ---------------------------------------------------------
  void _mostraDettaglioIntervento(BuildContext context, Map<String, dynamic> d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d['cliente'].toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(),
            _infoRow(Icons.calendar_today, "Data:", DateFormat('dd/MM/yyyy HH:mm').format((d['dataInizio'] as Timestamp).toDate())),
            _infoRow(Icons.build, "Tipo:", d['tipo']),
            _infoRow(Icons.people, "Staff:", d['staff'].join(', ')),
            const SizedBox(height: 20),
            const Text("NOTE / DESCRIZIONE:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(d['descrizione'] ?? "Nessuna nota"),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CHIUDI")),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData i, String t, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [Icon(i, size: 20, color: Colors.grey), const SizedBox(width: 10), Text(t), const SizedBox(width: 10), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}