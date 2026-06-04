import 'package:flutter_test/flutter_test.dart';
import 'package:novella/data/models/community.dart';

void main() {
  test('parses deleted author flags from feed and reply payloads', () {
    final feedItem = CommunityFeedItem.fromJson({
      'Id': 1,
      'BoardKey': 'general',
      'BoardName': '综合',
      'Title': '帖子标题',
      'AuthorName': 'Alice',
      'AuthorIsDeleted': true,
    });

    final reply = CommunityThreadReply.fromJson({
      'Id': 2,
      'AuthorName': 'Bob',
      'AuthorIsDeleted': true,
      'ReplyTo': {'Id': 1, 'AuthorName': 'Alice', 'AuthorIsDeleted': true},
    });

    expect(feedItem.authorIsDeleted, isTrue);
    expect(reply.authorIsDeleted, isTrue);
    expect(reply.replyTo?.authorIsDeleted, isTrue);
  });

  test('defaults missing deleted author flags to false', () {
    final feedItem = CommunityFeedItem.fromJson({
      'Id': 1,
      'BoardKey': 'general',
      'BoardName': '综合',
      'Title': '帖子标题',
      'AuthorName': 'Alice',
    });

    final reply = CommunityThreadReply.fromJson({
      'Id': 2,
      'AuthorName': 'Bob',
      'ReplyTo': {'Id': 1, 'AuthorName': 'Alice'},
    });

    expect(feedItem.authorIsDeleted, isFalse);
    expect(reply.authorIsDeleted, isFalse);
    expect(reply.replyTo?.authorIsDeleted, isFalse);
  });
}
