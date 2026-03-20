import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' as image_picker;
import 'package:location/location.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:usafe_front_end/core/constants/app_colors.dart';
import 'package:usafe_front_end/features/auth/auth_service.dart';
import 'package:usafe_front_end/features/auth/community_report_service.dart';
import 'package:usafe_front_end/src/config/app_config.dart';

const String _communityPortalMapboxToken = mapboxPublicToken;

class CommunityReportsPortalScreen extends StatefulWidget {
  const CommunityReportsPortalScreen({super.key});

  @override
  State<CommunityReportsPortalScreen> createState() =>
      _CommunityReportsPortalScreenState();
}

class _CommunityReportsPortalScreenState
    extends State<CommunityReportsPortalScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationSearchController =
      TextEditingController();
  final image_picker.ImagePicker _imagePicker = image_picker.ImagePicker();
  final Location _location = Location();

  final Set<int> _selectedIssueIndices = <int>{};
  final List<File> _selectedImages = <File>[];
  final List<_PortalIssueType> _issueTypes = const <_PortalIssueType>[
    _PortalIssueType(
      icon: Icons.construction_rounded,
      title: 'Road Issue',
      description: 'Potholes, cracks, and damaged roads affecting safety.',
      color: Color(0xFFF59E0B),
    ),
    _PortalIssueType(
      icon: Icons.lightbulb_rounded,
      title: 'Street Lighting',
      description: 'Dark streets, broken lights, and low-visibility zones.',
      color: Color(0xFFEAB308),
    ),
    _PortalIssueType(
      icon: Icons.visibility_rounded,
      title: 'Suspicious Activity',
      description: 'Unusual behavior or activity reported by the community.',
      color: Color(0xFFEF4444),
    ),
    _PortalIssueType(
      icon: Icons.groups_rounded,
      title: 'Harassment',
      description: 'Unsafe encounters, intimidation, or harassment reports.',
      color: Color(0xFFEC4899),
    ),
    _PortalIssueType(
      icon: Icons.apartment_rounded,
      title: 'Infrastructure',
      description: 'Broken sidewalks, public assets, or unsafe structures.',
      color: Color(0xFF38BDF8),
    ),
    _PortalIssueType(
      icon: Icons.security_rounded,
      title: 'Security',
      description: 'Theft, break-ins, or vulnerable public areas.',
      color: Color(0xFFF97316),
    ),
    _PortalIssueType(
      icon: Icons.eco_rounded,
      title: 'Environmental',
      description: 'Pollution, illegal dumping, or environmental hazards.',
      color: Color(0xFF22C55E),
    ),
    _PortalIssueType(
      icon: Icons.broken_image_rounded,
      title: 'Vandalism',
      description:
          'Property damage, graffiti, or destruction of public assets.',
      color: Color(0xFFA855F7),
    ),
  ];

  Map<String, dynamic>? _currentUser;
  List<_CommunityPortalPost> _posts = <_CommunityPortalPost>[];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showComposer = false;
  String? _feedError;

  String? _selectedLocationLabel;
  Position? _selectedLocationPosition;

  MapboxMap? _mapController;
  PointAnnotationManager? _pointAnnotationManager;
  CircleAnnotationManager? _userLocationManager;
  CircleAnnotation? _userLocationAnnotation;
  LocationData? _currentPosition;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _debounce;
  int _suggestionRequestId = 0;
  String _searchSessionToken = '';
  bool _isSearchingSuggestions = false;
  bool _isPickingLocation = false;
  Position? _pendingPinnedPosition;
  Uint8List? _destinationMarkerBytes;
  List<Map<String, dynamic>> _locationSuggestions = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(_communityPortalMapboxToken);
    _refreshSearchSessionToken();
    _loadPortal();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationSearchController.dispose();
    _locationSubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPortal() async {
    setState(() {
      _isLoading = true;
      _feedError = null;
    });

    try {
      final currentUser = await AuthService.getCurrentUser();
      final myReports = await CommunityReportService.getMyReports();
      final myPosts = myReports
          .map((report) => _CommunityPortalPost.fromUserReport(
                report: report,
                fallbackUser: currentUser,
              ))
          .toList();

      final merged = <_CommunityPortalPost>[
        ..._seedPosts(),
        ...myPosts,
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _currentUser = currentUser;
        _posts = merged;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentUser = null;
        _posts = _seedPosts();
        _feedError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  List<_CommunityPortalPost> _seedPosts() {
    return <_CommunityPortalPost>[
      _CommunityPortalPost(
        id: 'seed-1',
        username: 'Ayesha K',
        avatarUrl: '',
        locationLabel: 'Main Street, Colombo 03',
        reportText:
            'Street lights are out near the bus stop. The area gets very dark after 8 PM, so please stay alert if you are walking alone.',
        issueTags: const <String>['Street Lighting'],
        createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
        likeCount: 18,
        comments: <_PostComment>[
          _PostComment(
            username: 'Nimal P',
            text: 'Saw this too. It has been dark for two nights now.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 24)),
          ),
        ],
      ),
      _CommunityPortalPost(
        id: 'seed-2',
        username: 'SafeWalk LK',
        avatarUrl: '',
        locationLabel: 'Kandy Lake Round',
        reportText:
            'Heavy traffic and poor sidewalk access on the lake side this evening. If possible, use the opposite lane or wait until traffic clears.',
        issueTags: const <String>['Road Issue', 'Infrastructure'],
        createdAt:
            DateTime.now().subtract(const Duration(hours: 2, minutes: 5)),
        likeCount: 32,
        comments: <_PostComment>[
          _PostComment(
            username: 'Tharushi M',
            text: 'Thanks for posting this. The crossing was blocked today.',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          _PostComment(
            username: 'User_197',
            text: 'A traffic officer arrived around 6:30 PM.',
            createdAt: DateTime.now().subtract(const Duration(minutes: 55)),
          ),
        ],
      ),
    ];
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.alert : AppColors.success,
      ),
    );
  }

  void _openComposer() => setState(() => _showComposer = true);

  void _closeComposer() => setState(() => _showComposer = false);

  String _displayNameFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'uSafe User';
    final first = '${user['firstName'] ?? ''}'.trim();
    final last = '${user['lastName'] ?? ''}'.trim();
    final full = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
    if (full.isNotEmpty) return full;
    final name = '${user['name'] ?? ''}'.trim();
    return name.isNotEmpty ? name : 'uSafe User';
  }

  String? _avatarUrlFromUser(Map<String, dynamic>? user) {
    if (user == null) return null;
    for (final key in const <String>[
      'picture',
      'photoUrl',
      'photoURL',
      'avatarUrl',
      'profileImage',
      'avatar',
      'imageUrl',
      'image',
    ]) {
      final value = '${user[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String _relativeTime(DateTime dateTime) {
    final delta = DateTime.now().difference(dateTime);
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _pickFromGallery() async {
    try {
      final images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (images.isEmpty) return;
      setState(() {
        _selectedImages.addAll(images.map((img) => File(img.path)));
      });
      _updateAutoGeneratedReport();
    } catch (_) {
      _showSnack('Unable to open gallery.', error: true);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: image_picker.ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo == null) return;
      setState(() => _selectedImages.add(File(photo.path)));
      _updateAutoGeneratedReport();
    } catch (_) {
      _showSnack('Unable to open camera.', error: true);
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
    _updateAutoGeneratedReport();
  }

  String _formatReportTimestamp(DateTime value) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  void _updateAutoGeneratedReport() {
    if (_selectedIssueIndices.isEmpty) {
      _descriptionController.clear();
      return;
    }

    final locationText = (_selectedLocationLabel ?? '').trim().isNotEmpty
        ? _selectedLocationLabel!.trim()
        : '[Auto-detected or User Input]';

    final report = StringBuffer()
      ..writeln('═══════════════════════════════════════')
      ..writeln('        COMMUNITY SAFETY REPORT')
      ..writeln('═══════════════════════════════════════')
      ..writeln()
      ..writeln('📅 Date: ${_formatReportTimestamp(DateTime.now())}')
      ..writeln('📍 Location: $locationText')
      ..writeln();

    if (_selectedIssueIndices.length == 1) {
      final issue = _issueTypes[_selectedIssueIndices.first];
      report
        ..writeln('🚨 REPORTED ISSUE:')
        ..writeln()
        ..writeln('1. ${issue.title}')
        ..writeln('   └─ ${issue.description}')
        ..writeln();
    } else {
      report.writeln(
          '🚨 MULTIPLE ISSUES REPORTED (${_selectedIssueIndices.length}):');
      report.writeln();
      var count = 1;
      for (final index in _selectedIssueIndices) {
        final issue = _issueTypes[index];
        report
          ..writeln('$count. ${issue.title}')
          ..writeln('   └─ ${issue.description}')
          ..writeln();
        count++;
      }
    }

    report
      ..writeln('───────────────────────────────────────')
      ..writeln('ADDITIONAL DETAILS:')
      ..writeln('Please add specific information about:')
      ..writeln('• Exact location/address')
      ..writeln('• Time of occurrence')
      ..writeln('• Severity level')
      ..writeln('• Any immediate dangers')
      ..writeln('• Additional context')
      ..writeln('───────────────────────────────────────');

    if (_selectedImages.isNotEmpty) {
      report.writeln();
      report
          .writeln('📸 ATTACHED EVIDENCE: ${_selectedImages.length} photo(s)');
    }

    _descriptionController.value = TextEditingValue(
      text: report.toString(),
      selection: TextSelection.collapsed(offset: report.length),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedLocationPosition == null || _selectedLocationLabel == null) {
      _showSnack('Choose a report location first.', error: true);
      return;
    }
    if (_selectedIssueIndices.isEmpty) {
      _showSnack('Select at least one issue type.', error: true);
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      _showSnack('Write a short community report.', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await CommunityReportService.submitReport(
        reportContent: _descriptionController.text.trim(),
        images: _selectedImages,
        location: _selectedLocationLabel,
        locationLat: _selectedLocationPosition!.lat.toDouble(),
        locationLng: _selectedLocationPosition!.lng.toDouble(),
        issueTypes: _selectedIssueIndices
            .map((index) => _issueTypes[index].title)
            .toList(),
      );

      if (result['success'] != true) {
        _showSnack(
          result['error']?.toString() ?? 'Unable to submit report.',
          error: true,
        );
        return;
      }

      final user = await AuthService.getCurrentUser();
      final newPost = _CommunityPortalPost(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        username: _displayNameFromUser(user),
        avatarUrl: _avatarUrlFromUser(user) ?? '',
        locationLabel: _selectedLocationLabel!,
        reportText: _descriptionController.text.trim(),
        imageUrls: _selectedImages.map((file) => file.path).toList(),
        issueTags: _selectedIssueIndices
            .map((index) => _issueTypes[index].title)
            .toList(),
        createdAt: DateTime.now(),
        likeCount: 0,
        comments: <_PostComment>[],
        isOwnedByCurrentUser: true,
      );

      if (!mounted) return;
      setState(() {
        _posts = <_CommunityPortalPost>[newPost, ..._posts];
        _selectedIssueIndices.clear();
        _selectedImages.clear();
        _descriptionController.clear();
        _showComposer = false;
      });
      _showSnack('Community report posted successfully.');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _toggleLike(_CommunityPortalPost post) {
    setState(() {
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
    });
  }

  Future<void> _addComment(_CommunityPortalPost post) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Add Comment',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Write a helpful update for this report',
            hintStyle: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    final userName = _displayNameFromUser(_currentUser);
    setState(() {
      post.comments.insert(
        0,
        _PostComment(
          username: userName,
          text: value,
          createdAt: DateTime.now(),
        ),
      );
    });
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapController = map;
    _pointAnnotationManager =
        await map.annotations.createPointAnnotationManager();
    _userLocationManager =
        await map.annotations.createCircleAnnotationManager();
    await _startUserLocationTracking();
  }

  Future<bool> _ensureLocationAccess() async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) return false;
    }
    PermissionStatus permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
    }
    return permission == PermissionStatus.granted;
  }

  Position _positionFromLocation(LocationData loc) =>
      Position(loc.longitude!, loc.latitude!);

  Future<void> _moveCameraToPosition(
    Position position, {
    double zoom = 14.8,
  }) async {
    if (_mapController == null) return;
    await _mapController!.flyTo(
      CameraOptions(center: Point(coordinates: position), zoom: zoom),
      MapAnimationOptions(duration: 900),
    );
  }

  CircleAnnotationOptions _buildUserLocationMarker(Position pos) =>
      CircleAnnotationOptions(
        geometry: Point(coordinates: pos),
        circleColor: AppColors.primary.value,
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.value,
        circleSortKey: 100,
      );

  Future<void> _syncUserLocationMarker(LocationData location) async {
    if (_userLocationManager == null ||
        location.latitude == null ||
        location.longitude == null) {
      return;
    }

    final position = _positionFromLocation(location);
    if (_userLocationAnnotation == null) {
      _userLocationAnnotation = await _userLocationManager!
          .create(_buildUserLocationMarker(position));
    } else {
      _userLocationAnnotation!.geometry = Point(coordinates: position);
      await _userLocationManager!.update(_userLocationAnnotation!);
    }
  }

  Future<void> _startUserLocationTracking() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;

    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 2000,
      distanceFilter: 5,
    );

    final initialLocation = await _location.getLocation();
    _currentPosition = initialLocation;
    await _syncUserLocationMarker(initialLocation);

    if (_selectedLocationPosition == null &&
        initialLocation.latitude != null &&
        initialLocation.longitude != null) {
      final current = Position(
        initialLocation.longitude!,
        initialLocation.latitude!,
      );
      await _moveCameraToPosition(current);
    }

    _locationSubscription?.cancel();
    _locationSubscription =
        _location.onLocationChanged.listen((location) async {
      if (!mounted || location.latitude == null || location.longitude == null) {
        return;
      }
      _currentPosition = location;
      await _syncUserLocationMarker(location);
    });
  }

  Future<void> _useCurrentLocation() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) {
      _showSnack('Location permission is required.', error: true);
      return;
    }
    final current = await _location.getLocation();
    if (current.latitude == null || current.longitude == null) {
      _showSnack('Unable to read current location.', error: true);
      return;
    }
    final position = Position(current.longitude!, current.latitude!);
    final label = await _labelForPosition(position);
    await _showDestinationPin(position);
    await _moveCameraToPosition(position);
    if (!mounted) return;
    setState(() {
      _selectedLocationPosition = position;
      _selectedLocationLabel = label;
      _locationSearchController.text = label;
    });
    _updateAutoGeneratedReport();
  }

  Future<String> _labelForPosition(Position position) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.lat.toDouble(),
        position.lng.toDouble(),
      );
      if (placemarks.isEmpty) {
        return 'Pinned (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
      }
      final place = placemarks.first;
      final seen = <String>{};
      final parts = <String>[];
      for (final raw in <String?>[
        place.street,
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
        place.postalCode,
        place.country,
      ]) {
        final value = (raw ?? '').trim();
        if (value.isEmpty) continue;
        final key = value.toLowerCase();
        if (seen.add(key)) {
          parts.add(value);
        }
      }
      if (parts.isEmpty) {
        return 'Pinned (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
      }
      return parts.join(', ');
    } catch (_) {
      return 'Pinned (${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)})';
    }
  }

  void _refreshSearchSessionToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256)).map((v) {
      return v.toRadixString(16).padLeft(2, '0');
    }).join();
    _searchSessionToken = '${bytes.substring(0, 8)}-${bytes.substring(8, 12)}-'
        '${bytes.substring(12, 16)}-${bytes.substring(16, 20)}-'
        '${bytes.substring(20, 32)}';
  }

  String _buildSearchBoxCommonParams() {
    final params = <String>[
      'access_token=$_communityPortalMapboxToken',
      'session_token=$_searchSessionToken',
      'limit=8',
      'language=en',
      'country=LK',
    ];
    if (_currentPosition?.longitude != null &&
        _currentPosition?.latitude != null) {
      params.add(
        'proximity=${_currentPosition!.longitude},${_currentPosition!.latitude}',
      );
    }
    return params.join('&');
  }

  Future<Map<String, dynamic>?> _geocodingFallbackSuggestion(
      String place) async {
    try {
      final results = await geocoding
          .locationFromAddress(place.trim())
          .timeout(const Duration(seconds: 8));
      if (results.isEmpty) return null;
      return <String, dynamic>{
        'name': place.trim(),
        'full_address': place.trim(),
        'feature_type': 'place',
        'source': 'geocoding_fallback',
        'fallback_lat': results.first.latitude,
        'fallback_lng': results.first.longitude,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    final trimmedQuery = query.trim();
    final requestId = ++_suggestionRequestId;

    if (trimmedQuery.isEmpty) {
      setState(() {
        _locationSuggestions = <Map<String, dynamic>>[];
        _isSearchingSuggestions = false;
      });
      return;
    }

    setState(() => _isSearchingSuggestions = true);

    try {
      var parsed = <Map<String, dynamic>>[];
      final fallback = await _geocodingFallbackSuggestion(trimmedQuery);
      if (fallback != null) {
        parsed = <Map<String, dynamic>>[fallback];
      } else {
        final url = Uri.parse(
          'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=${Uri.encodeComponent(trimmedQuery)}&${_buildSearchBoxCommonParams()}',
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final suggestions = data['suggestions'];
          parsed = suggestions is List
              ? suggestions
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
              : <Map<String, dynamic>>[];
        }
      }
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() => _locationSuggestions = parsed);
    } catch (_) {
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() => _locationSuggestions = <Map<String, dynamic>>[]);
    } finally {
      if (!mounted || requestId != _suggestionRequestId) return;
      setState(() => _isSearchingSuggestions = false);
    }
  }

  Future<Map<String, dynamic>?> _retrieveSuggestion(String mapboxId) async {
    final url = Uri.parse(
      'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
      '?access_token=$_communityPortalMapboxToken'
      '&session_token=$_searchSessionToken&language=en',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'];
    if (features is! List || features.isEmpty) return null;
    final feature = features.first;
    return feature is Map<String, dynamic>
        ? feature
        : Map<String, dynamic>.from(feature as Map);
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    FocusScope.of(context).unfocus();
    Position? position;
    final mapboxId = suggestion['mapbox_id']?.toString();
    if (mapboxId != null && mapboxId.isNotEmpty) {
      final feature = await _retrieveSuggestion(mapboxId);
      final coords =
          (feature?['geometry'] as Map<String, dynamic>?)?['coordinates'];
      if (coords is List && coords.length >= 2) {
        position = Position(
          (coords[0] as num).toDouble(),
          (coords[1] as num).toDouble(),
        );
      }
    }
    position ??=
        (suggestion['fallback_lng'] is num && suggestion['fallback_lat'] is num)
            ? Position(
                (suggestion['fallback_lng'] as num).toDouble(),
                (suggestion['fallback_lat'] as num).toDouble(),
              )
            : null;

    if (position == null) {
      _showSnack('Unable to resolve that location.', error: true);
      return;
    }

    final label = _suggestionLabel(suggestion);
    await _showDestinationPin(position);
    await _moveCameraToPosition(position);
    if (!mounted) return;
    setState(() {
      _selectedLocationPosition = position;
      _selectedLocationLabel = label;
      _locationSearchController.text = label;
      _locationSuggestions = <Map<String, dynamic>>[];
      _isPickingLocation = false;
    });
    _updateAutoGeneratedReport();
    _refreshSearchSessionToken();
  }

  String _suggestionLabel(Map<String, dynamic> suggestion) {
    final name = suggestion['name']?.toString().trim() ?? '';
    final address = (suggestion['full_address'] ??
                suggestion['place_formatted'] ??
                suggestion['address'])
            ?.toString()
            .trim() ??
        '';
    if (address.isEmpty) return name;
    if (name.isEmpty) return address;
    if (address.startsWith(name)) return address;
    return '$name, $address';
  }

  Future<Uint8List> _loadDestinationMarkerBytes() async {
    if (_destinationMarkerBytes != null) return _destinationMarkerBytes!;
    final bytes = await rootBundle.load('assets/red-pin bg r.png');
    _destinationMarkerBytes = bytes.buffer.asUint8List();
    return _destinationMarkerBytes!;
  }

  Future<void> _showDestinationPin(Position position) async {
    final manager = _pointAnnotationManager;
    if (manager == null) return;
    await manager.deleteAll();
    final markerBytes = await _loadDestinationMarkerBytes();
    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: position),
        image: markerBytes,
        iconSize: 0.2,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
  }

  Future<void> _enableMapPickMode() async {
    FocusScope.of(context).unfocus();
    Position? initialPin = _selectedLocationPosition;
    if (initialPin == null &&
        _currentPosition?.latitude != null &&
        _currentPosition?.longitude != null) {
      initialPin =
          Position(_currentPosition!.longitude!, _currentPosition!.latitude!);
    }
    if (initialPin != null) {
      _pendingPinnedPosition = initialPin;
      await _moveCameraToPosition(initialPin);
    }
    if (!mounted) return;
    setState(() => _isPickingLocation = true);
  }

  Future<void> _confirmPinnedLocation() async {
    Position? position = _pendingPinnedPosition;
    if (position == null && _mapController != null) {
      final cameraState = await _mapController!.getCameraState();
      position = cameraState.center.coordinates;
    }
    if (position == null) {
      _showSnack('Move the map to pin a location.', error: true);
      return;
    }
    final label = await _labelForPosition(position);
    await _showDestinationPin(position);
    if (!mounted) return;
    setState(() {
      _selectedLocationPosition = position;
      _selectedLocationLabel = label;
      _locationSearchController.text = label;
      _isPickingLocation = false;
      _pendingPinnedPosition = null;
      _locationSuggestions = <Map<String, dynamic>>[];
    });
    _updateAutoGeneratedReport();
  }

  Widget _buildFeed() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPortal,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        children: [
          _buildPortalHero(),
          if (_feedError != null) ...[
            const SizedBox(height: 16),
            _buildInfoBanner(
              icon: Icons.cloud_off_rounded,
              title: 'Feed fallback active',
              subtitle:
                  'Showing sample community activity and your synced reports. $_feedError',
            ),
          ],
          const SizedBox(height: 18),
          ..._posts.map(_buildPostCard),
        ],
      ),
    );
  }

  Widget _buildPortalHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.22),
            AppColors.surface.withOpacity(0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Community Portal',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Live-style community safety posts from uSafe users, plus your own reports in one place.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  label: 'Posts',
                  value: '${_posts.length}',
                  icon: Icons.article_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricChip(
                  label: 'Your name',
                  value: _displayNameFromUser(_currentUser),
                  icon: Icons.person_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(_CommunityPortalPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(post.username, imageUrl: post.avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.username,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (post.isOwnedByCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reported at ${post.locationLabel} · ${_relativeTime(post.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.issueTags
                .map(
                  (tag) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            post.reportText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _buildPostImage(post.imageUrls[index]),
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: post.imageUrls.length,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _buildActionButton(
                icon: post.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount}',
                color:
                    post.isLiked ? Colors.pinkAccent : AppColors.textSecondary,
                onTap: () => _toggleLike(post),
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.mode_comment_outlined,
                label: '${post.comments.length}',
                color: AppColors.textSecondary,
                onTap: () => _addComment(post),
              ),
            ],
          ),
          if (post.comments.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...post.comments.take(2).map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${comment.username} ',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: comment.text,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(String username, {String? imageUrl}) {
    final initials = username
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.surfaceElevated,
        backgroundImage: NetworkImage(imageUrl),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary.withOpacity(0.18),
      child: Text(
        initials.isEmpty ? 'U' : initials,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildPostImage(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    if (value.startsWith('/') || value.contains('uploads')) {
      final normalized = value.startsWith('/')
          ? '${CommunityReportService.baseUrl}$value'
          : '${CommunityReportService.baseUrl}/$value';
      return Image.network(
        normalized,
        width: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imageFallback(),
      );
    }
    final file = File(value);
    return Image.file(
      file,
      width: 220,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imageFallback(),
    );
  }

  Widget _imageFallback() {
    return Container(
      width: 220,
      color: AppColors.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        _buildInfoBanner(
          icon: Icons.map_rounded,
          title: 'Report with SafePath Guardian map',
          subtitle:
              'Use current location, search a place, or pin directly on the map without leaving the portal.',
        ),
        const SizedBox(height: 16),
        _buildMapPickerCard(),
        const SizedBox(height: 16),
        _buildIssueSelectorCard(),
        const SizedBox(height: 16),
        _buildDescriptionCard(),
        const SizedBox(height: 16),
        _buildEvidenceCard(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitReport,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_isSubmitting ? 'Posting report...' : 'Post to Portal'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapPickerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose location',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Search, use current location, or drag the map and pin the exact spot.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _locationSearchController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 450),
                      () => _fetchSuggestions(value),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search report location',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: _isSearchingSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_locationSearchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  setState(() {
                                    _locationSearchController.clear();
                                    _locationSuggestions =
                                        <Map<String, dynamic>>[];
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              )),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
                if (_locationSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemBuilder: (_, index) {
                        final suggestion = _locationSuggestions[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            _suggestionLabel(suggestion),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemCount: _locationSuggestions.length,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapWidget(
                      key: const ValueKey('community_portal_map'),
                      styleUri: MapboxStyles.STANDARD,
                      cameraOptions: CameraOptions(
                        center: Point(coordinates: Position(80.7718, 7.8731)),
                        zoom: 7,
                      ),
                      onMapCreated: _onMapCreated,
                      onTapListener: (gestureContext) async {
                        FocusScope.of(context).unfocus();
                        if (_isPickingLocation) return;
                        final position = gestureContext.point.coordinates;
                        final label = await _labelForPosition(position);
                        await _showDestinationPin(position);
                        if (!mounted) return;
                        setState(() {
                          _selectedLocationPosition = position;
                          _selectedLocationLabel = label;
                          _locationSearchController.text = label;
                          _locationSuggestions = <Map<String, dynamic>>[];
                        });
                        _updateAutoGeneratedReport();
                      },
                      onCameraChangeListener: (event) {
                        if (!_isPickingLocation) return;
                        _pendingPinnedPosition =
                            event.cameraState.center.coordinates;
                      },
                      onMapIdleListener: (_) {
                        if (!mounted || !_isPickingLocation) return;
                        setState(() {});
                      },
                    ),
                  ),
                  if (_isPickingLocation)
                    IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -18),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.alert,
                            size: 52,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: _useCurrentLocation,
                        icon: const Icon(
                          Icons.my_location_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Current location'),
              ),
              OutlinedButton.icon(
                onPressed: _enableMapPickMode,
                icon: const Icon(Icons.push_pin_outlined),
                label: Text(_isPickingLocation ? 'Move map' : 'Pin on map'),
              ),
              if (_isPickingLocation)
                FilledButton.icon(
                  onPressed: _confirmPinnedLocation,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirm pin'),
                ),
            ],
          ),
          if (_selectedLocationLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected location',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _selectedLocationLabel!,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIssueSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Issue types',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_selectedIssueIndices.length} selected',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List<Widget>.generate(_issueTypes.length, (index) {
              final issue = _issueTypes[index];
              final selected = _selectedIssueIndices.contains(index);
              return InkWell(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedIssueIndices.remove(index);
                    } else {
                      _selectedIssueIndices.add(index);
                    }
                  });
                  _updateAutoGeneratedReport();
                },
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 158,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? issue.color.withOpacity(0.16)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? issue.color : AppColors.border,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(issue.icon, color: issue.color),
                      const SizedBox(height: 10),
                      Text(
                        issue.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        issue.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Write your report',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Post it like a real-world community update so others can quickly understand the risk.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            maxLines: 8,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Example: Broken street light near the pedestrian crossing. The area becomes very dark after 7 PM and there were no officers nearby.',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add evidence',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photos help other users understand the situation faster.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, index) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        _selectedImages[index],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: _selectedImages.length,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _showComposer ? 'Add Community Report' : 'Community Reports',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _showComposer ? _closeComposer : _openComposer,
            icon: Icon(
              _showComposer ? Icons.view_stream_rounded : Icons.add_rounded,
              color: Colors.white,
            ),
            label: Text(
              _showComposer ? 'Portal' : 'Add',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _showComposer ? _buildComposer() : _buildFeed(),
      ),
      floatingActionButton: _showComposer
          ? null
          : FloatingActionButton.extended(
              onPressed: _openComposer,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Add community report'),
            ),
    );
  }
}

class _PortalIssueType {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _PortalIssueType({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _PostComment {
  final String username;
  final String text;
  final DateTime createdAt;

  _PostComment({
    required this.username,
    required this.text,
    required this.createdAt,
  });
}

class _CommunityPortalPost {
  final String id;
  final String username;
  final String avatarUrl;
  final String locationLabel;
  final String reportText;
  final List<String> imageUrls;
  final List<String> issueTags;
  final DateTime createdAt;
  int likeCount;
  bool isLiked;
  final List<_PostComment> comments;
  final bool isOwnedByCurrentUser;

  _CommunityPortalPost({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.locationLabel,
    required this.reportText,
    this.imageUrls = const <String>[],
    this.issueTags = const <String>[],
    required this.createdAt,
    required this.likeCount,
    this.isLiked = false,
    required this.comments,
    this.isOwnedByCurrentUser = false,
  });

  factory _CommunityPortalPost.fromUserReport({
    required Map<String, dynamic> report,
    Map<String, dynamic>? fallbackUser,
  }) {
    final imageUrls = <String>[];
    final rawImages = report['images_proofs'];
    if (rawImages is List) {
      for (final item in rawImages) {
        final value = '$item'.trim();
        if (value.isNotEmpty) imageUrls.add(value);
      }
    }

    final issueTags = <String>[];
    final rawIssueTypes = report['issueTypes'];
    if (rawIssueTypes is List) {
      for (final item in rawIssueTypes) {
        final value = '$item'.trim();
        if (value.isNotEmpty) issueTags.add(value);
      }
    }

    final userName = [
      '${fallbackUser?['firstName'] ?? ''}'.trim(),
      '${fallbackUser?['lastName'] ?? ''}'.trim(),
    ].where((part) => part.isNotEmpty).join(' ').trim();

    return _CommunityPortalPost(
      id: '${report['reportId'] ?? report['id'] ?? DateTime.now().millisecondsSinceEpoch}',
      username: userName.isNotEmpty
          ? userName
          : ('${fallbackUser?['name'] ?? ''}'.trim().isNotEmpty
              ? '${fallbackUser?['name']}'.trim()
              : 'uSafe User'),
      avatarUrl:
          '${fallbackUser?['picture'] ?? fallbackUser?['photoUrl'] ?? fallbackUser?['avatarUrl'] ?? ''}',
      locationLabel: '${report['location'] ?? 'Reported location'}'.trim(),
      reportText: '${report['reportContent'] ?? ''}'.trim(),
      imageUrls: imageUrls,
      issueTags: issueTags,
      createdAt: DateTime.tryParse('${report['reportDate_time'] ?? ''}') ??
          DateTime.now(),
      likeCount: 0,
      comments: <_PostComment>[],
      isOwnedByCurrentUser: true,
    );
  }
}
