import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/calendario_page.dart';
import '../pages/clienti_page.dart';
import '../pages/interventi_page.dart';
import '../pages/impostazioni_page.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ---------------------------------------------------------
          // INTESTAZIONE DEL MENU (LOGO E INFO AZIENDA)
          // ---------------------------------------------------------
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0D47A1)),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.water_drop, color: Color(0xFF0D47A1), size: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text("Idrocostruzioni", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text("gestione@idrocostruzioni.it", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
          // ---------------------------------------------------------

          // ---------------------------------------------------------
          // VOCE: DASHBOARD (PAGINA PRINCIPALE)
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.blue),
            title: const Text("Dashboard"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const HomePage())),
          ),
          // ---------------------------------------------------------

          // ---------------------------------------------------------
          // VOCE: AGENDA (IL CALENDARIO)
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: const Text("Agenda Interventi"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const CalendarioPage())),
          ),
          // ---------------------------------------------------------

          // ---------------------------------------------------------
          // VOCE: LISTA INTERVENTI (QUELLA CHE ERA SPARITA)
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.list_alt, color: Colors.blue),
            title: const Text("Lista Interventi"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const InterventiPage())),
          ),
          // ---------------------------------------------------------

          // ---------------------------------------------------------
          // VOCE: ANAGRAFICA CLIENTI
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text("Anagrafica Clienti"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ClientiPage())),
          ),
          // ---------------------------------------------------------

          const Spacer(), // Spinge le impostazioni in basso
          const Divider(),

          // ---------------------------------------------------------
          // VOCE: IMPOSTAZIONI E STAFF
          // ---------------------------------------------------------
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text("Impostazioni Staff"),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const ImpostazioniPage())),
          ),
          // ---------------------------------------------------------
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}