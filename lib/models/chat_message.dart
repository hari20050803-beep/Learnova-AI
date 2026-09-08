/// One message in the AI Academic Chatbot conversation.
class ChatMessage {
  final String text;

  /// True if the student wrote it, false if Gemini answered.
  final bool isUser;

  const ChatMessage({required this.text, required this.isUser});
}
