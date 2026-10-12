import 'package:dilemin/core/models.dart';
import 'package:dilemin/features/chat/message_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage message(int id) => ChatMessage(
  id: '$id',
  senderId: '2',
  body: 'Message $id',
  createdAt: DateTime.utc(2026, 10, 12),
);

void main() {
  test('refreshing newest messages preserves older history', () {
    final previouslyLoaded = [message(10), message(9), message(8), message(3), message(2)];
    final fresh = [message(12), message(11), message(10), message(9)];
    final merged = mergeMessagePages(previouslyLoaded, fresh);
    expect(merged.map((m) => m.id), ['12', '11', '10', '9', '8', '3', '2']);
  });

  test('loading an overlapping older page never duplicates message IDs', () {
    final previous = [message(100), message(99), message(98)];
    final page = [message(98), message(97), message(96)];
    final merged = mergeMessagePages(previous, page);
    expect(merged.map((m) => m.id), ['100', '99', '98', '97', '96']);
  });

  test('supports IDs larger than IEEE 754 JavaScript integer precision', () {
    final first = ChatMessage(
      id: '9007199254740993', senderId: '1', body: 'Later',
      createdAt: DateTime.utc(2026, 10, 12),
    );
    final second = ChatMessage(
      id: '9007199254740992', senderId: '1', body: 'Earlier',
      createdAt: DateTime.utc(2026, 10, 12),
    );
    expect(mergeMessagePages([second], [first]).first.id, first.id);
  });
}
