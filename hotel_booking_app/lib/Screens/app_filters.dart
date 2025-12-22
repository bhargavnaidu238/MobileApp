import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hotel_booking_app/services/api_service.dart';


// LOCATION HANDLING (with reverse geocoding)
Future<String> getCurrentLocationDisplayName() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to get last known position as fallback (emulator friendly)
      Position? last = await Geolocator.getLastKnownPosition();
      if (last == null) return "Manual Location";
      return await _reverseGeocodeToCity(last.latitude, last.longitude) ??
          "Manual Location";
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return "Manual Location";
    }
    if (permission == LocationPermission.deniedForever) {
      return "Permission Permanently Denied";
    }

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    final city = await _reverseGeocodeToCity(position.latitude, position.longitude);
    if (city != null && city.isNotEmpty) return city;

    // fallback to coordinates if reverse fails
    return "Lat: ${position.latitude.toStringAsFixed(2)}, "
        "Lng: ${position.longitude.toStringAsFixed(2)}";
  } catch (e) {
    debugPrint("⚠️ Location Error: $e");
    // try last known position
    try {
      Position? last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final city = await _reverseGeocodeToCity(last.latitude, last.longitude);
        if (city != null && city.isNotEmpty) return city;
        return "Lat: ${last.latitude.toStringAsFixed(2)}, "
            "Lng: ${last.longitude.toStringAsFixed(2)}";
      }
    } catch (_) {}
    return "Manual Location";
  }
}

Future<String?> _reverseGeocodeToCity(double lat, double lon) async {
  try {
    final url =
    Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon');
    final response = await http.get(url, headers: {
      "User-Agent": "HotelBookingApp/1.0 (your-email@example.com)"
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map && data.containsKey('address')) {
        final addr = data['address'];
        // prefer city, then town, then village, then state
        String? city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            addr['state'];
        return city?.toString();
      }
    }
  } catch (e) {
    debugPrint("Reverse geocode failed: $e");
  }
  return null;
}

// ================== SEARCH REMOTE HOTELS ====================
Future<List<dynamic>> remoteSearchHotels(
    String query, {
      String? city,
      Map<String, dynamic>? filters,
    }) async {
  try {
    final uri = Uri.parse(
        "${ApiConfig.baseUrl}/search?query=${Uri.encodeComponent(query)}"
            "${city != null ? "&city=${Uri.encodeComponent(city)}" : ""}");
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("❌ Search request failed: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    debugPrint("❌ Search error: $e");
    return [];
  }
}

// ========================= LOCATION SELECTOR ===========================

Future<String?> openLocationSelector(BuildContext context) async {
  TextEditingController controller = TextEditingController();
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Change Location"),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.location_on_outlined, color: Colors.green),
          labelText: "Enter City or Location",
          hintText: "e.g., Bangalore",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          onPressed: () {
            Navigator.pop(context, controller.text.trim());
          },
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("Apply"),
        ),
      ],
    ),
  );
}


// ==================== FILTER SHEET (updated: Reset restores previous state, added Sort By) ========================

Future<Map<String, dynamic>?> openFilterSheet(
    BuildContext context, Map<String, dynamic> currentFilters) async {
  // Make a defensive copy of currentFilters to use as "original"
  final Map<String, dynamic> originalFilters = Map<String, dynamic>.from(currentFilters);

  RangeValues priceRange = RangeValues(
    (currentFilters["minPrice"] ?? 500).toDouble(),
    (currentFilters["maxPrice"] ?? 5000).toDouble(),
  );

  // Accept either numeric rating or legacy string
  String selectedRatingLabel;
  if (currentFilters.containsKey("rating")) {
    final r = currentFilters["rating"];
    if (r is num) {
      if (r >= 4.0) selectedRatingLabel = "4★ & Above";
      else if (r >= 3.0) selectedRatingLabel = "3★";
      else if (r >= 2.0) selectedRatingLabel = "2★";
      else selectedRatingLabel = "All";
    } else if (r is String) {
      selectedRatingLabel = r;
    } else {
      selectedRatingLabel = "All";
    }
  } else {
    selectedRatingLabel = "All";
  }

  // Sort options: none, price_lowest, price_highest, top_rated
  String selectedSort = currentFilters["sortBy"] ?? "none";

  return await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text("Filters",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Price Range"),
                  RangeSlider(
                    min: 500,
                    max: 10000,
                    divisions: 19,
                    values: priceRange,
                    onChanged: (values) {
                      setState(() => priceRange = values);
                    },
                    labels: RangeLabels(
                      "₹${priceRange.start.toInt()}",
                      "₹${priceRange.end.toInt()}",
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Hotel Rating"),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (var rating in ["All", "4★ & Above", "3★", "2★"])
                        ChoiceChip(
                          label: Text(rating),
                          selected: selectedRatingLabel == rating,
                          onSelected: (_) =>
                              setState(() => selectedRatingLabel = rating),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sort By dropdown
                  const Text("Sort By"),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedSort,
                    items: const [
                      DropdownMenuItem(value: "none", child: Text("None")),
                      DropdownMenuItem(value: "price_lowest", child: Text("Price (Lowest First)")),
                      DropdownMenuItem(value: "price_highest", child: Text("Price (Highest First)")),
                      DropdownMenuItem(value: "top_rated", child: Text("Top Rated")),
                    ],
                    onChanged: (v) => setState(() => selectedSort = v ?? "none"),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Reset reverts to original filters (restores previous state)
                            setState(() {
                              priceRange = RangeValues(
                                (originalFilters["minPrice"] ?? 500).toDouble(),
                                (originalFilters["maxPrice"] ?? 5000).toDouble(),
                              );
                              // restore rating
                              if (originalFilters.containsKey("rating")) {
                                final r = originalFilters["rating"];
                                if (r is num) {
                                  if (r >= 4.0) selectedRatingLabel = "4★ & Above";
                                  else if (r >= 3.0) selectedRatingLabel = "3★";
                                  else if (r >= 2.0) selectedRatingLabel = "2★";
                                  else selectedRatingLabel = "All";
                                } else if (r is String) {
                                  selectedRatingLabel = r;
                                } else {
                                  selectedRatingLabel = "All";
                                }
                              } else {
                                selectedRatingLabel = "All";
                              }
                              selectedSort = originalFilters["sortBy"] ?? "none";
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("Reset Filters"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () {
                            // Map rating label to numeric for backend
                            double? ratingValue;
                            if (selectedRatingLabel == "4★ & Above") ratingValue = 4.0;
                            else if (selectedRatingLabel == "3★") ratingValue = 3.0;
                            else if (selectedRatingLabel == "2★") ratingValue = 2.0;
                            else ratingValue = null; // All

                            final result = <String, dynamic>{
                              "minPrice": priceRange.start.round(),
                              "maxPrice": priceRange.end.round(),
                              // only include rating if not 'All'
                              if (ratingValue != null) "rating": ratingValue,
                              // include sortBy for backend
                              if (selectedSort != null && selectedSort != "none")
                                "sortBy": selectedSort,
                            };

                            Navigator.pop(context, result);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("Apply"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// =========================== FETCH HOTELS WITH FILTERS ===============================
Future<List<dynamic>> fetchHotelsWithFilters(
    Map<String, dynamic> filters, String type) async {
  try {
    final uri = Uri.parse("${ApiConfig.baseUrl}/hotels/filter");
    // We'll send a top-level JSON with 'type' and 'filters' and optionally 'sortBy'
    final body = <String, dynamic>{
      "type": type,
      "filters": filters ?? {},
      // if filters contains sortBy already, move it up
    };
    if (filters.containsKey("sortBy")) {
      body["sortBy"] = filters["sortBy"];
    }

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      debugPrint("❌ Filter fetch failed: ${response.statusCode}");
      return [];
    }
  } catch (e) {
    debugPrint("❌ Error fetching hotels with filters: $e");
    return [];
  }
}
