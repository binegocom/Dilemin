import '../../core/models.dart';

/// Combines incoming pages with the already-visible timeline, preserving
/// previously loaded history when the newest page is refreshed.
List<ChatMessage> mergeMessagePages(
  List<ChatMessage> existing,
  List<ChatMessage> incoming,
) {
  final byId = <String, ChatMessage>{
    for (final message in existing) message.id: message,
    for (final message in incoming) message.id: message,
  };
  final result = byId.values.toList(growable: false);
  result.sort((a, b) {
    final left = BigInt.parse(a.id);
    final right = BigInt.parse(b.id);
    return right.compareTo(left);
  });
  return result;
}
