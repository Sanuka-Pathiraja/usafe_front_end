import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
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
    // ── High-severity types (classify as Red) ────────────────────────────
    _PortalIssueType(
      icon: Icons.gpp_bad_rounded,
      title: 'Gunshots / Shooting',
      description: 'Gunfire heard or witnessed in the area.',
      color: Color(0xFFB91C1C),
      value: 'Gunshot',
    ),
    _PortalIssueType(
      icon: Icons.personal_injury_rounded,
      title: 'Assault',
      description: 'Physical attack on a person.',
      color: Color(0xFFDC2626),
    ),
    _PortalIssueType(
      icon: Icons.money_off_rounded,
      title: 'Armed Robbery',
      description: 'Robbery involving a weapon.',
      color: Color(0xFFDC2626),
    ),
    _PortalIssueType(
      icon: Icons.warning_rounded,
      title: 'Sexual Assault',
      description: 'Sexual violence or attempted sexual violence.',
      color: Color(0xFFDC2626),
    ),
    _PortalIssueType(
      icon: Icons.child_care_rounded,
      title: 'Kidnapping / Abduction',
      description: 'Person forcibly taken or missing under suspicious circumstances.',
      color: Color(0xFFB91C1C),
      value: 'Kidnapping',
    ),
    _PortalIssueType(
      icon: Icons.groups_3_rounded,
      title: 'Gang Activity',
      description: 'Visible gang presence or gang-related incident.',
      color: Color(0xFFDC2626),
    ),
    _PortalIssueType(
      icon: Icons.crisis_alert_rounded,
      title: 'Bomb / Explosive Threat',
      description: 'Suspected explosive device or threat.',
      color: Color(0xFFB91C1C),
      value: 'Bomb Threat',
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
  Uint8List? _destinationMarkerBytes;
  bool _isGettingCurrentLocation = false;
  List<Map<String, dynamic>> _locationSuggestions = [];
  bool _isSearchingSuggestions = false;
  int _suggestionRequestId = 0;
  String _searchSessionToken = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(_communityPortalMapboxToken);
    _loadPortal();
    _fetchCurrentPositionOnce();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _debounce?.cancel();
    _descriptionController.dispose();
    _locationSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPortal() async {
    setState(() {
      _isLoading = true;
      _feedError = null;
    });

    try {
      final currentUser = await AuthService.getCurrentUser();
      final feedReports = await CommunityReportService.getCommunityFeed();
      final feedPosts = feedReports
          .map((report) => _CommunityPortalPost.fromUserReport(
                report: report,
                currentUser: currentUser,
              ))
          .toList();

      final merged = _dedupePosts(feedPosts)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _currentUser = currentUser;
        _posts = merged;
        _isLoading = false;
      });
    } catch (e) {
      try {
        final currentUser = await AuthService.getCurrentUser();
        final myReports = await CommunityReportService.getMyReports();
        final myPosts = myReports
            .map((report) => _CommunityPortalPost.fromUserReport(
                  report: report,
                  currentUser: currentUser,
                ))
            .toList();

        myPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (!mounted) return;
        setState(() {
          _currentUser = currentUser;
          _posts = _dedupePosts(myPosts);
          _feedError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _currentUser = null;
          _posts = <_CommunityPortalPost>[];
          _feedError = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<_CommunityPortalPost> _dedupePosts(List<_CommunityPortalPost> posts) {
    final byId = <String, _CommunityPortalPost>{};
    for (final post in posts) {
      byId[post.id] = post;
    }
    return byId.values.toList();
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

    final draftLocation = (_selectedLocationLabel ?? '').trim().isNotEmpty
        ? _selectedLocationLabel!.trim()
        : 'this area';
    final issueTitles = _selectedIssueIndices
        .map((index) => _issueTypes[index].title)
        .toList(growable: false);
    final issueSummary = issueTitles.length == 1
        ? issueTitles.first
        : '${issueTitles.sublist(0, issueTitles.length - 1).join(', ')} and ${issueTitles.last}';
    final draftText =
        'Reporting $issueSummary near $draftLocation. Please add what happened, when you noticed it, and anything others should watch out for.';

    _descriptionController.value = TextEditingValue(
      text: draftText,
      selection: TextSelection.collapsed(offset: draftText.length),
    );
    return;

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
            .map((index) => _issueTypes[index].backendValue)
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

  // ── Embedded map lifecycle ──────────────────────────────────────────────

  Future<void> _onMapCreated(MapboxMap map) async {
    _mapController = map;
    _pointAnnotationManager =
        await map.annotations.createPointAnnotationManager();
    _userLocationManager =
        await map.annotations.createCircleAnnotationManager();
    await _startUserLocationTracking();
  }

  CircleAnnotationOptions _buildUserLocationMarker(Position pos) =>
      CircleAnnotationOptions(
        geometry: Point(coordinates: pos),
        circleColor: Colors.blue.toARGB32(),
        circleRadius: 8.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleSortKey: 100,
      );

  Future<void> _syncUserLocationMarker(LocationData location) async {
    if (_userLocationManager == null ||
        location.latitude == null ||
        location.longitude == null) return;
    final position = _positionFromLocation(location);
    if (_userLocationAnnotation == null) {
      _userLocationAnnotation =
          await _userLocationManager!.create(_buildUserLocationMarker(position));
    } else {
      try {
        _userLocationAnnotation!.geometry = Point(coordinates: position);
        await _userLocationManager!.update(_userLocationAnnotation!);
      } catch (_) {
        _userLocationAnnotation = null;
        _userLocationAnnotation =
            await _userLocationManager!.create(_buildUserLocationMarker(position));
      }
    }
  }

  Future<void> _startUserLocationTracking() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;
    await _location.changeSettings(
        accuracy: LocationAccuracy.high, interval: 2000, distanceFilter: 5);
    final initial = await _location.getLocation();
    _currentPosition = initial;
    await _syncUserLocationMarker(initial);
    if (_selectedLocationPosition == null &&
        initial.latitude != null &&
        initial.longitude != null) {
      await _moveCameraToPosition(
          Position(initial.longitude!, initial.latitude!));
    }
    _locationSubscription?.cancel();
    _locationSubscription = _location.onLocationChanged.listen((loc) async {
      if (!mounted || loc.latitude == null || loc.longitude == null) return;
      _currentPosition = loc;
      await _syncUserLocationMarker(loc);
    });
  }

  Future<void> _moveCameraToPosition(Position position,
      {double zoom = 14.8}) async {
    if (_mapController == null) return;
    await _mapController!.flyTo(
      CameraOptions(center: Point(coordinates: position), zoom: zoom),
      MapAnimationOptions(duration: 900),
    );
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
    await manager.create(PointAnnotationOptions(
      geometry: Point(coordinates: position),
      image: markerBytes,
      iconSize: 0.2,
      iconAnchor: IconAnchor.BOTTOM,
    ));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingCurrentLocation = true);
    try {
      final hasAccess = await _ensureLocationAccess();
      if (!hasAccess) {
        _showSnack('Location permission required.', error: true);
        return;
      }
      final loc = await _location.getLocation();
      if (loc.latitude == null || loc.longitude == null) return;
      final position = Position(loc.longitude!, loc.latitude!);
      final label = await _labelForPosition(position);
      await _showDestinationPin(position);
      await _moveCameraToPosition(position, zoom: 15.5);
      if (!mounted) return;
      setState(() {
        _selectedLocationPosition = position;
        _selectedLocationLabel = label;
        _locationSearchController.text = label;
        _currentPosition = loc;
        _locationSuggestions = [];
      });
      _updateAutoGeneratedReport();
    } finally {
      if (mounted) setState(() => _isGettingCurrentLocation = false);
    }
  }

  Position _positionFromLocation(LocationData loc) =>
      Position(loc.longitude!, loc.latitude!);

  void _refreshSearchSessionToken() {
    final bytes = List.generate(
        16, (_) => (Random().nextDouble() * 256).floor());
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _searchSessionToken =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _locationSuggestions = []);
      return;
    }
    final requestId = ++_suggestionRequestId;
    setState(() => _isSearchingSuggestions = true);
    try {
      final prox = _currentPosition;
      final proxPart = prox != null
          ? '&proximity=${prox.longitude},${prox.latitude}'
          : '';
      final uri = Uri.parse(
          'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=${Uri.encodeComponent(query)}'
          '&access_token=$_communityPortalMapboxToken'
          '&session_token=$_searchSessionToken'
          '&language=en$proxPart');
      final resp = await http.get(uri);
      if (!mounted || requestId != _suggestionRequestId) return;
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => _locationSuggestions =
            (body['suggestions'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList());
      } else {
        setState(() => _locationSuggestions = []);
      }
    } catch (_) {
      if (mounted && requestId == _suggestionRequestId) {
        setState(() => _locationSuggestions = []);
      }
    } finally {
      if (mounted && requestId == _suggestionRequestId) {
        setState(() => _isSearchingSuggestions = false);
      }
    }
  }

  String _suggestionLabel(Map<String, dynamic> s) {
    final name = s['name']?.toString().trim() ?? '';
    final addr =
        (s['full_address'] ?? s['place_formatted'] ?? s['address'])
                ?.toString()
                .trim() ??
            '';
    if (addr.isEmpty) return name;
    if (name.isEmpty) return addr;
    if (addr.startsWith(name)) return addr;
    return '$name, $addr';
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    FocusScope.of(context).unfocus();
    Position? position;
    final mapboxId = suggestion['mapbox_id']?.toString();
    if (mapboxId != null && mapboxId.isNotEmpty) {
      try {
        final uri = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
            '?access_token=$_communityPortalMapboxToken'
            '&session_token=$_searchSessionToken&language=en');
        final resp = await http.get(uri);
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final features = body['features'] as List? ?? [];
          if (features.isNotEmpty) {
            final coords =
                (features.first as Map<String, dynamic>)['geometry']
                    ['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              position = Position((coords[0] as num).toDouble(),
                  (coords[1] as num).toDouble());
            }
          }
        }
      } catch (_) {}
    }
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
      _locationSuggestions = [];
    });
    _updateAutoGeneratedReport();
    _refreshSearchSessionToken();
  }

  // ── End embedded map lifecycle ──────────────────────────────────────────

  Future<void> _fetchCurrentPositionOnce() async {
    final hasAccess = await _ensureLocationAccess();
    if (!hasAccess) return;
    try {
      final loc = await _location.getLocation();
      if (mounted && loc.latitude != null && loc.longitude != null) {
        setState(() => _currentPosition = loc);
      }
    } catch (_) {}
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<_LocationPickerResult>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _LocationPickerPage(
          initialPosition: _selectedLocationPosition,
          initialLabel: _selectedLocationLabel,
          proximityPosition: _currentPosition != null
              ? Position(_currentPosition!.longitude!, _currentPosition!.latitude!)
              : null,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedLocationPosition = result.position;
        _selectedLocationLabel = result.label;
      });
      _updateAutoGeneratedReport();
    }
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
                  'Showing available synced reports only. $_feedError',
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
                      'Community safety posts from all uSafe users in one place.',
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
          // ── Header ──────────────────────────────────────────────────────
          const Text(
            'Choose location',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search, use current location, or drag the map and pin the exact spot.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),

          // ── Search bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _locationSearchController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(
                      const Duration(milliseconds: 450),
                      () => _fetchSuggestions(v),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Search report location',
                    hintStyle:
                        const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 20),
                    suffixIcon: _isSearchingSuggestions
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : (_locationSearchController.text.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() {
                                  _locationSearchController.clear();
                                  _locationSuggestions = [];
                                }),
                                icon: const Icon(Icons.close_rounded,
                                    color: AppColors.textSecondary,
                                    size: 18),
                              )),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                ),
                if (_locationSuggestions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: const BoxDecoration(
                      border:
                          Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _locationSuggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final s = _locationSuggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.primary, size: 18),
                          title: Text(
                            _suggestionLabel(s),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Embedded map (tap-to-pin preview — panning via fullscreen) ───
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 230,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: MapWidget(
                      key: const ValueKey('community_portal_map'),
                      styleUri: MapboxStyles.STANDARD,
                      cameraOptions: CameraOptions(
                        center: Point(
                            coordinates: Position(80.7718, 7.8731)),
                        zoom: 7,
                      ),
                      onMapCreated: _onMapCreated,
                      onTapListener: (ctx) async {
                        // Tap directly on the map to drop a quick pin.
                        FocusScope.of(context).unfocus();
                        final pos = ctx.point.coordinates;
                        final label = await _labelForPosition(pos);
                        await _showDestinationPin(pos);
                        if (!mounted) return;
                        setState(() {
                          _selectedLocationPosition = pos;
                          _selectedLocationLabel = label;
                          _locationSearchController.text = label;
                          _locationSuggestions = [];
                        });
                        _updateAutoGeneratedReport();
                      },
                    ),
                  ),

                  // Fullscreen expand button (top-right)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _openLocationPicker,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),

                  // My-location button (top-left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: GestureDetector(
                      onTap: _isGettingCurrentLocation
                          ? null
                          : _useCurrentLocation,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.5)),
                        ),
                        child: _isGettingCurrentLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded,
                                color: Colors.white, size: 18),
                      ),
                    ),
                  ),

                  // "Pan to pick" hint at bottom of map
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _openLocationPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_full_rounded,
                                color: Colors.white70, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Tap to pin · Open full map to pan & search',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Action buttons ───────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGettingCurrentLocation
                      ? null
                      : _useCurrentLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Current location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openLocationPicker,
                  icon: const Icon(Icons.open_in_full_rounded, size: 16),
                  label: const Text('Full map'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),

          // ── Selected label ───────────────────────────────────────────────
          if (_selectedLocationLabel != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedLocationLabel!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedLocationLabel = null;
                      _selectedLocationPosition = null;
                      _locationSearchController.clear();
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textSecondary),
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
    final int generalCount = 8; // first 8 are general types
    final generalTypes = _issueTypes.sublist(0, generalCount);
    final severeTypes = _issueTypes.sublist(generalCount);

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
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Issue Types',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (_selectedIssueIndices.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${_selectedIssueIndices.length} selected',
                    style: const TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select all that apply',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // ── General section ─────────────────────────────────────────────
          _buildSectionLabel('General', color: AppColors.textSecondary),
          const SizedBox(height: 10),
          _buildChipGroup(generalTypes, startIndex: 0),
          const SizedBox(height: 16),

          // ── High severity section ────────────────────────────────────────
          _buildSectionLabel('High Severity', color: const Color(0xFFEF4444),
              icon: Icons.warning_amber_rounded),
          const SizedBox(height: 10),
          _buildChipGroup(severeTypes, startIndex: generalCount),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label,
      {required Color color, IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.2)),
        ),
      ],
    );
  }

  Widget _buildChipGroup(List<_PortalIssueType> types, {required int startIndex}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(types.length, (i) {
        final index = startIndex + i;
        final issue = types[i];
        final selected = _selectedIssueIndices.contains(index);
        return _IssueChip(
          issue: issue,
          selected: selected,
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
        );
      }),
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
              fillColor: Colors.white.withValues(alpha: 0.04),
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

// ─────────────────────────────────────────────────────────────────────────────
// Compact selectable chip for issue type selection
// ─────────────────────────────────────────────────────────────────────────────

class _IssueChip extends StatelessWidget {
  final _PortalIssueType issue;
  final bool selected;
  final VoidCallback onTap;

  const _IssueChip({
    required this.issue,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? issue.color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? issue.color.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              issue.icon,
              size: 15,
              color: selected ? issue.color : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              issue.title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white60,
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle_rounded,
                  size: 14, color: issue.color),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PortalIssueType {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  /// Backend keyword to send in issueTypes[]. Defaults to [title] when null.
  final String? value;

  const _PortalIssueType({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.value,
  });

  /// The string to include in the issueTypes[] payload sent to the backend.
  String get backendValue => value ?? title;
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
    Map<String, dynamic>? currentUser,
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

    final reportUser = report['user'] is Map
        ? Map<String, dynamic>.from(report['user'] as Map)
        : <String, dynamic>{};
    final userName = [
      '${reportUser['firstName'] ?? reportUser['first_name'] ?? ''}'.trim(),
      '${reportUser['lastName'] ?? reportUser['last_name'] ?? ''}'.trim(),
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final fallbackName = '${reportUser['name'] ?? reportUser['username'] ?? ''}'
        .trim();
    final currentUserName = [
      '${currentUser?['firstName'] ?? ''}'.trim(),
      '${currentUser?['lastName'] ?? ''}'.trim(),
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final ownerId =
        '${reportUser['userId'] ?? reportUser['id'] ?? report['userId'] ?? report['ownerId'] ?? ''}'
            .trim();
    final currentUserId =
        '${currentUser?['userId'] ?? currentUser?['id'] ?? ''}'.trim();
    final ownerEmail =
        '${reportUser['email'] ?? report['email'] ?? report['userEmail'] ?? ''}'
            .trim()
            .toLowerCase();
    final currentUserEmail =
        '${currentUser?['email'] ?? ''}'.trim().toLowerCase();
    final isOwnedByCurrentUser =
        (ownerId.isNotEmpty && ownerId == currentUserId) ||
            (ownerEmail.isNotEmpty && ownerEmail == currentUserEmail);

    return _CommunityPortalPost(
      id: '${report['reportId'] ?? report['id'] ?? DateTime.now().millisecondsSinceEpoch}',
      username: userName.isNotEmpty
          ? userName
          : (fallbackName.isNotEmpty
              ? fallbackName
              : (currentUserName.isNotEmpty && isOwnedByCurrentUser
                  ? currentUserName
                  : 'uSafe User')),
      avatarUrl:
          '${reportUser['avatarUrl'] ?? reportUser['avatar'] ?? reportUser['photoUrl'] ?? reportUser['picture'] ?? ''}',
      locationLabel: '${report['location'] ?? 'Reported location'}'.trim(),
      reportText: '${report['reportContent'] ?? ''}'.trim(),
      imageUrls: imageUrls,
      issueTags: issueTags,
      createdAt: DateTime.tryParse('${report['reportDate_time'] ?? ''}') ??
          DateTime.now(),
      likeCount: int.tryParse('${report['likeCount'] ?? 0}') ?? 0,
      isLiked: report['isLikedByCurrentUser'] == true,
      comments: <_PostComment>[],
      isOwnedByCurrentUser: isOwnedByCurrentUser,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen location picker
// ─────────────────────────────────────────────────────────────────────────────

class _LocationPickerResult {
  final Position position;
  final String label;
  const _LocationPickerResult({required this.position, required this.label});
}

class _LocationPickerPage extends StatefulWidget {
  final Position? initialPosition;
  final String? initialLabel;
  final Position? proximityPosition;

  const _LocationPickerPage({
    this.initialPosition,
    this.initialLabel,
    this.proximityPosition,
  });

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  MapboxMap? _map;
  CircleAnnotationManager? _locationCircleManager;
  CircleAnnotation? _locationAnnotation;
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSub;

  Position? _pinnedPosition;
  String _pinnedLabel = '';
  bool _isFetchingLabel = false;
  bool _isMoving = false;

  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;
  int _reqId = 0;
  String _sessionToken = '';

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(_communityPortalMapboxToken);
    _refreshSessionToken();
    _pinnedPosition = widget.initialPosition;
    _pinnedLabel = widget.initialLabel ?? '';
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _refreshSessionToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _sessionToken =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _locationCircleManager =
        await map.annotations.createCircleAnnotationManager();

    if (widget.initialPosition != null) {
      await _moveCameraTo(widget.initialPosition!, zoom: 15.5, animated: false);
    } else {
      await _flyToCurrentLocation(showMarker: false);
    }
  }

  Future<void> _moveCameraTo(Position pos,
      {double zoom = 15.5, bool animated = true}) async {
    if (_map == null) return;
    final opts = CameraOptions(
        center: Point(coordinates: pos), zoom: zoom);
    if (animated) {
      await _map!.flyTo(opts, MapAnimationOptions(duration: 800));
    } else {
      await _map!.setCamera(opts);
    }
  }

  Future<void> _flyToCurrentLocation({bool showMarker = true}) async {
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location.requestService();
    if (!serviceEnabled) return;
    PermissionStatus perm = await _location.hasPermission();
    if (perm == PermissionStatus.denied) {
      perm = await _location.requestPermission();
    }
    if (perm != PermissionStatus.granted) return;

    final loc = await _location.getLocation();
    if (loc.latitude == null || loc.longitude == null || !mounted) return;
    final pos = Position(loc.longitude!, loc.latitude!);

    if (showMarker) await _syncLocationMarker(pos);
    await _moveCameraTo(pos, zoom: 15.5);

    _locationSub?.cancel();
    _locationSub = _location.onLocationChanged.listen((l) async {
      if (!mounted || l.latitude == null || l.longitude == null) return;
      await _syncLocationMarker(Position(l.longitude!, l.latitude!));
    });
  }

  Future<void> _syncLocationMarker(Position pos) async {
    final m = _locationCircleManager;
    if (m == null) return;
    if (_locationAnnotation == null) {
      _locationAnnotation = await m.create(CircleAnnotationOptions(
        geometry: Point(coordinates: pos),
        circleColor: Colors.blue.toARGB32(),
        circleRadius: 7.0,
        circleStrokeWidth: 2.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleSortKey: 100,
      ));
    } else {
      try {
        _locationAnnotation!.geometry = Point(coordinates: pos);
        await m.update(_locationAnnotation!);
      } catch (_) {
        _locationAnnotation = null;
        _locationAnnotation = await m.create(CircleAnnotationOptions(
          geometry: Point(coordinates: pos),
          circleColor: Colors.blue.toARGB32(),
          circleRadius: 7.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleSortKey: 100,
        ));
      }
    }
  }

  Future<void> _onCameraIdle() async {
    if (_map == null || !mounted) return;
    final cs = await _map!.getCameraState();
    final pos = cs.center.coordinates;
    if (!mounted) return;
    setState(() {
      _pinnedPosition = pos;
      _isFetchingLabel = true;
    });
    final label = await _reverseGeocode(pos);
    if (!mounted) return;
    setState(() {
      _pinnedLabel = label;
      _isFetchingLabel = false;
    });
  }

  Future<String> _reverseGeocode(Position pos) async {
    try {
      final places = await geocoding.placemarkFromCoordinates(
          pos.lat.toDouble(), pos.lng.toDouble());
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty) p.name!,
          if ((p.street ?? '').isNotEmpty) p.street!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return _coordLabel(pos);
  }

  String _coordLabel(Position pos) =>
      '${pos.lat.toStringAsFixed(5)}, ${pos.lng.toStringAsFixed(5)}';

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () => _fetchSuggestions(query));
  }

  Future<void> _fetchSuggestions(String query) async {
    final reqId = ++_reqId;
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final proximity = widget.proximityPosition;
      final proxPart = proximity != null
          ? '&proximity=${proximity.lng},${proximity.lat}'
          : '';
      final uri = Uri.parse(
          'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=${Uri.encodeComponent(query)}'
          '&access_token=$_communityPortalMapboxToken'
          '&session_token=$_sessionToken'
          '&language=en'
          '$proxPart');
      final resp = await http.get(uri);
      if (!mounted || reqId != _reqId) return;
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final suggestions = (body['suggestions'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        setState(() => _suggestions = suggestions);
      } else {
        setState(() => _suggestions = []);
      }
    } catch (_) {
      if (mounted && reqId == _reqId) setState(() => _suggestions = []);
    } finally {
      if (mounted && reqId == _reqId) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> s) async {
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);
    _searchCtrl.clear();

    Position? pos;
    final mapboxId = s['mapbox_id']?.toString();
    if (mapboxId != null && mapboxId.isNotEmpty) {
      try {
        final uri = Uri.parse(
            'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
            '?access_token=$_communityPortalMapboxToken'
            '&session_token=$_sessionToken&language=en');
        final resp = await http.get(uri);
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          final features = body['features'] as List? ?? [];
          if (features.isNotEmpty) {
            final coords = (features.first as Map<String, dynamic>)['geometry']
                ['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              pos = Position(
                  (coords[0] as num).toDouble(), (coords[1] as num).toDouble());
            }
          }
        }
      } catch (_) {}
    }

    if (pos == null) return;
    final name = s['name']?.toString().trim() ?? '';
    final addr = (s['full_address'] ?? s['place_formatted'] ?? s['address'])
            ?.toString()
            .trim() ??
        '';
    final label = addr.isEmpty
        ? name
        : name.isEmpty
            ? addr
            : addr.startsWith(name)
                ? addr
                : '$name, $addr';

    setState(() {
      _pinnedPosition = pos;
      _pinnedLabel = label;
    });
    await _moveCameraTo(pos, zoom: 15.5);
    _refreshSessionToken();
  }

  String _suggestionLabel(Map<String, dynamic> s) {
    final name = s['name']?.toString().trim() ?? '';
    final addr = (s['full_address'] ?? s['place_formatted'] ?? s['address'])
            ?.toString()
            .trim() ??
        '';
    if (addr.isEmpty) return name;
    if (name.isEmpty) return addr;
    if (addr.startsWith(name)) return addr;
    return '$name, $addr';
  }

  void _confirmLocation() {
    final pos = _pinnedPosition;
    if (pos == null) return;
    final label = _pinnedLabel.isNotEmpty ? _pinnedLabel : _coordLabel(pos);
    Navigator.pop(
        context, _LocationPickerResult(position: pos, label: label));
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────
          Positioned.fill(
            child: MapWidget(
              key: const ValueKey('location_picker_map'),
              styleUri: MapboxStyles.DARK,
              cameraOptions: CameraOptions(
                center: Point(
                    coordinates: widget.initialPosition ??
                        Position(80.7718, 7.8731)),
                zoom: widget.initialPosition != null ? 15.5 : 7.0,
              ),
              onMapCreated: _onMapCreated,
              onTapListener: (ctx) async {
                FocusScope.of(context).unfocus();
                setState(() => _suggestions = []);
                final pos = ctx.point.coordinates;
                setState(() {
                  _pinnedPosition = pos;
                  _isFetchingLabel = true;
                });
                await _moveCameraTo(pos);
                final label = await _reverseGeocode(pos);
                if (mounted) setState(() { _pinnedLabel = label; _isFetchingLabel = false; });
              },
              onCameraChangeListener: (event) {
                if (!mounted) return;
                setState(() => _isMoving = true);
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 600), () {
                  if (mounted) setState(() => _isMoving = false);
                  _onCameraIdle();
                });
              },
            ),
          ),

          // ── Centre crosshair pin ────────────────────────────────────────
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: _isMoving ? 1.18 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFEF4444),
                      size: 48,
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isMoving ? 12 : 8,
                    height: _isMoving ? 3 : 4,
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Search bar overlay (top) ────────────────────────────────────
          Positioned(
            top: topPad + 10,
            left: 14,
            right: 14,
            child: Column(
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          blurRadius: 16,
                          offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white70, size: 20),
                      ),
                      // Search field
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w400),
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Search location...',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.7),
                                fontSize: 15),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 14),
                            suffixIcon: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.textSecondary),
                                    ),
                                  )
                                : (_searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          setState(() => _suggestions = []);
                                        },
                                        icon: const Icon(Icons.close_rounded,
                                            color: AppColors.textSecondary,
                                            size: 18),
                                      )
                                    : const Icon(Icons.search_rounded,
                                        color: AppColors.textSecondary,
                                        size: 20)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Suggestions dropdown
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black45,
                            blurRadius: 10,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
                      itemBuilder: (_, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.primary, size: 18),
                          title: Text(
                            _suggestionLabel(s),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                    ),
                  ),
              ],
            ),
          ),

          // ── My location FAB ─────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: 180 + bottomPad,
            child: FloatingActionButton.small(
              heroTag: 'picker_location_fab',
              onPressed: () => _flyToCurrentLocation(),
              backgroundColor: AppColors.surface,
              foregroundColor: Colors.white,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // ── Bottom confirm panel ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPad),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Address row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isFetchingLabel
                            ? Row(children: const [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Finding address...',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ])
                            : Text(
                                _pinnedLabel.isNotEmpty
                                    ? _pinnedLabel
                                    : 'Pan or tap map to choose location',
                                style: TextStyle(
                                  color: _pinnedLabel.isNotEmpty
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: _pinnedLabel.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Action buttons
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _pinnedPosition == null ? null : _confirmLocation,
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Confirm this location'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
