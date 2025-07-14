import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// MODEL
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  ChatMessage({required this.role, required this.content});
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;

  ChatSession({required this.id, required this.title, required this.messages});
}

// SAYFA
class ChatDetailPage extends StatefulWidget {
  final ChatSession session;

  const ChatDetailPage({super.key, required this.session});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
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
    bool available = await _speech.initialize(
      onStatus: (status) => print("SPEECH STATUS: $status"),
      onError: (error) => print("SPEECH ERROR: ${error.errorMsg}"),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() {
            _recognizedText = val.recognizedWords;
            _textController.text = val.recognizedWords;
          });
        },
        listenFor: const Duration(seconds: 6),
      );
    }
  }

  Future<void> _stopListeningAndSend() async {
    _speech.stop();
    setState(() => _isListening = false);
    await _sendText(_textController.text);
  }

  Future<void> _sendText(String inputText) async {
    if (inputText.isEmpty) return;

    widget.session.messages.add(ChatMessage(role: 'user', content: inputText));

    final url = Uri.parse("http://172.18.80.190:5000/generate");

    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = json.encode({'text': inputText});

      final streamedResponse = await request.send();
      StringBuffer buffer = StringBuffer();

      streamedResponse.stream.transform(utf8.decoder).listen(
            (chunk) {
          buffer.write(chunk);
          String currentText = buffer.toString();

          if (currentText.startsWith(inputText)) {
            currentText = currentText.substring(inputText.length).trimLeft();
          }

          setState(() {
            _responseText = currentText;
            widget.session.messages
                .add(ChatMessage(role: 'assistant', content: currentText));
          });
        },
        onDone: () async {
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
        },
        onError: (e) {
          setState(() {
            _responseText = "Streaming hatası: $e";
          });
        },
      );
    } catch (e) {
      setState(() {
        _responseText = "Sunucuya bağlanılamadı: $e";
      });
    }

    _textController.clear();
    _recognizedText = '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.title),
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
            const SizedBox(height: 16),
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
                itemCount: widget.session.messages.length,
                itemBuilder: (context, index) {
                  final message = widget.session.messages[index];
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
    );
  }
}
