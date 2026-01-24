import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:collection/collection.dart';
import '../widgets/main_drawer.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  DateTime _focusedDate = DateTime.now();
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _stati = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _caricaDatiSupporto();
  }

  Future<void> _caricaDatiSupporto() async {
    try {
      // Carica lo staff
      final staffSnapshot = await FirebaseFirestore.instance.collection('staff').orderBy('nome').get();
      _staff = staffSnapshot.docs.map((doc) => doc.data()).toList();

      // Carica gli stati per i colori
      final commesseDoc = await FirebaseFirestore.instance.collection('impostazioni').doc('commesse').get();
      if (commesseDoc.exists && commesseDoc.data() != null) {
        _stati = List<Map<String, dynamic>>.from(commesseDoc.data()!['stati'] ?? []);
      }
    } catch (e) {
      debugPrint("Errore caricamento dati per calendario: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getColoreStato(String? statoNome) {
    if (statoNome == null) return Colors.blueGrey;
    // FIX: Gestione robusta del colore per evitare crash se lo stato non esiste più
    final stato = _stati.firstWhereOrNull((s) => s['nome'] == statoNome);
    if (stato != null && stato['colore'] is int) {
      return Color(stato['colore']);
    }
    return Colors.blueGrey; // Colore di fallback sicuro
  }

  void _changeWeek(int days) {
    setState(() {
      _focusedDate = _focusedDate.add(Duration(days: days));
    });
  }

  @override
  Widget build(BuildContext context) {
    // --- CONTROLLO PIATTAFORMA ---
    // Mostra questa pagina solo su web/desktop. Su mobile mostra un messaggio.
    final bool isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(title: const Text("Agenda Interventi"), backgroundColor: Colors.blue[100]),
        drawer: const MainDrawer(),
        body: const Center(
          child: Text("L'agenda settimanale non è disponibile su smartphone.\nUsa la Lista Interventi.", textAlign: TextAlign.center),
        ),
      );
    }

    final firstDayOfWeek = _focusedDate.subtract(Duration(days: _focusedDate.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));

    final startTimestamp = Timestamp.fromDate(DateTime(firstDayOfWeek.year, firstDayOfWeek.month, firstDayOfWeek.day));
    final endTimestamp = Timestamp.fromDate(DateTime(lastDayOfWeek.year, lastDayOfWeek.month, lastDayOfWeek.day, 23, 59, 59));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Agenda Interventi"),
        backgroundColor: Colors.blue[100],
      ),
      drawer: const MainDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildWeekNavigator(firstDayOfWeek, lastDayOfWeek),
                _buildHeaderRow(firstDayOfWeek),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('interventi')
                        .where('dataInizio', isGreaterThanOrEqualTo: startTimestamp)
                        .where('dataInizio', isLessThanOrEqualTo: endTimestamp)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: Text("Nessun dato per questa settimana."));
                      }

                      final interventi = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: _staff.length,
                        itemBuilder: (context, index) {
                          final tecnico = _staff[index];
                          return _buildTechnicianRow(tecnico, interventi, firstDayOfWeek);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildWeekNavigator(DateTime firstDay, DateTime lastDay) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeWeek(-7)),
          Column(
            children: [
              Text(
                "Settimana dal ${DateFormat('d MMM', 'it_IT').format(firstDay)} al ${DateFormat('d MMM yyyy', 'it_IT').format(lastDay)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(onPressed: () => setState(() => _focusedDate = DateTime.now()), child: const Text("Vai a oggi"))
            ],
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeWeek(7)),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(DateTime firstDayOfWeek) {
    // FIX: Riscritto interamente per correggere errori di sintassi e parentesi.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border(bottom: BorderSide(color: Colors.grey.shade400, width: 2)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 100, child: Center(child: Text("Tecnico", style: TextStyle(fontWeight: FontWeight.bold)))),
          ...List.generate(7, (index) {
            final day = firstDayOfWeek.add(Duration(days: index));
            return Expanded(
              child: Column(children: [
                Text(DateFormat('E', 'it_IT').format(day).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                Text(DateFormat('d', 'it_IT').format(day),
                    style: const TextStyle(fontSize: 14)),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTechnicianRow(Map<String, dynamic> tecnico, List<QueryDocumentSnapshot> allInterventi, DateTime firstDayOfWeek) {
    // FIX: Riscritto interamente per correggere errori di sintassi e parentesi.
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Allinea le celle all'inizio
        children: [
          SizedBox(
            width: 100,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text(tecnico['nome'] ?? 'N/D',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          ...List.generate(7, (dayIndex) {
            final currentDay = firstDayOfWeek.add(Duration(days: dayIndex));
            final interventiDelGiorno = allInterventi.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final dataInizio = (data['dataInizio'] as Timestamp?)?.toDate();
              if (dataInizio == null) return false;
              return data['tecnico'] == tecnico['nome'] && DateUtils.isSameDay(dataInizio, currentDay);
            }).toList();

            return Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 60),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.shade300))),
                child: Column(children: interventiDelGiorno.map((intervento) => _buildInterventoBox(intervento)).toList()),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInterventoBox(DocumentSnapshot intervento) {
    final data = intervento.data() as Map<String, dynamic>;
    final cliente = data['cliente'] ?? 'N/D';
    final tipo = data['tipo'] ?? 'Nessun tipo';
    final indirizzo = "${data['via'] ?? ''}, ${data['citta'] ?? ''}";
    final oraInizio = data['dataInizio'] != null ? DateFormat('HH:mm').format((data['dataInizio'] as Timestamp).toDate()) : '';
    final oraFine = data['dataFine'] != null ? DateFormat('HH:mm').format((data['dataFine'] as Timestamp).toDate()) : '';
    final note = data['descrizione'] ?? 'Nessuna nota.';

    return Tooltip(
      message: note,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 14),
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getColoreStato(data['stato']).withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _getColoreStato(data['stato'])),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(cliente, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
                Text("$oraInizio - $oraFine", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Text(tipo, style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
            const SizedBox(height: 4),
            Text(indirizzo, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}