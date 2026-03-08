import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/core/services/api_service.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';

class SafePathSchedulerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const SafePathSchedulerScreen({super.key, this.onBack});

  @override
  State<SafePathSchedulerScreen> createState() => _SafePathSchedulerScreenState();
}

class _SafePathSchedulerScreenState extends State<SafePathSchedulerScreen> {
  final List<String> _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  final List<String> _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<int> _selectedDays = {};

  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _checkpointSearchController = TextEditingController();

  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;
  bool _isBeaconActive = false;
  bool _isSendingPing = false;
  bool _isLoadingPredictions = false;
  Timer? _pingTimer;
  Timer? _placesDebounce;
  int _trustedContactsCount = 0;
  String _beaconStatus = 'Inactive';
  String _placesErrorMessage = '';
  bool _authSearchHintShown = false;
  String _placesSessionToken = '';
  final List<Map<String, dynamic>> _placePredictions = [];
  final List<Map<String, dynamic>> _selectedCheckpoints = [];

  @override
  void initState() {
    super.initState();
    _placesSessionToken = _newPlacesSessionToken();
    _loadTrustedContacts();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _placesDebounce?.cancel();
    _tripNameController.dispose();
    _checkpointSearchController.dispose();
    super.dispose();
  }

  String _newPlacesSessionToken() {
    return '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
  }

  Future<void> _loadTrustedContacts() async {
    final contacts = await AuthService.loadTrustedContacts();
    if (!mounted) return;
    setState(() {
      _trustedContactsCount = contacts.length;
    });
  }

  String _timeAs24Hour() {
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final minute = _selectedTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _onCheckpointQueryChanged(String raw) {
    final query = raw.trim();
    _placesDebounce?.cancel();

    if (_selectedCheckpoints.length >= 3) {
      setState(() {
        _placePredictions.clear();
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _placePredictions.clear();
        _isLoadingPredictions = false;
        _placesErrorMessage = '';
        _authSearchHintShown = false;
      });
      return;
    }

    _placesDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadPlacePredictions(query);
    });
  }

  Future<void> _loadPlacePredictions(String query) async {
    final jwt = await AuthService.getToken();
    if (!mounted) return;

    if (jwt.isEmpty) {
      setState(() {
        _isLoadingPredictions = false;
        _placePredictions.clear();
        _placesErrorMessage = 'Checkpoint search requires login token.';
      });

      if (!_authSearchHintShown) {
        _authSearchHintShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: const Text('Please login again. Autocomplete needs a valid session.'),
          ),
        );
      }
      return;
    }

    _authSearchHintShown = false;

    setState(() {
      _isLoadingPredictions = true;
      _placesErrorMessage = '';
    });

    try {
      final predictions = await ApiService.fetchPlacesAutocomplete(
        query: query,
        jwt: jwt,
        sessionToken: _placesSessionToken,
      );

      if (!mounted) return;
      if (_checkpointSearchController.text.trim() != query) return;

      setState(() {
        _placePredictions
          ..clear()
          ..addAll(predictions);
        if (predictions.isEmpty && query.length >= 2) {
          _placesErrorMessage = 'No places found for "$query".';
        }
      });
    } catch (error, stackTrace) {
      // Surface backend/places failures so users are not left with a blank list.
      print('[SafePath] Autocomplete failed: $error');
      print('[SafePath] Autocomplete stack: $stackTrace');

      if (!mounted) return;
      setState(() {
        _placePredictions.clear();
        _placesErrorMessage = 'Failed to fetch places: $error';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Failed to fetch places: $error'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingPredictions = false;
      });
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    if (_selectedCheckpoints.length >= 3) return;

    final jwt = await AuthService.getToken();
    if (jwt.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to resolve place details.')),
      );
      return;
    }

    final placeId = (prediction['placeId'] ?? '').toString();
    if (placeId.isEmpty) return;

    try {
      final place = await ApiService.fetchPlaceDetails(
        placeId: placeId,
        jwt: jwt,
        sessionToken: _placesSessionToken,
      );

      final lat = (place['lat'] as num?)?.toDouble();
      final lng = (place['lng'] as num?)?.toDouble();
      final name = (place['name'] ?? prediction['mainText'] ?? prediction['description'] ?? 'Checkpoint')
          .toString()
          .trim();

      if (lat == null || lng == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not resolve coordinates for that place.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        final exists = _selectedCheckpoints.any((cp) => cp['placeId'] == placeId);
        if (!exists) {
          _selectedCheckpoints.add({
            'placeId': placeId,
            'name': name,
            'lat': lat,
            'lng': lng,
            'address': (place['address'] ?? prediction['description'] ?? '').toString(),
          });
        }

        _checkpointSearchController.clear();
        _placePredictions.clear();
        if (_selectedCheckpoints.length >= 3) {
          _placesDebounce?.cancel();
        }
      });

      _placesSessionToken = _newPlacesSessionToken();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch place details. Try again.')),
      );
    }
  }

  void _removeCheckpoint(String placeId) {
    setState(() {
      _selectedCheckpoints.removeWhere((cp) => cp['placeId'] == placeId);
    });
  }

  Future<void> _saveSchedule() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one recurring day.')),
      );
      return;
    }

    if (_selectedCheckpoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one precise checkpoint.')),
      );
      return;
    }

    final jwt = await AuthService.getToken();
    if (jwt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login again to save your SafePath.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final payload = {
        'tripName': _tripNameController.text.trim().isEmpty
            ? 'SafePath Trip'
            : _tripNameController.text.trim(),
        'activeDays': _selectedDays.toList()..sort(),
        'startTime': _timeAs24Hour(),
        'checkpoints': _selectedCheckpoints
          .map((cp) => {
              'name': cp['name'],
              'lat': cp['lat'],
              'lng': cp['lng'],
            })
          .toList(),
      };

      await ApiService.saveSafePathSchedule(payload: payload, jwt: jwt);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SafePath schedule saved successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save schedule: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _toggleBeacon() async {
    if (_isBeaconActive) {
      _pingTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isBeaconActive = false;
        _beaconStatus = 'Stopped';
      });
      return;
    }

    final jwt = await AuthService.getToken();
    if (jwt.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first to start live beacon.')),
      );
      return;
    }

    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    if (!mounted) return;
    setState(() {
      _isBeaconActive = true;
      _beaconStatus = 'Starting...';
    });

    await _sendPingNow();
    _pingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendPingNow();
    });
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required for live beacon.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _sendPingNow() async {
    if (_isSendingPing) return;

    final jwt = await AuthService.getToken();
    if (jwt.isEmpty) {
      if (!mounted) return;
      setState(() {
        _beaconStatus = 'Auth missing';
      });
      return;
    }

    _isSendingPing = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await ApiService.sendSafePathPing(
        latitude: position.latitude,
        longitude: position.longitude,
        jwt: jwt,
      );

      if (!mounted) return;
      setState(() {
        _beaconStatus = 'Live: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _beaconStatus = 'Ping failed';
      });
    } finally {
      _isSendingPing = false;
    }
  }

  Future<void> _handleBack() async {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    await Navigator.of(context).maybePop();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: AppColors.surfaceElevated.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Widget _buildCheckpointPicker() {
    final reachedMax = _selectedCheckpoints.length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _checkpointSearchController,
          enabled: !reachedMax,
          onChanged: _onCheckpointQueryChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: reachedMax
                ? 'Max 3 checkpoints selected'
                : 'Search checkpoint (Uber-style place search)',
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: AppColors.surfaceElevated.withOpacity(0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            suffixIcon: _isLoadingPredictions
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          ),
        ),
        if (_placePredictions.isNotEmpty && !reachedMax) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border.withOpacity(0.35)),
            ),
            child: ListView.separated(
              itemCount: _placePredictions.length.clamp(0, 5),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => Divider(color: AppColors.border.withOpacity(0.2), height: 1),
              itemBuilder: (context, index) {
                final item = _placePredictions[index];
                return ListTile(
                  dense: true,
                  onTap: () => _selectPrediction(item),
                  leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  title: Text(
                    (item['mainText'] ?? item['description'] ?? '').toString(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    (item['secondaryText'] ?? '').toString(),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
        if (_selectedCheckpoints.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedCheckpoints.map((cp) {
              final name = (cp['name'] ?? 'Checkpoint').toString();
              final placeId = (cp['placeId'] ?? '').toString();
              return InputChip(
                label: Text(name, overflow: TextOverflow.ellipsis),
                onDeleted: placeId.isEmpty ? null : () => _removeCheckpoint(placeId),
                deleteIconColor: AppColors.alert,
                backgroundColor: AppColors.primary.withOpacity(0.15),
                labelStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          reachedMax
              ? 'Max 3 checkpoints reached. Remove one to add another.'
              : '${_selectedCheckpoints.length}/3 checkpoints selected',
          style: TextStyle(
            color: reachedMax ? const Color(0xFFF59E0B) : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_placesErrorMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _placesErrorMessage,
            style: TextStyle(
              color: Colors.red.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDaysRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(_days.length, (index) {
        final isSelected = _selectedDays.contains(index);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedDays.remove(index);
              } else {
                _selectedDays.add(index);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceElevated.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _days[index],
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimePicker() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.2), // Subtle deep blue matching screenshot
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Custom Highlight overlay
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          CupertinoTheme(
            data: const CupertinoThemeData(
              brightness: Brightness.dark,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800, // Matches bold style from wireframe
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: DateTime.now(),
              use24hFormat: true, // Typically better suited for modern schedulers unless AM/PM requested
              onDateTimeChanged: (DateTime newDateTime) {
                setState(() {
                  _selectedTime = TimeOfDay.fromDateTime(newDateTime);
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox() {
    if (_trustedContactsCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0E241B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF34D399).withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$_trustedContactsCount trusted contact(s) ready for SafePath alerts.',
                style: TextStyle(
                  color: const Color(0xFF34D399).withOpacity(0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1B16), // Dark amber subtle background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No trusted contacts yet. Add them first.',
              style: TextStyle(
                color: const Color(0xFFF59E0B).withOpacity(0.9),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 64, // Massive touch target
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveSchedule,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FFD1), // Neon Cyan exactly matching wireframe
          foregroundColor: const Color(0xFF022C22), // Deep dark green/black for high contrast text
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Text(
                'Save SafePath Schedule',
                style: TextStyle(
                  fontWeight: FontWeight.w900, // Extra bold
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildBeaconButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _toggleBeacon,
        icon: Icon(_isBeaconActive ? Icons.stop_circle_outlined : Icons.gps_fixed_rounded),
        label: Text(_isBeaconActive ? 'Stop Live Beacon' : 'Start Live Beacon'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(
            color: _isBeaconActive
                ? const Color(0xFFF97316).withOpacity(0.8)
                : AppColors.primary.withOpacity(0.8),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  List<String> get _selectedDayNames {
    final result = _selectedDays.toList()..sort();
    return result.map((index) => _dayLabels[index]).toList();
  }

  String get _selectedDaysPreview {
    final names = _selectedDayNames;
    if (names.isEmpty) return 'No days selected';
    return names.join(', ');
  }

  Widget _buildSelectionPreview() {
    return Text(
      'Selected days: $_selectedDaysPreview | Start time: ${_timeAs24Hour()}',
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SafePath Scheduler',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: _handleBack,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Trip Name'),
              const SizedBox(height: 12),
              _buildTextField(
                hint: 'e.g. Going to school',
                controller: _tripNameController,
              ),

              const SizedBox(height: 32),
              _buildSectionTitle('Recurring Days'),
              const SizedBox(height: 16),
              _buildDaysRow(),
              const SizedBox(height: 10),
              _buildSelectionPreview(),

              const SizedBox(height: 32),
              _buildSectionTitle('Start Time'),
              const SizedBox(height: 16),
              _buildTimePicker(),

              const SizedBox(height: 32),
              _buildSectionTitle('Checkpoints'),
              const SizedBox(height: 12),
              _buildCheckpointPicker(),

              const SizedBox(height: 32),
              _buildSectionTitle('Notify Priority Contacts'),
              const SizedBox(height: 4),
              const Text(
                'Add trusted contacts first in the Contacts tab.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildWarningBox(),

              const SizedBox(height: 48),
              _buildSaveButton(),
              const SizedBox(height: 12),
              _buildBeaconButton(),
              const SizedBox(height: 8),
              Text(
                'Beacon status: $_beaconStatus',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}
