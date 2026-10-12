class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.onlineVisible,
    this.bio,
    this.photoId,
    this.photoStatus,
    this.isModerator = false,
    this.emailVerified = false,
  });

  final String id;
  final String name;
  final bool onlineVisible;
  final String? bio;
  final String? photoId;
  final String? photoStatus;
  final bool isModerator;
  final bool emailVerified;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'].toString(),
        name: json['display_name'] as String,
        onlineVisible: json['online_visible'] as bool,
        bio: json['bio'] as String?,
        photoId: json['photo_id']?.toString(),
        photoStatus: json['photo_status'] as String?,
        isModerator: json['is_moderator'] == true,
        emailVerified: json['email_verified'] == true,
      );
}

class OnlinePerson {
  const OnlinePerson({required this.id, required this.name, this.bio, this.photoId});

  final String id;
  final String name;
  final String? bio;
  final String? photoId;

  factory OnlinePerson.fromJson(Map<String, dynamic> json) => OnlinePerson(
        id: json['id'].toString(),
        name: json['display_name'] as String,
        bio: json['bio'] as String?,
        photoId: json['photo_id']?.toString(),
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

class PendingPhoto {
  const PendingPhoto({required this.id, required this.userId, required this.name, required this.revision});
  final String id;
  final String userId;
  final String name;
  final String revision;

  factory PendingPhoto.fromJson(Map<String, dynamic> json) => PendingPhoto(
    id: json['id'].toString(),
    userId: json['user_id'].toString(),
    name: json['display_name'] as String,
    revision: json['revision'] as String,
  );
}

class PendingReport {
  const PendingReport({
    required this.id, required this.reporterName, required this.reason,
    this.reportedName, this.details,
  });

  final String id;
  final String reporterName;
  final String? reportedName;
  final String reason;
  final String? details;

  factory PendingReport.fromJson(Map<String, dynamic> json) => PendingReport(
    id: json['id'].toString(),
    reporterName: json['reporter_name'] as String,
    reportedName: json['reported_name'] as String?,
    reason: json['reason'] as String,
    details: json['details'] as String?,
  );
}
