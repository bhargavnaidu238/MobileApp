import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class PgDetailsPage extends StatefulWidget {
  final Map<String, dynamic> pg;
  final Map<String, dynamic> user;

  const PgDetailsPage({
    required this.pg,
    required this.user,
    Key? key,
  }) : super(key: key);

  @override
  State<PgDetailsPage> createState() => _PgDetailsPageState();
}

class _PgDetailsPageState extends State<PgDetailsPage> {
  late List<String> images;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();
  String selectedRoomType = '';
  String selectedRoomPrice = '';

  @override
  void initState() {
    super.initState();
    images = _parseImages(widget.pg['PG_Images']);
  }

  // -------------------- IMAGE PARSER --------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];
    try {
      // If it's already a List
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .map(_normalizeImageUrl)
            .toList();
      }

      // If it's a JSON string representing a list
      if (raw is String) {
        final s = raw.trim();
        // If looks like JSON array
        if ((s.startsWith('[') && s.endsWith(']')) || (s.contains('http') && s.contains(','))) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              return parsed
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .map(_normalizeImageUrl)
                  .toList();
            }
          } catch (_) {
            // fallback to comma-split
            final parts = s.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',');
            return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).map(_normalizeImageUrl).toList();
          }
        } else {
          // simple comma-separated
          final parts = s.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').split(',');
          return parts.map((e) => e.trim()).where((e) => e.isNotEmpty).map(_normalizeImageUrl).toList();
        }
      }
    } catch (_) {
      // any parsing error -> return safe empty list
    }
    return [];
  }

  String _normalizeImageUrl(String url) {
    url = url.replaceAll("\\", "/").trim();
    if (url.startsWith("http://") || url.startsWith("https://")) {
      return url.replaceAll("[", "").replaceAll("]", "");
    }

    final cleaned = url.replaceAll("[", "").replaceAll("]", "");
    final path = cleaned.startsWith('/') ? cleaned.substring(1) : cleaned;
    return '${ApiConfig.baseUrl}/hotel_images/$path';
  }

  // -------------------- MAP + CALL --------------------
  Future<void> _openMap(String? location) async {
    if (location == null || location.isEmpty) return;
    final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _callContact(String? contact) async {
    if (contact == null || contact.isEmpty) return;
    final Uri url = Uri(scheme: 'tel', path: contact);
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // -------------------- ADDRESS BUILDER --------------------
  String _joinAddress() {
    final p = widget.pg;

    final addr = (p['Address'] ?? '').toString().trim();
    final city = (p['City'] ?? '').toString().trim();
    final state = (p['State'] ?? '').toString().trim();
    final country = (p['Country'] ?? '').toString().trim();
    final pin = (p['Pincode'] ?? '').toString().trim();

    // Full address: Address + City + State + Country + Pincode
    final combined = [addr, city, state, country, pin].where((e) => e.isNotEmpty).join(', ');
    if (combined.isNotEmpty) return combined;

    // Fallback to any stored single-field full address / location if address parts are not present
    final hotelLocation = (p['Address_Full'] ?? p['Hotel_Location'] ?? p['PG_Location'] ?? '').toString().trim();
    return hotelLocation;
  }

  // Build map query string using latitude & longitude if available
  String _getMapQuery() {
    final p = widget.pg;

    final lat = (p['Latitude'] ?? p['latitude'] ?? p['PG_Latitude'] ?? '').toString().trim();
    final lng = (p['Longitude'] ?? p['longitude'] ?? p['PG_Longitude'] ?? '').toString().trim();

    if (lat.isNotEmpty && lng.isNotEmpty) {
      // Prefer latitude,longitude for map lookup
      return "$lat,$lng";
    }

    // Fallback to existing location string or full address
    return (p['Hotel_Location'] ?? p['PG_Location'] ?? _joinAddress()).toString();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  IconData _getAmenityIcon(String name) {
    switch (name.toLowerCase()) {
      case 'wifi':
        return Icons.wifi;
      case 'ac':
      case 'a/c':
        return Icons.ac_unit;
      case 'meals':
      case 'food':
        return Icons.restaurant;
      case 'parking':
        return Icons.local_parking;
      case 'security':
        return Icons.security;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'tv':
        return Icons.tv;
      case 'mess':
        return Icons.set_meal;
      default:
        return Icons.check_circle_outline;
    }
  }

  // -------------------- ROOM PRICE PARSER --------------------
  /// Accepts: Map, List, CSV string, JSON-string list
  Map<String, String> _extractRoomPrices() {
    final raw = widget.pg["Room_Prices"] ?? widget.pg["Room_Price"] ?? widget.pg["room_price"];
    if (raw == null) return {};
    try {
      List<String> parts = [];

      // If already a Map (e.g. {"Single":"4000","Double":"5000"})
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        // Normalize to our ordered slots where possible
        final result = <String, String>{};
        if (m.isNotEmpty) {
          m.forEach((k, v) {
            result[k.toString()] = v?.toString() ?? "N/A";
          });
        }
        // If map contains specific keys we'll return them
        if (result.isNotEmpty) return result.map((k, v) => MapEntry(_normalizeRoomKey(k), v));
      }

      // If it's a List
      if (raw is List) {
        parts = raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      } else if (raw is String) {
        final s = raw.trim();
        // Try JSON parse
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              parts = parsed.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {
            // fallback to comma split
            parts = s
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll('"', '')
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } else if (s.contains(',')) {
          parts = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else {
          // single price string, use as single-sharing
          parts = [s];
        }
      }

      // Default mapping by order: Single, Double, Three, Four, Five
      final Map<String, String> out = {
        "Single Sharing Room": parts.length > 0 ? parts[0] : "N/A",
        "Double Sharing Room": parts.length > 1 ? parts[1] : "N/A",
        "Three Sharing Room": parts.length > 2 ? parts[2] : "N/A",
        "Four Sharing Room": parts.length > 3 ? parts[3] : "N/A",
        "Five Sharing Room": parts.length > 4 ? parts[4] : "N/A",
      };

      return out;
    } catch (_) {
      return {};
    }
  }

  String _normalizeRoomKey(String k) {
    final lk = k.toLowerCase();
    if (lk.contains('single')) return "Single Sharing Room";
    if (lk.contains('double')) return "Double Sharing Room";
    if (lk.contains('three') || lk.contains('3')) return "Three Sharing Room";
    if (lk.contains('four') || lk.contains('4')) return "Four Sharing Room";
    if (lk.contains('five') || lk.contains('5')) return "Five Sharing Room";
    return k;
  }

  Widget _buildRatingStars(double rating) {
    int filled = rating.round().clamp(0, 5);
    return Row(
      children: List.generate(5, (index) {
        if (index < filled) {
          return const Icon(Icons.star, color: Colors.orange, size: 20);
        } else {
          return const Icon(Icons.star_border, color: Colors.orange, size: 20);
        }
      }),
    );
  }

  // -------------------- AMENITIES PARSER --------------------
  List<String> _parseAmenities(dynamic raw) {
    if (raw == null) return [];
    try {
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      if (raw is String) {
        final s = raw.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          try {
            final parsed = json.decode(s);
            if (parsed is List) {
              return parsed.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          } catch (_) {
            // fallback
          }
        }
        return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } catch (_) {}
    return [];
  }

  // -------------------- POLICIES WIDGET --------------------
  Widget _buildPoliciesWidget(String policies) {
    final trimmed = policies.trim();
    if (trimmed.isEmpty) {
      return const Text("No policies provided.");
    }

    // Split policies by comma and show as bullet points if more than one
    final List<String> items = trimmed
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (items.length <= 1) {
      // Single policy, show as plain text (old behavior)
      return Text(trimmed);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (p) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("• "),
            Expanded(child: Text(p)),
          ],
        ),
      )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pg = widget.pg;
    final user = widget.user;
    final address = _joinAddress();
    final pgName = pg['PG_Name'] ?? 'Unknown PG';
    final pgType = (pg['PG_Type'] ?? pg['PGType'] ?? '').toString();
    final roomTypeField = (pg['Room_Type'] ?? pg['RoomType'] ?? '').toString();
    final contact = (pg['PG_Contact'] ?? pg['Contact'] ?? "N/A").toString();
    final policies = (pg['Policies'] ?? pg['PG_Policies'] ?? pg['Rules'] ?? "").toString();
    final roomPrices = _extractRoomPrices();

    final availableCounts = {
      "Single Sharing Room":
      _toInt(pg['Total_Single_Sharing_Rooms'] ?? pg['Available_Single_Sharing_Rooms'] ?? pg['Available_Single'] ?? 0),
      "Double Sharing Room":
      _toInt(pg['Total_Double_Sharing_Rooms'] ?? pg['Available_Double_Sharing_Rooms'] ?? pg['Available_Double'] ?? 0),
      "Three Sharing Room":
      _toInt(pg['Total_Three_Sharing_Rooms'] ?? pg['Available_Three_Sharing_Rooms'] ?? pg['Available_Three'] ?? 0),
      "Four Sharing Room":
      _toInt(pg['Total_Four_Sharing_Rooms'] ?? pg['Available_Four_Sharing_Rooms'] ?? pg['Available_Four'] ?? 0),
      "Five Sharing Room": _toInt(
          pg['Total_Five_ShARING_ROOMS'] ?? pg['Total_Five_Sharing_Rooms'] ?? pg['Available_Five_Sharing_Rooms'] ?? pg['Available_Five'] ?? 0),
    };

    final amenitiesList = _parseAmenities(pg['Amenities']);

    double rating = 0;
    if (pg['Rating'] != null) {
      rating = double.tryParse(pg['Rating'].toString()) ?? 0;
    }

    // NOTE: Removed auto-selection of first available room type
    // so that "Book Now" is only shown after user manually selects a room.

    return Scaffold(
      backgroundColor: const Color(0xFFF7FFEA),
      appBar: AppBar(title: Text(pgName), backgroundColor: Colors.green[700]),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------- IMAGE SLIDER ----------------
                SizedBox(
                  height: 220,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.isEmpty ? 1 : images.length,
                    onPageChanged: (i) => setState(() => currentImageIndex = i),
                    itemBuilder: (_, index) {
                      if (images.isEmpty) {
                        return Container(
                          decoration:
                          BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
                        );
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: CircularProgressIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(child: Icon(Icons.broken_image, size: 40)),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),
                // ---------------- NAME + RATING ----------------
                Row(
                  children: [
                    Expanded(
                      child: Text(pgName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ),
                    _buildRatingStars(rating),
                  ],
                ),
                if (pgType.isNotEmpty) Text(pgType, style: TextStyle(color: Colors.grey[700])),
                //if (roomTypeField.isNotEmpty) Text("Room type: $roomTypeField", style: TextStyle(color: Colors.grey[700])),
                const SizedBox(height: 12),

                // Address
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _openMap(_getMapQuery()),
                      child: const Icon(Icons.location_on, color: Colors.green, size: 26),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Contact
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _callContact(contact),
                      child: const Icon(Icons.call, color: Colors.green, size: 26),
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(contact)),
                  ],
                ),
                const SizedBox(height: 18),

                // Rooms
                const Text("Rooms", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: roomPrices.keys.map((roomType) {
                      final price = roomPrices[roomType] ?? "N/A";
                      final available = availableCounts[roomType] ?? 0;
                      // show all room cards; no greying out, but disable tap if unavailable
                      return GestureDetector(
                        onTap: available > 0
                            ? () {
                          setState(() {
                            selectedRoomType = roomType;
                            selectedRoomPrice = price;
                          });
                        }
                            : null,
                        child: Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedRoomType == roomType ? Colors.green.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                                color: Colors.black.withOpacity(0.06),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.bed, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(
                                    child:
                                    Text(roomType, style: const TextStyle(fontWeight: FontWeight.bold))),
                              ]),
                              const Spacer(),
                              Text("Rs/$price",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                              const SizedBox(height: 6),
                              Text("$available available",
                                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Amenities
                const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                if (amenitiesList.isEmpty)
                  const Text("No amenities listed.")
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: amenitiesList
                        .map(
                          (a) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.green.shade50,
                            child: Icon(_getAmenityIcon(a), color: Colors.green, size: 20),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              a,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                        .toList(),
                  ),

                const SizedBox(height: 20),
                // About
                const Text("About PG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text(pg["About_This_PG"] ?? pg["Description"] ?? "No description available."),

                const SizedBox(height: 16),
                // Policies
                const Text("Policies", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                _buildPoliciesWidget(policies),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // Booking bar - only show after user selects a room type
          if (selectedRoomType.isNotEmpty)
            Positioned(
              bottom: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(selectedRoomType, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Rs/$selectedRoomPrice",
                          style: TextStyle(color: Colors.green.shade800)),
                    ]),
                    ElevatedButton(
                      onPressed: () {
                        // Deep copy to avoid mutating original map reference
                        final data = Map<String, dynamic>.from(pg);
                        // Put canonical address and location values
                        data["Address"] = address;
                        data["Hotel_Location"] =
                            widget.pg['Hotel_Location'] ?? widget.pg['PG_Location'] ?? address;
                        // Selected room details
                        data["Selected_Room_Type"] = selectedRoomType;
                        data["Selected_Room_Price"] = selectedRoomPrice;
                        // Pass policies explicitly
                        data["Policies"] = policies;
                        // Pass availability counts
                        data["Available_Counts"] = {
                          "Single": availableCounts["Single Sharing Room"] ?? 0,
                          "Double": availableCounts["Double Sharing Room"] ?? 0,
                          "Three": availableCounts["Three Sharing Room"] ?? 0,
                          "Four": availableCounts["Four Sharing Room"] ?? 0,
                          "Five": availableCounts["Five Sharing Room"] ?? 0,
                        };
                        // Ensure images are normalized and present
                        data["PG_Images"] = images;

                        Navigator.pushNamed(
                          context,
                          "/booking",
                          arguments: {
                            "pg": data,
                            "user": user,
                            "userId": user["userId"] ?? "",
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                        const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Book Now", style: TextStyle(fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
