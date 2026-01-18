import 'package:flutter/material.dart';
import 'clienti_page.dart';
import 'calendario_page.dart';
import 'interventi_page.dart';
import 'impostazioni_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard Idro"), centerTitle: true),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15,
        children: [
          _homeCard(context, Icons.people, "CLIENTI", Colors.blue, const ClientiPage()),
          _homeCard(context, Icons.calendar_month, "CALENDARIO", Colors.orange, const CalendarioPage()),
          _homeCard(context, Icons.build, "INTERVENTI", Colors.green, const ListaInterventiPage()),
          _homeCard(context, Icons.settings, "IMPOSTAZIONI", Colors.grey, const ImpostazioniPage()),
        ],
      ),
    );
  }

  Widget _homeCard(BuildContext context, IconData icon, String label, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
      child: Card(
        elevation: 4, 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, size: 50, color: color), 
            const SizedBox(height: 10), 
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold))
          ]
        )
      ),
    );
  }
}