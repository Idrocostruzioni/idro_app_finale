import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestione Staff"),
        backgroundColor: Colors.blue[100],
      ),
      // ---------------------------------------------------------
      // TASTO AGGIUNGI NUOVO OPERATORE
      // ---------------------------------------------------------
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostraModuloStaff(context),
        label: const Text("Aggiungi Staff"),
        icon: const Icon(Icons.person_add),
      ),
      // ---------------------------------------------------------

      // ---------------------------------------------------------
      // LISTA OPERATORI DA DATABASE
      // ---------------------------------------------------------
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('staff').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(10),
            children: snapshot.data!.docs.map((doc) {
              final s = doc.data() as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(s['colore'] ?? Colors.grey.value),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(s['nome'] ?? "Senza nome", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${s['ruolo']} | ${s['email']}"),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _mostraModuloStaff(context, dati: s, idDoc: doc.id),
                ),
              );
            }).toList(),
          );
        },
      ),
      // ---------------------------------------------------------
    );
  }

  void _mostraModuloStaff(BuildContext context, {Map<String, dynamic>? dati, String? idDoc}) {
    final nomeController = TextEditingController(text: dati?['nome']);
    final emailController = TextEditingController(text: dati?['email']);
    final telController = TextEditingController(text: dati?['tel']);
    final passController = TextEditingController(); // Solo per nuovi o reset
    String ruoloScelto = dati?['ruolo'] ?? "Tecnico";
    int coloreScelto = dati?['colore'] ?? Colors.blue.value;

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
                Text(idDoc == null ? "NUOVO OPERATORE" : "MODIFICA OPERATORE", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // BLOCCO FOTO (Segnaposto per ora)
                // ---------------------------------------------------------
                const CircleAvatar(radius: 40, child: Icon(Icons.camera_alt, size: 30)),
                const TextButton(onPressed: null, child: Text("Carica Foto")),
                // ---------------------------------------------------------

                _input(nomeController, "Nome e Cognome", Icons.person),
                _input(emailController, "Indirizzo Email", Icons.email),
                _input(telController, "Telefono", Icons.phone),
                
                // ---------------------------------------------------------
                // PASSWORD TEMPORANEA (Solo se nuovo utente)
                // ---------------------------------------------------------
                if (idDoc == null)
                _input(passController, "Password Temporanea", Icons.lock_outline),
                // ---------------------------------------------------------

                const SizedBox(height: 10),

                // ---------------------------------------------------------
                // SELEZIONE RUOLO E PERMESSI
                // ---------------------------------------------------------
                DropdownButtonFormField<String>(
                  value: ruoloScelto,
                  decoration: const InputDecoration(labelText: "Ruolo (Permessi)", border: OutlineInputBorder()),
                  items: ["Admin", "Tecnico", "Segreteria"].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setModalState(() => ruoloScelto = v!),
                ),
                // ---------------------------------------------------------

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // SELEZIONE COLORE IN AGENDA
                // ---------------------------------------------------------
                const Align(alignment: Alignment.centerLeft, child: Text("Colore Agenda:")),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple].map((c) => GestureDetector(
                    onTap: () => setModalState(() => coloreScelto = c.value),
                    child: CircleAvatar(
                      backgroundColor: c,
                      child: coloreScelto == c.value ? const Icon(Icons.check, color: Colors.white) : null,
                    ),
                  )).toList(),
                ),
                // ---------------------------------------------------------

                const SizedBox(height: 30),

                // ---------------------------------------------------------
                // BOTTONE SALVA E CREA ACCOUNT
                // ---------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                    onPressed: () async {
                      try {
                        // 1. Se è nuovo, crea l'accesso reale su Firebase Auth
                        if (idDoc == null) {
                          await FirebaseAuth.instance.createUserWithEmailAndPassword(
                            email: emailController.text.trim(),
                            password: passController.text.trim(),
                          );
                        }

                        // 2. Salva o aggiorna i dati dello staff su Firestore
                        final map = {
                          'nome': nomeController.text,
                          'email': emailController.text.trim(),
                          'tel': telController.text,
                          'ruolo': ruoloScelto,
                          'colore': coloreScelto,
                          'primo_accesso': idDoc == null ? true : false,
                        };

                        if (idDoc == null) {
                          await FirebaseFirestore.instance.collection('staff').add(map);
                        } else {
                          await FirebaseFirestore.instance.collection('staff').doc(idDoc).update(map);
                        }

                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Errore: $e")));
                      }
                    },
                    child: Text(idDoc == null ? "CREA ACCOUNT E SALVA" : "AGGIORNA DATI"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), border: const OutlineInputBorder())),
  );
}