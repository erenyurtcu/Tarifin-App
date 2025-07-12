import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarifin Asistan',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const SpeechPage(),
    );
  }
}

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key});

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';
  String _responseText = '';
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _recognizedText = val.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 6),
      );
    }
  }

  Future<void> _stopListeningAndSend() async {
    _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse("http://10.0.2.2:5000/api"), // emülatör için
          headers: {"Content-Type": "application/json"},
          body: json.encode({"text": _recognizedText}),
        );

        if (response.statusCode == 200) {
          setState(() {
            _responseText = json.decode(response.body)['reply'];
          });
          await _flutterTts.speak(_responseText);
        } else {
          setState(() {
            _responseText = "Hata: ${response.statusCode}";
          });
        }
      } catch (e) {
        setState(() {
          _responseText = "Sunucuya bağlanılamadı: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarifin Asistan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isListening ? _stopListeningAndSend : _startListening,
              child: Text(_isListening ? "Durdur ve Gönder" : "Konuşmaya Başla"),
            ),
            const SizedBox(height: 20),
            Text("🎤 Algılanan: $_recognizedText"),
            const SizedBox(height: 10),
            Text("🧠 Yanıt: $_responseText"),
          ],
        ),
      ),
    );
  }
}
