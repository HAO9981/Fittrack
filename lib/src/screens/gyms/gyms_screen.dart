import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart' as places;
import 'package:url_launcher/url_launcher.dart';

import '../../services/firestore_service.dart';
import '../../services/gym_service.dart';

class GymsScreen extends StatefulWidget {
  const GymsScreen({super.key});

  @override
  State<GymsScreen> createState() => _GymsScreenState();
}

class _GymsScreenState extends State<GymsScreen> {
  GoogleMapController? _mapController;
  Position? _position;
  List<places.PlaceData> _gyms = const [];
  Set<String> _savedGymIds = <String>{};
  bool _loading = true;
  bool _savedLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedGymIds();
    _loadNearbyGyms();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadSavedGymIds() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final ids = await FirestoreService.instance.getSavedGymIds(uid);
      if (!mounted) return;
      setState(() => _savedGymIds = ids);
    } catch (_) {
      // Saved gyms should not prevent the map from loading.
    }
  }

  Future<void> _loadNearbyGyms() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!GymService.instance.isConfigured) {
        throw StateError('Google Maps API key is not configured yet.');
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Please turn on location services to find nearby gyms.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is required to find nearby gyms.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final gyms = await GymService.instance.searchNearbyGyms(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _position = position;
        _gyms = gyms;
        _loading = false;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    final position = _position;
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: 'Your location'),
        ),
      );
    }

    for (final gym in _gyms) {
      final location = gym.location;
      if (location == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(gym.id),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: gym.displayName?.text ?? 'Gym',
            snippet: gym.rating == null
                ? null
                : 'Rating ${gym.rating!.toStringAsFixed(1)}',
          ),
        ),
      );
    }
    return markers;
  }

  String? _openingSummary(places.PlaceData gym) {
    final hours = gym.currentOpeningHours ?? gym.regularOpeningHours;
    if (hours == null) return null;

    final openNow = hours['openNow'];
    final weekdayDescriptions = hours['weekdayDescriptions'];
    String? today;

    if (weekdayDescriptions is List) {
      const weekdays = <String>[
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final dayName = weekdays[DateTime.now().weekday - 1];
      for (final value in weekdayDescriptions) {
        if (value is String && value.startsWith('$dayName:')) {
          today = value.substring(dayName.length + 2);
          break;
        }
      }
    }

    final status = openNow is bool ? (openNow ? 'Open now' : 'Closed now') : null;
    return [
      if (status != null) status,
      if (today != null && today.isNotEmpty) today,
    ].join(' • ');
  }

  Future<void> _toggleSavedGym(places.PlaceData gym) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final isSaved = _savedGymIds.contains(gym.id);
    setState(() {
      if (isSaved) {
        _savedGymIds = {..._savedGymIds}..remove(gym.id);
      } else {
        _savedGymIds = {..._savedGymIds, gym.id};
      }
    });

    try {
      if (isSaved) {
        await FirestoreService.instance.removeSavedGym(uid, gym.id);
      } else {
        await FirestoreService.instance.saveGym(uid, gym.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (isSaved) {
          _savedGymIds = {..._savedGymIds, gym.id};
        } else {
          _savedGymIds = {..._savedGymIds}..remove(gym.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update saved gym: $error')),
      );
    }
  }

  Future<List<places.PlaceData>> _loadSavedGyms() async {
    final results = <places.PlaceData>[];
    for (final placeId in _savedGymIds) {
      try {
        results.add(await GymService.instance.getGymDetails(placeId));
      } catch (_) {
        // Ignore places that are temporarily unavailable or no longer exist.
      }
    }
    return results;
  }

  Future<void> _showGymDetails(places.PlaceData gym) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final name = gym.displayName?.text ?? 'Gym';
        final opening = _openingSummary(gym);
        final isSaved = _savedGymIds.contains(gym.id);

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isSaved ? 'Remove saved gym' : 'Save gym',
                      onPressed: () => _toggleSavedGym(gym),
                      icon: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
                  ],
                ),
                if (gym.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 20),
                      const SizedBox(width: 4),
                      Text(gym.rating!.toStringAsFixed(1)),
                      if (gym.userRatingCount != null) ...[
                        const SizedBox(width: 4),
                        Text('(${gym.userRatingCount} reviews)'),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (gym.formattedAddress != null)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: gym.formattedAddress!,
                  ),
                if (gym.nationalPhoneNumber != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    text: gym.nationalPhoneNumber!,
                  ),
                ],
                if (opening != null && opening.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.schedule_outlined,
                    text: opening,
                  ),
                ],
                if (gym.websiteUri != null) ...[
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.language_outlined,
                    text: gym.websiteUri!,
                  ),
                ],
                const SizedBox(height: 20),
                if (gym.nationalPhoneNumber != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri(scheme: 'tel', path: gym.nationalPhoneNumber),
                      ),
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Gym'),
                    ),
                  ),
                if (gym.websiteUri != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(gym.websiteUri!)),
                      icon: const Icon(Icons.language),
                      label: const Text('Open Website'),
                    ),
                  ),
                ],
                if (gym.googleMapsUri != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => launchUrl(Uri.parse(gym.googleMapsUri!)),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Open in Google Maps'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSavedGyms() async {
    if (_savedLoading) return;
    setState(() => _savedLoading = true);
    final gyms = await _loadSavedGyms();
    if (!mounted) return;
    setState(() => _savedLoading = false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: gyms.isEmpty
              ? const Center(
                  child: Text('No saved gyms yet. Save a gym to find it here later.'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: gyms.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final gym = gyms[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.fitness_center),
                      ),
                      title: Text(gym.displayName?.text ?? 'Gym'),
                      subtitle: Text(
                        [
                          if (gym.rating != null)
                            '★ ${gym.rating!.toStringAsFixed(1)}',
                          if (gym.formattedAddress != null) gym.formattedAddress!,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showGymDetails(gym);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final initialTarget = position == null
        ? const LatLng(1.4927, 103.7414)
        : LatLng(position.latitude, position.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Gyms'),
        actions: [
          IconButton(
            tooltip: 'Saved gyms',
            onPressed: _showSavedGyms,
            icon: Badge(
              isLabelVisible: _savedGymIds.isNotEmpty,
              label: Text('${_savedGymIds.length}'),
              child: const Icon(Icons.bookmark_outline),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadNearbyGyms,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 13,
            ),
            myLocationEnabled: position != null,
            myLocationButtonEnabled: position != null,
            zoomControlsEnabled: false,
            markers: _markers(),
            onMapCreated: (controller) => _mapController = controller,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.fitness_center),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _loading
                            ? 'Finding gyms near you...'
                            : '${_gyms.length} gyms found within 5 km',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off, size: 42),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _loadNearbyGyms,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_loading && _error == null && _gyms.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.24,
              minChildSize: 0.12,
              maxChildSize: 0.55,
              snap: true,
              builder: (context, scrollController) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: const [
                    BoxShadow(blurRadius: 12, offset: Offset(0, -3)),
                  ],
                ),
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: _gyms.length,
                  itemBuilder: (context, index) {
                    final gym = _gyms[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.fitness_center),
                      ),
                      title: Text(gym.displayName?.text ?? 'Gym'),
                      subtitle: Text(
                        [
                          if (gym.rating != null)
                            '★ ${gym.rating!.toStringAsFixed(1)}',
                          if (gym.formattedAddress != null) gym.formattedAddress!,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(
                        _savedGymIds.contains(gym.id)
                            ? Icons.bookmark
                            : Icons.chevron_right,
                      ),
                      onTap: () {
                        final location = gym.location;
                        if (location != null) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(location.latitude, location.longitude),
                              16,
                            ),
                          );
                        }
                        _showGymDetails(gym);
                      },
                    );
                  },
                ),
              ),
            ),
          if (!_loading && _error == null && _gyms.isEmpty)
            const Center(
              child: Card(
                margin: EdgeInsets.all(24),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No gyms were found nearby. Try refreshing or moving to another area.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}
