import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

const _lime = Color(0xFF9BFF3D);
const _ink = Color(0xFFF4F7F1);
const _muted = Color(0xFF9AA69C);
const _bg = Color(0xFF080D0B);
const _placesApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

class _GymPlace {
  const _GymPlace({required this.id, required this.name, required this.address, required this.position, this.rating, this.ratingCount = 0, this.mapsUrl, this.type = 'gym'});
  final String id, name, address, type;
  final LatLng position;
  final double? rating;
  final int ratingCount;
  final String? mapsUrl;
  factory _GymPlace.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>? ?? {};
    final display = json['displayName'] as Map<String, dynamic>? ?? {};
    return _GymPlace(
      id: json['id'] as String? ?? '',
      name: display['text'] as String? ?? 'Fitness place',
      address: json['formattedAddress'] as String? ?? 'Address unavailable',
      position: LatLng((loc['latitude'] as num?)?.toDouble() ?? 0, (loc['longitude'] as num?)?.toDouble() ?? 0),
      rating: (json['rating'] as num?)?.toDouble(),
      ratingCount: (json['userRatingCount'] as num?)?.toInt() ?? 0,
      mapsUrl: json['googleMapsUri'] as String?,
      type: json['primaryType'] as String? ?? 'gym',
    );
  }
}

class GymFinderScreen extends StatefulWidget {
  const GymFinderScreen({super.key});
  @override State<GymFinderScreen> createState() => _GymFinderScreenState();
}

class _GymFinderScreenState extends State<GymFinderScreen> {
  final _searchController = TextEditingController();
  final _mapController = Completer<GoogleMapController>();
  String _category = 'All';
  bool _loading = false;
  String? _error;
  Position? _position;
  List<_GymPlace> _places = [];
  String? _selectedId;
  final Set<String> _savedIds = {};
  final Set<String> _savingIds = {};
  static const _categories = ['All', 'Gym', 'Yoga', 'Swimming', 'Sports', 'Saved'];

  List<String> get _includedPlaceTypes => switch (_category) {
    'Gym' => ['gym'],
    'Yoga' => ['yoga_studio'],
    'Swimming' => ['swimming_pool'],
    'Sports' => ['sports_club', 'sports_complex', 'stadium', 'athletic_field'],
    'Saved' => [],
    _ => ['gym', 'yoga_studio', 'swimming_pool', 'sports_club', 'sports_complex', 'stadium', 'athletic_field'],
  };

  @override void initState() {
    super.initState();
    _searchController.addListener(_refreshView);
    _loadSavedPlaces();
    if (_placesApiKey.isNotEmpty) _loadNearbyPlaces();
  }
  @override void dispose() {
    _searchController..removeListener(_refreshView)..dispose();
    super.dispose();
  }
  void _refreshView() { if (mounted) setState(() {}); }

  Future<Position> _getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw Exception('Turn on Location Services and try again.');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) throw Exception('Location permission was denied. Allow it to find nearby gyms.');
    if (permission == LocationPermission.deniedForever) throw Exception('Location permission is permanently denied. Enable it in app settings.');
    return Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
  }

  CollectionReference<Map<String, dynamic>>? get _savedCollection {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('savedPlaces');
  }

  Future<void> _loadSavedPlaces() async {
    final collection = _savedCollection;
    if (collection == null) return;
    try {
      final snapshot = await collection.get();
      if (!mounted) return;
      final saved = snapshot.docs.map((doc) => _GymPlace.fromJson(doc.data())).toList();
      setState(() {
        _savedIds
          ..clear()
          ..addAll(snapshot.docs.map((doc) => doc.id));
        if (_category == 'Saved') _places = saved;
      });
    } catch (_) {
      // Keep Gym Finder usable if saved-place loading is temporarily unavailable.
    }
  }

  Future<void> _toggleSaved(_GymPlace place) async {
    final collection = _savedCollection;
    if (collection == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save places.')));
      return;
    }
    if (place.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This place has no saveable Google Place ID.')));
      return;
    }
    if (_savingIds.contains(place.id)) return;
    setState(() => _savingIds.add(place.id));
    final doc = collection.doc(place.id);
    try {
      if (_savedIds.contains(place.id)) {
        await doc.delete();
        if (!mounted) return;
        setState(() {
          _savedIds.remove(place.id);
          if (_category == 'Saved') _places.removeWhere((item) => item.id == place.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from saved places.')));
      } else {
        await doc.set({
          'id': place.id,
          'displayName': {'text': place.name},
          'formattedAddress': place.address,
          'location': {'latitude': place.position.latitude, 'longitude': place.position.longitude},
          'rating': place.rating,
          'userRatingCount': place.ratingCount,
          'googleMapsUri': place.mapsUrl,
          'primaryType': place.type,
          'savedAt': FieldValue.serverTimestamp(),
        });
        if (!mounted) return;
        setState(() => _savedIds.add(place.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Place saved.')));
      }
    } catch (error) {
      if (mounted) {
        final message = error is FirebaseException && error.code == 'permission-denied'
            ? 'Saving was blocked by Firestore rules. Check access to users/{uid}/savedPlaces.'
            : 'Unable to save this place (${error is FirebaseException ? error.code : error.runtimeType}).';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(place.id));
    }
  }

  Future<void> _loadNearbyPlaces() async {
    if (_category == 'Saved') {
      await _loadSavedPlaces();
      return;
    }
    if (_placesApiKey.isEmpty) {
      setState(() { _error = 'Google Maps API key is not configured yet.'; _loading = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final position = await _getCurrentPosition();
      final response = await http.post(
        Uri.parse('https://places.googleapis.com/v1/places:searchNearby'),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _placesApiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.googleMapsUri,places.primaryType',
        },
        body: jsonEncode({
          'includedTypes': _includedPlaceTypes,
          'maxResultCount': 20,
          'rankPreference': 'DISTANCE',
          'locationRestriction': {'circle': {'center': {'latitude': position.latitude, 'longitude': position.longitude}, 'radius': 8000.0}},
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? message;
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map<String, dynamic>) {
          final errorDetails = errorBody['error'];
          if (errorDetails is Map<String, dynamic>) {
            final apiMessage = errorDetails['message'];
            if (apiMessage is String) message = apiMessage;
          }
        }
        throw Exception(message ?? 'Places API request failed (${response.statusCode}).');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = body['places'] as List<dynamic>? ?? [];
      final places = raw.whereType<Map<String, dynamic>>().map(_GymPlace.fromJson).where((p) => p.position.latitude != 0 || p.position.longitude != 0).toList();
      if (!mounted) return;
      setState(() { _position = position; _places = places; _selectedId = null; _loading = false; });
      if (_mapController.isCompleted) {
        await _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 13)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  List<_GymPlace> get _visiblePlaces {
    final query = _searchController.text.trim().toLowerCase();
    return _places.where((p) {
      final matchesSearch = query.isEmpty || p.name.toLowerCase().contains(query) || p.address.toLowerCase().contains(query) || p.type.toLowerCase().contains(query);
      final type = p.type.toLowerCase();
      final matchesCategory = switch (_category) {
        'Gym' => type == 'gym' || type.contains('fitness_center'),
        'Yoga' => type.contains('yoga'),
        'Swimming' => type.contains('swim'),
        'Sports' => type.contains('sport') || type.contains('stadium') || type.contains('athletic_field'),
        'Saved' => _savedIds.contains(p.id),
        _ => true,
      };
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Set<Marker> get _markers => _visiblePlaces.map((p) => Marker(
    markerId: MarkerId(p.id), position: p.position,
    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    infoWindow: InfoWindow(title: p.name, snippet: p.address),
    onTap: () => setState(() => _selectedId = p.id),
  )).toSet();

  Future<void> _focusPlace(_GymPlace place) async {
    setState(() => _selectedId = place.id);
    if (_mapController.isCompleted) await _mapController.future.then((c) => c.animateCamera(CameraUpdate.newLatLngZoom(place.position, 16)));
  }

  @override Widget build(BuildContext context) {
    final target = _position == null ? const LatLng(3.1390, 101.6869) : LatLng(_position!.latitude, _position!.longitude);
    final places = _visiblePlaces;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
        const Text('Gym Finder', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 5),
        const Text('Find a place that fits your routine.', style: TextStyle(fontSize: 13, color: _muted)),
        const SizedBox(height: 18),
        TextField(controller: _searchController, decoration: InputDecoration(
          hintText: 'Search gyms or activities', prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.close_rounded)),
        )),
        const SizedBox(height: 14),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: _categories.map((cat) {
          final selected = _category == cat;
          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(cat), selected: selected, onSelected: (_) {
              if (_category == cat) return;
              setState(() { _category = cat; _places = []; _selectedId = null; });
              if (cat == 'Saved') {
                _loadSavedPlaces();
              } else {
                _loadNearbyPlaces();
              }
            },
            selectedColor: _lime, backgroundColor: const Color(0xFF141B17), side: BorderSide.none, showCheckmark: false, shape: const StadiumBorder(),
            labelStyle: TextStyle(color: selected ? const Color(0xFF080D0B) : _ink, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          ));
        }).toList())),
        const SizedBox(height: 18),
        Container(height: 270, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: const Color(0xFF27332B), borderRadius: BorderRadius.circular(24)),
          child: Stack(children: [
            if (_placesApiKey.isNotEmpty) GoogleMap(
              initialCameraPosition: CameraPosition(target: target, zoom: 11),
              myLocationEnabled: _position != null, myLocationButtonEnabled: false, zoomControlsEnabled: false, mapToolbarEnabled: false,
              markers: _markers,
              onMapCreated: (c) { if (!_mapController.isCompleted) _mapController.complete(c); },
            ) else const Center(child: Icon(Icons.map_outlined, size: 52, color: _muted)),
            Positioned(top: 12, right: 12, child: Material(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(14), child: IconButton(
              tooltip: 'Refresh nearby gyms', onPressed: _loading ? null : _loadNearbyPlaces,
              icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location_rounded, color: _ink),
            ))),
            if (_placesApiKey.isEmpty) Positioned(left: 12, right: 12, bottom: 12, child: Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(16)),
              child: const Text('Add your Google Maps API key to enable the live map and nearby search.', style: TextStyle(fontSize: 12, color: _ink), textAlign: TextAlign.center),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Nearby fitness places', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
          Text(places.length.toString() + ' found', style: const TextStyle(fontSize: 11, color: _muted)),
        ]),
        const SizedBox(height: 10),
        if (_error != null) Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: const Color(0xFF241B14), border: Border.all(color: const Color(0xFF493322)), borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB75E)), const SizedBox(width: 9),
            Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFF0D5B9), fontSize: 12, height: 1.4))),
          ]),
        ),
        if (_loading && _places.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: _lime)))
        else if (places.isEmpty) Container(
          padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            Container(width: 60, height: 60, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.location_on_outlined, color: _ink, size: 30)),
            const SizedBox(height: 12),
            Text(_searchController.text.trim().isNotEmpty ? 'No matching places' : _places.isEmpty ? 'No nearby gyms found yet' : 'No places match this filter',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 7),
            const Text('Check your location permission and Google Places API setup, then refresh to search again.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: _muted)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _loading ? null : _loadNearbyPlaces, style: FilledButton.styleFrom(backgroundColor: _lime, foregroundColor: _ink), icon: const Icon(Icons.refresh_rounded), label: const Text('Search nearby')),
          ]),
        ) else ...places.map(_placeCard),
      ])),
    );
  }

  Widget _placeCard(_GymPlace place) {
    final selected = _selectedId == place.id;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Material(
      color: const Color(0xFF141B17), borderRadius: BorderRadius.circular(20),
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: () => _focusPlace(place), child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: selected ? Border.all(color: _lime, width: 2) : null),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFF25351D), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.fitness_center_rounded, color: _ink, size: 25)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 5),
            Text(place.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.4, color: _muted)),
            if (place.rating != null) ...[
              const SizedBox(height: 7),
              Row(children: [
                const Icon(Icons.star_rounded, color: Color(0xFFFFB52E), size: 16), const SizedBox(width: 3),
                Text(place.rating!.toStringAsFixed(1) + (place.ratingCount > 0 ? ' (' + place.ratingCount.toString() + ')' : ''),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink)),
              ]),
            ],
          ])),
          const SizedBox(width: 5),
          IconButton(
            tooltip: _savedIds.contains(place.id) ? 'Remove saved place' : 'Save place',
            onPressed: _savingIds.contains(place.id) ? null : () => _toggleSaved(place),
            icon: _savingIds.contains(place.id)
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _savedIds.contains(place.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: _savedIds.contains(place.id) ? _ink : _muted,
                  ),
          ),
        ]),
      )),
    ));
  }
}
