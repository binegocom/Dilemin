import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'app_config.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode);
  final int statusCode;
}

class ApiClient {
  ApiClient({required http.Client client}) : _client = client;

  final http.Client _client;
  String? token;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, AppConfig.baseUri.resolve(path));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final streamed = await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode);
    }
    if (response.body.isEmpty) return const {};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid API response.');
    }
    return decoded;
  }

  Future<String> authorizeBroadcast({
    required String socketId,
    required String channelName,
  }) async {
    final response = await _send('POST', '/api/broadcasting/auth', body: {
      'socket_id': socketId,
      'channel_name': channelName,
    });
    final auth = response['auth'];
    if (auth is! String || auth.isEmpty) {
      throw const FormatException('Invalid broadcast authorization.');
    }
    return auth;
  }

  Future<(String, SessionUser)> login(String email, String password) async {
    final json = await _send('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
    });
    return (json['token'] as String, SessionUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<(String, SessionUser)> register({
    required String email,
    required String password,
    required String name,
    required String birthday,
  }) async {
    final json = await _send('POST', '/api/v1/auth/register', body: {
      'display_name': name,
      'email': email,
      'password': password,
      'date_of_birth': birthday,
    });
    return (json['token'] as String, SessionUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<void> requestPasswordRecovery({required String email, required String locale}) async {
    await _send('POST', '/api/v1/auth/password/request', body: {
      'email': email, 'locale': locale,
    });
  }

  Future<void> confirmPasswordRecovery({
    required String email, required String code, required String password,
  }) async {
    await _send('POST', '/api/v1/auth/password/confirm', body: {
      'email': email, 'code': code, 'password': password,
    });
  }

  Future<SessionUser> me() async {
    final json = await _send('GET', '/api/v1/auth/me');
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<List<OnlinePerson>> onlinePeople() async {
    final json = await _send('GET', '/api/v1/discovery/online');
    return (json['data'] as List<dynamic>)
        .map((value) => OnlinePerson.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<OnlinePerson> person(String id) async {
    final json = await _send('GET', '/api/v1/users/${Uri.encodeComponent(id)}');
    return OnlinePerson.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> heartbeat() async { await _send('POST', '/api/v1/presence/heartbeat'); }
  Future<void> offline() async { await _send('POST', '/api/v1/presence/offline'); }

  Future<SessionUser> visibility(bool visible) async {
    final json = await _send('PATCH', '/api/v1/account/visibility', body: {
      'online_visible': visible,
    });
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<SessionUser> updateProfile(String name, String bio) async {
    final json = await _send('PATCH', '/api/v1/account/profile', body: {
      'display_name': name,
      'bio': bio,
    });
    return SessionUser.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<List<ConversationPreview>> conversations() async {
    final json = await _send('GET', '/api/v1/conversations');
    return (json['data'] as List<dynamic>)
        .map((value) => ConversationPreview.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String> startConversation(String personId) async {
    final json = await _send('POST', '/api/v1/conversations', body: {
      'recipient_id': int.parse(personId),
    });
    return json['id'].toString();
  }

  Future<List<ChatMessage>> messages(String conversationId, {String? beforeId}) async {
    final path = '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages';
    final json = await _send('GET', beforeId == null ? path : '$path?before_id=${Uri.encodeComponent(beforeId)}');
    return (json['data'] as List<dynamic>)
        .map((value) => ChatMessage.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> markMessagesRead(String conversationId, String messageId) async {
    await _send('POST', '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/read',
        body: {'message_id': int.parse(messageId)});
  }

  Future<String> sendMessage(String conversationId, String body, {String? clientId}) async {
    final json = await _send('POST', '/api/v1/conversations/${Uri.encodeComponent(conversationId)}/messages', body: {
      'body': body,
      'client_id': clientId ?? const Uuid().v4(),
    });
    return json['id'].toString();
  }

  Future<List<OnlinePerson>> blockedPeople() async {
    final json = await _send('GET', '/api/v1/account/blocked');
    return (json['data'] as List<dynamic>)
        .map((value) => OnlinePerson.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> unblock(String personId) async {
    await _send('DELETE', '/api/v1/users/${Uri.encodeComponent(personId)}/block');
  }

  Future<List<PendingReport>> pendingReports() async {
    final json = await _send('GET', '/api/v1/moderation/reports');
    return (json['data'] as List<dynamic>)
        .map((value) => PendingReport.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> reviewReport(String id, bool dismissed) async {
    await _send('POST', '/api/v1/moderation/reports/${Uri.encodeComponent(id)}/review', body: {
      'decision': dismissed ? 'dismissed' : 'reviewed',
    });
  }

  Future<void> block(String personId) async {
    await _send('POST', '/api/v1/users/${Uri.encodeComponent(personId)}/block');
  }

  Future<void> report(String personId, String reason, {String? details}) async {
    await _send('POST', '/api/v1/users/${Uri.encodeComponent(personId)}/report', body: {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
  }

  Future<void> deleteAccount(String password) async {
    await _send('DELETE', '/api/v1/account', body: {'password': password});
  }


  Future<void> requestEmailVerificationCode(String locale) async {
    await _send('POST', '/api/v1/auth/email/request', body: {'locale': locale});
  }

  Future<SessionUser> verifyEmailCode(String code) async {
    final data = await _send('POST', '/api/v1/auth/email/confirm', body: {'code': code});
    return SessionUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<SessionUser> uploadPhoto(XFile file) async {
    final request = http.MultipartRequest('POST', AppConfig.baseUri.resolve('/api/v1/account/photo'));
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', file.path, filename: file.name));
    final streamed = await _client.send(request).timeout(const Duration(seconds: 35));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 201) throw ApiException(response.statusCode);
    return SessionUser.fromJson((jsonDecode(response.body) as Map<String, dynamic>)['user'] as Map<String, dynamic>);
  }

  Future<SessionUser> deletePhoto() async {
    final response = await _send('DELETE', '/api/v1/account/photo');
    return SessionUser.fromJson(response['user'] as Map<String, dynamic>);
  }

  Future<Uint8List> photoBytes(String userId) => _readImage(
    '/api/v1/users/${Uri.encodeComponent(userId)}/photo',
  );

  Future<Uint8List> moderationPhotoBytes(String photoId) => _readImage(
    '/api/v1/moderation/photos/${Uri.encodeComponent(photoId)}',
  );

  Future<Uint8List> _readImage(String path) async {
    final response = await _client.get(AppConfig.baseUri.resolve(path),
      headers: {'Accept': 'image/jpeg', if (token != null) 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw ApiException(response.statusCode);
    if (response.bodyBytes.length > 8 * 1024 * 1024) throw const FormatException('Image too large.');
    return response.bodyBytes;
  }

  Future<List<PendingPhoto>> pendingPhotos() async {
    final result = await _send('GET', '/api/v1/moderation/photos');
    return (result['data'] as List<dynamic>)
        .map((item) => PendingPhoto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> reviewPhoto(PendingPhoto photo, bool approved) async {
    await _send('POST', '/api/v1/moderation/photos/${Uri.encodeComponent(photo.id)}/review', body: {
      'revision': photo.revision,
      'decision': approved ? 'approved' : 'rejected',
    });
  }

  Future<List<DeviceSession>> deviceSessions() async {
    final response = await _send('GET', '/api/v1/auth/sessions');
    return (response['data'] as List<dynamic>)
        .map((value) => DeviceSession.fromJson(value as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> revokeSession(String sessionId) async {
    await _send('DELETE', '/api/v1/auth/sessions/${Uri.encodeComponent(sessionId)}');
  }

  Future<int> revokeOtherSessions(String password) async {
    final response = await _send('POST', '/api/v1/auth/sessions/revoke-others',
        body: {'password': password});
    return response['count'] as int;
  }

  // Stream the export to a temporary file instead of buffering private messages in memory.
  Future<void> exportAccount(String password, File destination) async {
    final request = http.Request('POST', AppConfig.baseUri.resolve('/api/v1/account/export'));
    request.headers['Accept'] = 'application/json';
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.body = jsonEncode({'password': password});
    final response = await _client.send(request).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw ApiException(response.statusCode);
    }
    final sink = destination.openWrite();
    try {
      await for (final chunk in response.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  Future<void> logout() async { await _send('POST', '/api/v1/auth/logout'); }

  void close() => _client.close();
}
