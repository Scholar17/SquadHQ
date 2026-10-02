import 'package:supabase_flutter/supabase_flutter.dart' show AuthRetryableFetchException;

const offlineMessage = "You're offline. Check your connection and try again.";

/// Signs of a network problem rather than a real error: Supabase's session
/// refresh failing (AuthRetryableFetchException — it retries on its own),
/// or the HTTP client failing to connect at all.
const _networkSignals = [
  'SocketException',
  'ClientException',
  'Failed host lookup',
  'Connection closed',
  'Connection refused',
  'Connection reset',
  'Network is unreachable',
  'timed out',
];

bool isNetworkError(Object error) =>
    error is AuthRetryableFetchException ||
    _networkSignals.any(error.toString().contains);

/// A message fit for a snackbar: [offlineMessage] for network problems
/// instead of a raw exception dump, the error's own text otherwise.
String friendlyErrorMessage(Object error) =>
    isNetworkError(error) ? offlineMessage : error.toString();
