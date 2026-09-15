import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

class GymService {
  GymService._();
  static final GymService instance = GymService._();

  final PlacesClient _client = PlacesClient(
    apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
  );

  bool get isConfigured =>
      const String.fromEnvironment('GOOGLE_MAPS_API_KEY').trim().isNotEmpty;

  static const Set<PlaceField> _gymFields = {
    PlaceField.displayName,
    PlaceField.formattedAddress,
    PlaceField.location,
    PlaceField.rating,
    PlaceField.userRatingCount,
    PlaceField.googleMapsUri,
    PlaceField.nationalPhoneNumber,
    PlaceField.websiteUri,
    PlaceField.currentOpeningHours,
    PlaceField.regularOpeningHours,
  };

  Future<List<PlaceData>> searchNearbyGyms({
    required double latitude,
    required double longitude,
    double radiusMeters = 5000,
  }) async {
    if (!isConfigured) return const [];

    return _client.searchNearby(
      NearbySearchRequest(
        locationRestriction: LocationRestriction.circle(
          center: PlaceCoordinates(latitude: latitude, longitude: longitude),
          radiusMeters: radiusMeters,
        ),
        includedPrimaryTypes: const ['gym'],
        fields: _gymFields,
        maxResultCount: 15,
        languageCode: 'en',
        regionCode: 'MY',
      ),
    );
  }

  Future<PlaceData> getGymDetails(String placeId) {
    return _client.fetchPlaceById(
      placeId,
      fields: _gymFields,
      languageCode: 'en',
      regionCode: 'MY',
    );
  }

  void dispose() => _client.close();
}
