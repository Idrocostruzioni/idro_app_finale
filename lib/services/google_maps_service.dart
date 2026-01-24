import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleMapsService {
  final String apiKey;

  GoogleMapsService(this.apiKey);

  Future<List<dynamic>> getAutocomplete(String input) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_API_KEY') {
      print('API Key for Google Maps is not configured.');
      return [];
    }
    
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&language=it&components=country:it';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        return data['predictions'];
      }
    }
    return [];
  }

  Future<Map<String, String>> getPlaceDetails(String placeId) async {
    if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_API_KEY') {
      print('API Key for Google Maps is not configured.');
      return {};
    }

    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&language=it&fields=address_component';

    final response = await http.get(Uri.parse(url));
    Map<String, String> address = {};

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 'OK') {
        final components = data['result']['address_components'];
        String streetNumber = '';
        String route = '';

        for (var component in components) {
          final types = component['types'];
          if (types.contains('street_number')) {
            streetNumber = component['long_name'];
          }
          if (types.contains('route')) {
            route = component['long_name'];
          }
          if (types.contains('locality')) {
            address['citta'] = component['long_name'];
          }
          if (types.contains('postal_code')) {
            address['cap'] = component['long_name'];
          }
        }
        address['via'] = '$route, $streetNumber'.trim();
        if (address['via']!.endsWith(',')) {
          address['via'] = address['via']!.substring(0, address['via']!.length - 1);
        }
      }
    }
    return address;
  }
}
