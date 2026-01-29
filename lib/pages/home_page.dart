import 'package:flutter/material.dart';
import '../widgets/main_drawer.dart';
import 'clienti_page.dart';
import 'calendario_page.dart';
import 'interventi_page.dart';
import 'impostazioni_page.dart';
import 'ticket_page.dart';
import 'prodotti_page.dart';
import 'rapporti_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard Idrocostruzioni"),
        centerTitle: true,
        backgroundColor: Colors.blue[100],
      ),
      drawer: const MainDrawer(),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2, // 2 colonne
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          // ---------------------------------------------------------
          // BLOCCO BOTTONE ANAGRAFICA CLIENTI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.people,
            "CLIENTI",
            Colors.blue,
            const ClientiPage()
          ),
          
          // ---------------------------------------------------------
          // BLOCCO BOTTONE CALENDARIO (AGENDA)
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.calendar_month,
            "CALENDARIO",
            Colors.orange,
            const CalendarioPage()
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE LISTA INTERVENTI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.build,
            "INTERVENTI",
            const Color(0xFF4CAF50), // Verde
            const InterventiPage()
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE TICKET
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.warning,
            "TICKET",
            Colors.red,
            const TicketPage()
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE RAPPORTI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.article,
            "RAPPORTI",
            Colors.purple,
            const RapportiPage()
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE CLIMATIZZATORI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.ac_unit,
            "CLIMATIZZATORI",
            Colors.lightBlue,
            const ProdottiPage(title: "Climatizzatori", content: "Istruzioni, regolamenti e best practice per l'installazione di climatizzatori.")
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE CALDAIE
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.whatshot,
            "CALDAIE",
            Colors.deepOrange,
            const ProdottiPage(title: "Caldaie", content: "Istruzioni, regolamenti e best practice per l'installazione di caldaie.")
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE SCALDABAGNI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.shower,
            "SCALDABAGNI",
            Colors.brown,
            const ProdottiPage(title: "Scaldabagni", content: "Istruzioni, regolamenti e best practice per l'installazione di scaldabagni.")
          ),

          // ---------------------------------------------------------
          // BLOCCO BOTTONE IMPOSTAZIONI
          // ---------------------------------------------------------
          _buildMenuCard(
            context,
            Icons.settings,
            "IMPOSTAZIONI",
            Colors.grey,
            const ImpostazioniPage()
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // FUNZIONE PER CREARE I BOTTONI DELLA DASHBOARD
  // ---------------------------------------------------------
  Widget _buildMenuCard(BuildContext context, IconData icon, String label, Color color, Widget page) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: color),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}