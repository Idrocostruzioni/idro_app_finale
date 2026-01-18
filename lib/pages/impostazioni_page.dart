import 'package:flutter/material.dart';

class ImpostazioniPage extends StatelessWidget {
  const ImpostazioniPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Impostazioni")),
      body: const Center(child: Text("Qui potrai gestire tipologie e team")),
    );
  }
}