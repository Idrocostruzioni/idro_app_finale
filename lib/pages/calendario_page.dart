import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'interventi_page.dart'; // Per poter creare un intervento dal calendario

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});
  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  CalendarFormat _format = CalendarFormat.week; // Vista settimanale per risparmiare spazio
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agenda Oraria"),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync), 
            onPressed: () => print("Sincronizzazione Google/iOS..."), // Qui collegheremo i calendari
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Calendario a righe (Settimanale/Mensile)
          TableCalendar(
            locale: 'it_IT',
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030),
            focusedDay: _focusedDay,
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() { _selectedDay = selected; _focusedDay = focused; });
            },
            onFormatChanged: (f) => setState(() => _format = f),
          ),
          const Divider(height: 1),
          
          // 2. VISTA GIORNALIERA ORARIA
          Expanded(
            child: ListView.builder(
              itemCount: 24, // 24 ore
              itemBuilder: (context, hour) {
                // Filtriamo solo ore lavorative (es. 08-19)
                if (hour < 8 || hour > 19) return const SizedBox.shrink();
                
                return InkWell(
                  onTap: () => _aggiungiInterventoOrario(hour),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      children: [
                        // Colonna Ora
                        Container(
                          width: 60,
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 10),
                          child: Text("$hour:00", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        // Area Interventi
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: hour == 10 ? Colors.blue[100] : Colors.transparent, // Esempio intervento alle 10
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: hour == 10 
                              ? const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text("Installazione Caldaia - Rossi", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ) 
                              : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _aggiungiInterventoOrario(9),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  void _aggiungiInterventoOrario(int ora) {
    // Naviga alla scheda intervento passando l'ora selezionata
    Navigator.push(context, MaterialPageRoute(builder: (context) => const SchedaIntervento()));
  }
}