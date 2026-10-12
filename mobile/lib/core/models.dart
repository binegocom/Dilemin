class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.onlineVisible,
    this.bio,
  });

  final String id;
  final String name;
  final bool onlineVisible;
  final String? bio;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'].toString(),
        name: json['display_name'] as String,
        onlineVisible: json['online_visible'] as bool,
        bio: json['bio'] as String?,
      );
}

class OnlinePerson {
  const OnlinePerson({required this.id, required this.name, this.bio});

  final String id;
  final String name;
  final String? bio;

  factory OnlinePerson.fromJson(Map<String, dynamic> json) => OnlinePerson(
        id: json['id'].toString(),
        name: json['display_name'] as String,
        bio: json['bio'] as String?,
      );
}

class ConversationPreview {
  const ConversationPreview({required this.id, required this.person});
  final String id;
  final OnlinePerson person;

  factory ConversationPreview.fromJson(Map<String, dynamic> json) =>
      ConversationPreview(
        id: json['id'].toString(),
        person: OnlinePerson.fromJson(json['person'] as Map<String, dynamic>),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'].toString(),
        senderId: json['sender_id'].toString(),
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
