import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    Future.delayed(Duration.zero, () async {
      await _flutterTts.setSpeechRate(0.45);
    });
  }


  Future<void> _startListening() async {
    print(">>> Başlatılıyor...");
    bool available = await _speech.initialize(
      onStatus: (status) => print("SPEECH STATUS: $status"),
      onError: (error) => print("SPEECH ERROR: ${error.errorMsg}"),
    );
    print("Speech initialized: $available");

    if (available) {
      print(">>> Dinleme başladı...");
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          print("Recognized words: ${val.recognizedWords}");
          setState(() {
            _recognizedText = val.recognizedWords;
            _textController.text = val.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 6),
      );
    } else {
      print(">>> Mikrofon başlatılamadı.");
    }
  }


  Future<void> _stopListeningAndSend() async {
    _speech.stop();
    setState(() => _isListening = false);
    await _sendText(_textController.text);
  }

  Future<void> _sendText(String inputText) async {
    if (inputText.isEmpty) return;

    final url = Uri.parse("http://172.18.80.190:5000/generate"); // WSL IP

    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({'text': inputText});

      final streamedResponse = await request.send();

      StringBuffer buffer = StringBuffer();

      streamedResponse.stream
          .transform(utf8.decoder)
          .listen((chunk) {
        buffer.write(chunk);
        String currentText = buffer.toString();

        // Eğer output, inputText ile başlıyorsa baştaki kısmı kaldır
        if (currentText.startsWith(inputText)) {
          currentText = currentText.substring(inputText.length).trimLeft();
        }

        setState(() {
          _responseText = currentText;
        });
      },

          onDone: () async {
            if (_responseText.isNotEmpty) {
              final sentences = _responseText.split(RegExp(r'[.!?]')).where((s) => s.trim().isNotEmpty);
              for (final sentence in sentences) {
                await _flutterTts.speak(sentence.trim());
                await Future.delayed(const Duration(milliseconds: 1500));
              }
              await _flutterTts.stop();
              await _flutterTts.speak(_responseText);
            }
          }
          , onError: (e) {
        setState(() {
          _responseText = "Streaming hatası: $e";
        });
      });

    } catch (e) {
      setState(() {
        _responseText = "Sunucuya bağlanılamadı: $e";
      });
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
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: "Yazılı olarak sor",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _sendText(_textController.text),
                ),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            const Text("🎤 Canlı Konuşma:"),
            Text(
              _recognizedText,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Text("🧠 Yanıt:"),
            const SizedBox(height: 8),
            // 🔽 Yanıt için markdown + scroll + overflow kontrolü
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: MarkdownBody(
                    data: _responseText,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(fontSize: 16),
                      h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      strong: const TextStyle(color: Colors.deepPurple),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

