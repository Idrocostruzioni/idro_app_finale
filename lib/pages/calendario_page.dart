import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/main_drawer.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  final CalendarController _calendarController = CalendarController();
  DateTime _dataSelezionata = DateTime.now();
  
  // Operatore attivo e colore (predefiniti)
  String _operatoreVisualizzato = "Luciano";
  Color _coloreCorrente = Colors.blue;

  @override
  void initState() {
    super.initState();
    _calendarController.displayDate = _dataSelezionata;
  }

  // ---------------------------------------------------------
  // 1. FUNZIONE PER MOSTRARE IL DETTAGLIO QUANDO TOCCHI L'AGENDA
  // ---------------------------------------------------------
  void _mostraSchedaDettaglio(BuildContext context, Appointment app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.subject.toUpperCase(), 
                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(height: 30),
            Row(children: [
              const Icon(Icons.access_time, size: 20, color: Colors.grey),
              const SizedBox(width: 10),
              Text("Orario: ${DateFormat('HH:mm').format(app.startTime)} - ${DateFormat('HH:mm').format(app.endTime)}", 
                   style: const TextStyle(fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 15),
            const Text("NOTE INTERVENTO:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(app.notes ?? "Nessuna nota inserita"),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CHIUDI")),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Agenda: $_operatoreVisualizzato"),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _dataSelezionata, firstDate: DateTime(2025), lastDate: DateTime(2030));
              if (d != null) setState(() { _dataSelezionata = d; _calendarController.displayDate = d; });
            },
          ),
          // SELETTORE OPERATORE (Menu in alto a destra)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('staff').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return PopupMenuButton<DocumentSnapshot>(
                icon: const Icon(Icons.people_alt),
                onSelected: (doc) => setState(() {
                  _operatoreVisualizzato = doc['nome'];
                  _coloreCorrente = Color(doc['colore']);
                }),
                itemBuilder: (context) => snapshot.data!.docs.map((doc) => 
                  PopupMenuItem(value: doc, child: Text(doc['nome']))).toList(),
              );
            },
          )
        ],
      ),
      drawer: const MainDrawer(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Text(DateFormat('MMMM yyyy', 'it').format(_dataSelezionata).toUpperCase(),
                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('interventi')
                  .where('staff', arrayContains: _operatoreVisualizzato)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Errore dati"));
                
                return SfCalendar(
                  controller: _calendarController,
                  view: CalendarView.day,
                  headerHeight: 0,
                  dataSource: _getCalendarDataSource(snapshot.data),
                  timeSlotViewSettings: const TimeSlotViewSettings(startHour: 8, endHour: 19, timeIntervalHeight: 150),
                  onTap: (CalendarTapDetails details) {
                    if (details.appointments != null && details.appointments!.isNotEmpty) {
                      _mostraSchedaDettaglio(context, details.appointments![0]);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () => _mostraModuloInserimento(context),
        backgroundColor: Colors.blue[900],
        child: const Icon(Icons.add, color: Colors.white, size: 40),
      ),
    );
  }

  // ---------------------------------------------------------
  // 2. LOGICA RECUPERO DATI DA FIREBASE (EVITA ERRORI CAMPI MANCANTI)
  // ---------------------------------------------------------
  _AppointmentDataSource _getCalendarDataSource(QuerySnapshot? snapshot) {
    List<Appointment> list = [];
    if (snapshot != null) {
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('dataInizio') && data['dataInizio'] != null) {
          list.add(Appointment(
            startTime: (data['dataInizio'] as Timestamp).toDate(),
            endTime: (data['dataFine'] as Timestamp).toDate(),
            subject: "${data['cliente']} - ${data['tipo']}",
            notes: data['descrizione'] ?? "",
            color: _coloreCorrente,
          ));
        }
      }
    }
    return _AppointmentDataSource(list);
  }

  // ---------------------------------------------------------
  // 3. MODULO PER AGGIUNGERE UN NUOVO INTERVENTO
  // ---------------------------------------------------------
  void _mostraModuloInserimento(BuildContext context) {
    String? clienteSelezionato;
    String? tipoScelto;
    final descController = TextEditingController();
    List<String> operatoriScelti = [_operatoreVisualizzato];
    TimeOfDay oraInizio = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay oraFine = const TimeOfDay(hour: 11, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("NUOVO APPUNTAMENTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),
                
                // Ricerca Cliente
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textValue) async {
                    if (textValue.text.isEmpty) return const Iterable.empty();
                    final snapshot = await FirebaseFirestore.instance.collection('clienti').get();
                    return snapshot.docs
                        .map((doc) => doc.data()['nome'].toString())
                        .where((nome) => nome.toLowerCase().contains(textValue.text.toLowerCase()));
                  },
                  onSelected: (String s) => setModalState(() => clienteSelezionato = s),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextField(
                    controller: controller, focusNode: focusNode,
                    decoration: const InputDecoration(labelText: "Cerca Cliente", border: OutlineInputBorder()),
                  ),
                ),

                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Tipo Intervento", border: OutlineInputBorder()),
                  items: ["Installazione", "Sopralluogo", "Manutenzione"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => tipoScelto = v,
                ),
                
                const SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  OutlinedButton(onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: oraInizio);
                    if (t != null) setModalState(() => oraInizio = t);
                  }, child: Text("Dalle: ${oraInizio.format(context)}")),
                  OutlinedButton(onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: oraFine);
                    if (t != null) setModalState(() => oraFine = t);
                  }, child: Text("Alle: ${oraFine.format(context)}")),
                ]),

                const SizedBox(height: 15),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Note/Descrizione", border: OutlineInputBorder())),
                
                const SizedBox(height: 25),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], padding: const EdgeInsets.all(15)),
                  onPressed: () async {
                    if (clienteSelezionato == null) return;
                    DateTime inizio = DateTime(_dataSelezionata.year, _dataSelezionata.month, _dataSelezionata.day, oraInizio.hour, oraInizio.minute);
                    DateTime fine = DateTime(_dataSelezionata.year, _dataSelezionata.month, _dataSelezionata.day, oraFine.hour, oraFine.minute);

                    await FirebaseFirestore.instance.collection('interventi').add({
                      'cliente': clienteSelezionato,
                      'tipo': tipoScelto,
                      'descrizione': descController.text,
                      'staff': operatoriScelti,
                      'dataInizio': inizio,
                      'dataFine': fine,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("SALVA IN AGENDA", style: TextStyle(color: Colors.white)),
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentDataSource extends CalendarDataSource {
  _AppointmentDataSource(List<Appointment> source) { appointments = source; }
}