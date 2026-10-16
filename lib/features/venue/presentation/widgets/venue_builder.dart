import 'package:flutter/widgets.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/entities/venue.dart';
import '../../domain/usecases/get_venue.dart';

/// Loads [venueId] and builds with it — null while it loads, or if it
/// can't (the match still shows its venue name). [reload] fetches it
/// again, e.g. after it's been edited.
class VenueBuilder extends StatefulWidget {
  const VenueBuilder({super.key, required this.venueId, required this.builder});

  final String venueId;
  final Widget Function(BuildContext context, Venue? venue, VoidCallback reload) builder;

  @override
  State<VenueBuilder> createState() => _VenueBuilderState();
}

class _VenueBuilderState extends State<VenueBuilder> {
  Venue? _venue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VenueBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.venueId != widget.venueId) {
      _venue = null;
      _load();
    }
  }

  Future<void> _load() async {
    final venueId = widget.venueId;
    final result = await sl<GetVenue>()(venueId);
    if (!mounted || venueId != widget.venueId) return;
    result.fold((_) {}, (venue) => setState(() => _venue = venue));
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _venue, _load);
}
