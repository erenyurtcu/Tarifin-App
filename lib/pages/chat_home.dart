import 'package:flutter/material.dart';
import '../services/chat_storage.dart';
import 'chat_detail.dart';

class ChatHomePage extends StatefulWidget {
  const ChatHomePage({super.key});

  @override
  State<ChatHomePage> createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  @override
  Widget build(BuildContext context) {
    final sessions = ChatStorage.getAllChats();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "tarifin – Recipe Assistant",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: sessions.isEmpty
          ? const Center(
        child: Text(
          "No conversations started yet.",
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          return ListTile(
            title: Text(session.title),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailPage(session: session),
                ),
              ).then((_) => setState(() {})); // geri dönünce yenile
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newSession = ChatSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: "",
            messages: [],
          );
          ChatStorage.addSession(newSession);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailPage(session: newSession),
            ),
          ).then((_) => setState(() {})); // yeni sohbet sonrası listeyi güncelle
        },
        tooltip: 'Yeni Sohbet Başlat',
        child: const Icon(Icons.add),
      ),
    );
  }
}