import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'pages/calendario_page.dart';
import 'pages/clienti_page.dart';
import 'pages/impostazioni_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it', 'IT')],
      locale: const Locale('it', 'IT'),
      initialRoute: '/calendario',
      routes: {
        '/calendario': (context) => const CalendarioPage(),
        '/clienti': (context) => const ClientiPage(),
        '/impostazioni': (context) => const ImpostazioniPage(),
      },
    );
  }
}