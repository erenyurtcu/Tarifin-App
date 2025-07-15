import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'pages/chat_home.dart';

void main() {
  runApp(const MyApp());
}

class ChatMessage {
  final String role; // 'user' or 'assistant'
  String content;

  ChatMessage({required this.role, required this.content});
}

class ChatSession {
  final String id;
  String title;
  final List<ChatMessage> messages;

  ChatSession({required this.id, required this.title, required this.messages});
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tarifin - Recipe Assistant',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      debugShowCheckedModeBanner: false,
      home: const ChatHomePage(),
    );
  }
}

class SpeechPage extends StatefulWidget {
  const SpeechPage({super.key});

  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  DateTime _lastUiUpdate = DateTime.now();
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
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
    if (inputText.trim().isEmpty) return;

    ChatMessage? assistantMessage;

    if (_currentSession != null && !_sessions.contains(_currentSession)) {
      final newTitle = inputText.length > 40 ? inputText.substring(0, 40) + "..." : inputText;
      setState(() {
        _currentSession!.title = newTitle;
        _sessions.add(_currentSession!);
      });
    }

    _currentSession?.messages.add(ChatMessage(role: 'user', content: inputText));
    setState(() {}); // Kullanıcının mesajı hemen görünsün

    final url = Uri.parse("http://172.18.80.190:5000/generate");

    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({'text': inputText});

      final streamedResponse = await request.send();

      if (_currentSession!.messages.isEmpty || _currentSession!.messages.last.role != 'assistant') {
        assistantMessage = ChatMessage(role: 'assistant', content: '');
        _currentSession?.messages.add(assistantMessage);
        setState(() {});
      }

      StringBuffer buffer = StringBuffer();

      streamedResponse.stream
          .transform(utf8.decoder)
          .listen((chunk) {
        buffer.write(chunk);
        String currentText = buffer.toString();

        // Kullanıcı girdisi tekrar edilmesin
        if (currentText.startsWith(inputText)) {
          currentText = currentText.substring(inputText.length).trimLeft();
        }

        if (assistantMessage != null) {
          if (DateTime.now().difference(_lastUiUpdate).inMilliseconds > 100) {
            _lastUiUpdate = DateTime.now();
            setState(() {
              assistantMessage!.content = currentText;
            });
          } else {
            assistantMessage!.content = currentText;
          }
        }
      }, onDone: () async {
        _responseText = buffer.toString();

        if (_responseText.isNotEmpty) {
          final sentences = _responseText
              .split(RegExp(r'[.!?]'))
              .where((s) => s.trim().isNotEmpty);

          for (final sentence in sentences) {
            await _flutterTts.speak(sentence.trim());
            await Future.delayed(const Duration(milliseconds: 1500));
          }

          await _flutterTts.stop();
          await _flutterTts.speak(_responseText);
        }
      }, onError: (e) {
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
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
            children: [
              const TextSpan(
                text: 'tarifin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const TextSpan(
                text: ' – ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const TextSpan(
                text: 'Recipe Assistant',
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _isListening ? _stopListeningAndSend : _startListening,
              child: Text(_isListening ? "Stop and Send" : "Start Talking"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: "Submit your question in writing",
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
            const Text("🎤 Live Transcription:"),
            Text(
              _recognizedText,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Text("Answer:"),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _currentSession!.messages.length,
                itemBuilder: (context, index) {
                  final message = _currentSession!.messages[index];
                  return Align(
                    alignment: message.role == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: message.role == 'user'
                            ? Colors.deepPurple.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: MarkdownBody(
                        data: message.content,
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: const TextStyle(fontSize: 16),
                          strong: const TextStyle(color: Colors.deepPurple),
                          code: const TextStyle(backgroundColor: Colors.black12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newSession = ChatSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "",
            messages: [],
          );
          setState(() {
            _currentSession = newSession;
            _textController.clear();
            _recognizedText = '';
            _responseText = '';
          });
        },
        tooltip: 'New Chat',
        child: const Icon(Icons.add),
      ),
    );
  }
}
