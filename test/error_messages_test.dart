import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:squad_hq/core/error/error_messages.dart';

void main() {
  test('Network problems read as "offline", not a raw exception', () {
    expect(
      friendlyErrorMessage(AuthRetryableFetchException(message: 'ClientException: Failed host lookup')),
      offlineMessage,
    );
    expect(
      friendlyErrorMessage(Exception("SocketException: Failed host lookup: 'x.supabase.co'")),
      offlineMessage,
    );
    expect(friendlyErrorMessage(Exception('ClientException: Connection closed')), offlineMessage);
  });

  test('Other errors keep their own message', () {
    expect(isNetworkError(Exception('Only a team admin can edit this match')), isFalse);
    expect(
      friendlyErrorMessage(Exception('Only a team admin can edit this match')),
      contains('Only a team admin'),
    );
  });
}
