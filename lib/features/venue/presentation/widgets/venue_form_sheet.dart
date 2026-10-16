import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../domain/entities/venue.dart';
import '../../domain/location_input.dart';
import '../../domain/maps_link.dart';
import '../../domain/usecases/save_venue.dart';

/// Add a venue to [teamId]'s list, or edit [initial]. Returns the saved
/// venue, or null if closed without saving. Only the name is required.
Future<Venue?> showVenueForm(BuildContext context, {required String teamId, Venue? initial}) {
  return showModalBottomSheet<Venue>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _VenueFormSheet(teamId: teamId, initial: initial),
  );
}

class _VenueFormSheet extends StatefulWidget {
  const _VenueFormSheet({required this.teamId, this.initial});

  final String teamId;
  final Venue? initial;

  @override
  State<_VenueFormSheet> createState() => _VenueFormSheetState();
}

class _VenueFormSheetState extends State<_VenueFormSheet> {
  static const _maxName = 80;
  static const _maxNotes = 300;

  late final _nameController = TextEditingController(text: widget.initial?.name);
  late final _mapsController = TextEditingController(text: widget.initial?.mapsUrl);
  late final _notesController = TextEditingController(text: widget.initial?.notes);
  late final _priceController = TextEditingController(text: _priceText(widget.initial?.pricePerHour));
  late final _latitudeController = TextEditingController(text: _coordinateText(widget.initial?.latitude));
  late final _longitudeController = TextEditingController(text: _coordinateText(widget.initial?.longitude));

  /// The location was filled from the Maps link, not typed: a new link may
  /// replace it. Typed numbers are never overwritten.
  bool _locationFromLink = false;

  /// A newly picked photo, not uploaded yet.
  Uint8List? _photoBytes;
  String? _photoExtension;

  /// The saved photo was taken off (without a new one).
  bool _photoRemoved = false;

  bool _saving = false;
  String? _error;

  static String? _coordinateText(double? value) =>
      value == null ? null : LocationInput.format(value);

  static String? _priceText(double? price) {
    if (price == null) return null;
    return price == price.roundToDouble() ? price.toInt().toString() : price.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _nameController.dispose();
    _mapsController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  String? get _nameError =>
      _name.length > _maxName ? 'Keep the name to $_maxName characters.' : null;

  /// Blank, or a Google Maps link.
  String? get _mapsError {
    final text = _mapsController.text.trim();
    if (text.isEmpty || MapsLink.parse(text) != null) return null;
    return 'Paste a Google Maps link — in Google Maps, tap Share, then Copy link.';
  }

  double? get _price => double.tryParse(_priceController.text.trim().replaceAll(',', ''));

  String? get _priceError {
    final text = _priceController.text.trim();
    if (text.isEmpty) return null;
    final price = _price;
    return price == null || price < 0 ? 'Enter a price, or leave it blank.' : null;
  }

  bool get _locationEmpty =>
      _latitudeController.text.trim().isEmpty && _longitudeController.text.trim().isEmpty;

  String? get _latitudeError {
    final text = _latitudeController.text.trim();
    if (text.isEmpty) return _longitudeController.text.trim().isEmpty ? null : 'Add the latitude too.';
    return LocationInput.latitude(text) == null ? 'A number from -90 to 90.' : null;
  }

  String? get _longitudeError {
    final text = _longitudeController.text.trim();
    if (text.isEmpty) return _latitudeController.text.trim().isEmpty ? null : 'Add the longitude too.';
    return LocationInput.longitude(text) == null ? 'A number from -180 to 180.' : null;
  }

  bool get _isValid =>
      _name.isNotEmpty &&
      _nameError == null &&
      _mapsError == null &&
      _priceError == null &&
      _latitudeError == null &&
      _longitudeError == null;

  /// A full Maps link that carries coordinates fills the location, read
  /// on the device. Share links (maps.app.goo.gl) don't carry them.
  void _onMapsChanged() {
    setState(() {});
    final uri = MapsLink.parse(_mapsController.text);
    if (uri == null || !(_locationEmpty || _locationFromLink)) return;
    if (MapsLink.coordinates(uri) case final coordinates?) {
      setState(() {
        _latitudeController.text = LocationInput.format(coordinates.latitude);
        _longitudeController.text = LocationInput.format(coordinates.longitude);
        _locationFromLink = true;
      });
    }
  }

  /// Typed by the admin. "13.7563, 100.5018" pasted into latitude (as
  /// Google Maps copies it) fills both.
  void _onLocationTyped() {
    final pair = LocationInput.pair(_latitudeController.text);
    setState(() {
      _locationFromLink = false;
      if (pair != null) {
        _latitudeController.text = LocationInput.format(pair.latitude);
        _longitudeController.text = LocationInput.format(pair.longitude);
      }
    });
  }

  bool get _hasPhoto =>
      _photoBytes != null || (widget.initial?.photoUrl != null && !_photoRemoved);

  Future<void> _pickPhoto() async {
    // Shrunk before upload: storage is the free tier's tight spot.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    if (!mounted) return;
    setState(() {
      _photoBytes = bytes;
      _photoExtension = name.endsWith('.png') ? 'png' : 'jpg';
      _photoRemoved = false;
    });
  }

  void _removePhoto() => setState(() {
        _photoBytes = null;
        _photoExtension = null;
        _photoRemoved = true;
      });

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final notes = _notesController.text.trim();
    final maps = _mapsController.text.trim();
    final result = await sl<SaveVenue>()(
      SaveVenueParams(
        id: widget.initial?.id,
        teamId: widget.teamId,
        name: _name,
        mapsUrl: maps.isEmpty ? null : maps,
        notes: notes.isEmpty ? null : notes,
        pricePerHour: _priceController.text.trim().isEmpty ? null : _price,
        latitude: LocationInput.latitude(_latitudeController.text),
        longitude: LocationInput.longitude(_longitudeController.text),
        photoBytes: _photoBytes,
        photoExtension: _photoExtension,
        previousPhotoPath: widget.initial?.photoPath,
        removePhoto: _photoRemoved,
      ),
    );
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (venue) => Navigator.of(context).pop(venue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPhoto = widget.initial?.photoUrl;
    return StickyActionSheet(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.initial == null ? 'New venue' : 'Edit venue',
                style: AppTextStyles.title(size: 18),
              ),
            ),
            IconButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
          ],
        ),
        const SizedBox(height: 8),
        _Label('NAME'),
        _Input(
          controller: _nameController,
          hintText: 'e.g. Arena 5 Rama 9',
          textCapitalization: TextCapitalization.words,
          errorText: _nameError,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 14),
        _Label('GOOGLE MAPS LINK', optional: true),
        _Input(
          controller: _mapsController,
          hintText: 'Paste the Share link',
          keyboardType: TextInputType.url,
          errorText: _mapsError,
          helperText: 'In Google Maps: open the place, tap Share, then Copy link.',
          onChanged: _onMapsChanged,
        ),
        const SizedBox(height: 14),
        _Label('LOCATION · FOR WEATHER FORECAST', optional: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Input(
                controller: _latitudeController,
                hintText: '13.7563',
                prefixText: 'Lat ',
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                errorText: _latitudeError,
                onChanged: _onLocationTyped,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Input(
                controller: _longitudeController,
                hintText: '100.5018',
                prefixText: 'Lng ',
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                errorText: _longitudeError,
                onChanged: _onLocationTyped,
              ),
            ),
          ],
        ),
        if (_locationEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              'On your phone: open Google Maps, touch and hold the pitch until a red pin '
              'drops. The numbers like 13.7563, 100.5018 appear at the top or in the card '
              'below; tap them to copy, then paste into Lat. Both boxes fill. '
              '(On a computer, right-click the pitch and click the numbers.)',
              style: AppTextStyles.body(size: 12, color: AppColors.textMuted, height: 1.4),
            ),
          ),
        const SizedBox(height: 14),
        _Label('PHOTO', optional: true),
        if (_hasPhoto)
          ClipRRect(
            borderRadius: AppRadius.lg,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _photoBytes != null
                  ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                  : Image.network(
                      initialPhoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: AppColors.card),
                    ),
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _pickPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(_hasPhoto ? 'Change photo' : 'Add photo'),
            ),
            if (_hasPhoto)
              TextButton(
                onPressed: _saving ? null : _removePhoto,
                child: Text('Remove', style: TextStyle(color: AppColors.textMuted)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _Label('NOTES', optional: true),
        _Input(
          controller: _notesController,
          hintText: 'Pitch number, parking, shoes…',
          maxLines: 3,
          maxLength: _maxNotes,
          textCapitalization: TextCapitalization.sentences,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 6),
        _Label('PRICE PER HOUR', optional: true),
        _Input(
          controller: _priceController,
          hintText: 'For reference — bills are entered separately',
          prefixText: '฿ ',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [MoneyInputFormatter()],
          errorText: _priceError,
          onChanged: () => setState(() {}),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(error, style: AppTextStyles.body(size: 12.5, color: AppColors.accent700)),
        ],
      ],
      action: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: _isValid && !_saving ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onDark,
            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onDark),
                )
              : Text(
                  widget.initial == null ? 'Save venue' : 'Save changes',
                  style: AppTextStyles.title(size: 14, color: AppColors.onDark),
                ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        optional ? '$text · OPTIONAL' : text,
        style: AppTextStyles.label(color: AppColors.textMuted),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.errorText,
    this.helperText,
    this.prefixText,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.maxLength,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;
  final String? errorText;
  final String? helperText;
  final String? prefixText;
  final TextInputType? keyboardType;
  final List<MoneyInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final rounded = maxLines == 1 ? AppRadius.pill : AppRadius.lg;
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hintText,
        prefixText: prefixText,
        errorText: errorText,
        errorMaxLines: 2,
        helperText: helperText,
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: rounded,
          borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
        ),
      ),
    );
  }
}
