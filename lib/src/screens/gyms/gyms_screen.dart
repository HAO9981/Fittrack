import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart' as places;

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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearbyGyms();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
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
            snippet: gym.rating == null ? null : 'Rating ${gym.rating!.toStringAsFixed(1)}',
          ),
        ),
      );
    }
    return markers;
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
                      leading: CircleAvatar(
                        child: const Icon(Icons.fitness_center),
                      ),
                      title: Text(gym.displayName?.text ?? 'Gym'),
                      subtitle: Text(
                        [
                          if (gym.rating != null) '★ ${gym.rating!.toStringAsFixed(1)}',
                          if (gym.formattedAddress != null) gym.formattedAddress!,
                        ].join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        final location = gym.location;
                        if (location == null) return;
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLngZoom(
                            LatLng(location.latitude, location.longitude),
                            16,
                          ),
                        );
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
