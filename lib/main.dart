// lib/main.dart
import 'package:flutter/material.dart';
import 'package:kelime_oyunu/app.dart';

// TODO: Firebase.initializeApp() — FAZ 6'da eklenecek

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KelimeOyunuApp());
}
