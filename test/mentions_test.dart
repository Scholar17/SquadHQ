import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/comments/domain/entities/mention.dart';

void main() {
  const aung = '00000000-0000-0000-0000-000000000002';
  const min = '00000000-0000-0000-0000-000000000003';
  const members = [
    MentionMember(id: 'me', name: 'Test Player', username: 'tester'),
    MentionMember(id: aung, name: 'Aung Ko', username: 'AungKo'),
    MentionMember(id: min, name: 'Min Thu', username: 'minthu'),
  ];

  group('encodeMentions', () {
    test('a member\'s @username, any case, becomes their id', () {
      expect(encodeMentions('@aungko and @MINTHU, bibs?', members), '<@$aung> and <@$min>, bibs?');
    });

    test('unknown names and email addresses stay as typed', () {
      expect(encodeMentions('@nobody mail me@aungko.com', members), '@nobody mail me@aungko.com');
    });

    test('a longer name is not a member\'s', () {
      expect(encodeMentions('@aungko2', members), '@aungko2');
    });
  });

  group('mentionParts', () {
    test('markers show as the member\'s current username', () {
      final parts = mentionParts('Hi <@$aung>!', members);
      expect(parts.map((p) => p.text).join(), 'Hi @AungKo!');
      expect(parts[1].memberId, aung);
    });

    test('someone no longer in the team shows as @someone', () {
      expect(
        plainMentions('<@00000000-0000-0000-0000-000000000009> left', members),
        '@someone left',
      );
    });

    test('encoding then showing gives back what was typed', () {
      const typed = 'Thanks @AungKo and @minthu';
      expect(plainMentions(encodeMentions(typed, members), members), typed);
    });
  });

  group('suggestions', () {
    test('the @partial right before the cursor', () {
      expect(mentionQueryAt('Bibs @au', 8), (start: 5, query: 'au'));
      expect(mentionQueryAt('Bibs @', 6), (start: 5, query: ''));
      expect(mentionQueryAt('me@au', 5), isNull);
      expect(mentionQueryAt('@au done', 8), isNull);
    });

    test('by username first, then by any word of the name; never you', () {
      expect(mentionSuggestions(members, 'thu', me: 'me').map((m) => m.id), [min]);
      expect(mentionSuggestions(members, 'a', me: 'me').map((m) => m.id), [aung]);
      expect(mentionSuggestions(members, '', me: 'me').map((m) => m.id), [aung, min]);
      expect(mentionSuggestions(members, 'test', me: 'me'), isEmpty);
    });
  });
}
