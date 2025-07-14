import '../pages/chat_detail.dart';

class ChatStorage {
  static final List<ChatSession> _sessions = [];

  static List<ChatSession> getAllChats() {
    return _sessions;
  }

  static void addSession(ChatSession session) {
    _sessions.add(session);
  }

  static ChatSession? getSessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  static void clearAllChats() {
    _sessions.clear();
  }

}
