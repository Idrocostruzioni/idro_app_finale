import 'package:flutter/material.dart';
import '../widgets/main_drawer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RapportiPage extends StatefulWidget {
  const RapportiPage({super.key});

  @override
  State<RapportiPage> createState() => _RapportiPageState();
}

class _RapportiPageState extends State<RapportiPage> {
  List<Map<String, dynamic>> _buttons = [];

  @override
  void initState() {
    super.initState();
    _caricaBottoni();
  }

  Future<void> _caricaBottoni() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('impostazioni').doc('rapporti').get();
      if (doc.exists && doc.data() != null) {
        setState(() {
          _buttons = List<Map<String, dynamic>>.from(doc.data()!['bottoni'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Errore caricamento bottoni: $e");
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rapporti (Verbali)"),
        centerTitle: true,
        backgroundColor: Colors.blue[100],
      ),
      drawer: const MainDrawer(),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _buttons.length,
        itemBuilder: (context, index) {
          final button = _buttons[index];
          final color = Color(int.parse(button['colore'].replaceFirst('#', '0xFF')));
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: () => _launchUrl(button['link']),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                button['testo'],
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
