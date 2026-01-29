import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StoricoInterventiPage extends StatelessWidget {
  final String clienteCodice;

  const StoricoInterventiPage({super.key, required this.clienteCodice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Storico Interventi - $clienteCodice"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('interventi')
            .where('codice_cliente', isEqualTo: clienteCodice)
            .orderBy('dataInizio', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Errore di connessione"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text("Nessun intervento trovato per questo cliente."));
          }

          final interventi = snapshot.data!.docs;

          return ListView.builder(
            itemCount: interventi.length,
            itemBuilder: (context, index) {
              final intervento =
                  interventi[index].data() as Map<String, dynamic>;
              final dataInizio = (intervento['dataInizio'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  title: Text(
                    intervento['tipo'] ?? 'N/D',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Data: ${dataInizio != null ? DateFormat('dd/MM/yyyy HH:mm').format(dataInizio) : 'N/D'}\nStato: ${intervento['stato'] ?? 'N/D'}",
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to the intervention details page
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
