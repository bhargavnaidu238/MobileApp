import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class HotelDetailsPage extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final Map<String, dynamic> user;

  const HotelDetailsPage({
    required this.hotel,
    required this.user,
    Key? key,
  }) : super(key: key);

  @override
  State<HotelDetailsPage> createState() => _HotelDetailsPageState();
}

class _HotelDetailsPageState extends State<HotelDetailsPage> {
  late List<String> images;
  int currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    images = _parseImages(widget.hotel['Hotel_Images']);
  }

  // -----------------------
  // Image parsing + resolver
  // -----------------------
  List<String> _parseImages(dynamic raw) {
    if (raw == null) return [];

    // If it's already a list of URLs
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .map(_resolveImageUrl)
          .toList();
    }

    // If it's a JSON array string or comma-separated string
    String s = raw.toString().trim();

    // Remove surrounding brackets/quotes if present
    if (s.startsWith('[') && s.endsWith(']')) {
      s = s.substring(1, s.length - 1);
    }
    s = s.replaceAll('"', '');

    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map(_resolveImageUrl)
        .toList();

    return parts;
  }

  String _resolveImageUrl(String url) {

    url = url.trim().replaceAll('\\', '/');
    url = url.replaceAll(RegExp(r'^\[+'), '').replaceAll(RegExp(r'\]+$'), '');

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    final path = url.startsWith('/') ? url.substring(1) : url;
    return '${ApiConfig.baseUrl}/hotel_images/$path';
  }

  // Open directions (Hotel_Location is "lat,lon")
  Future<void> _openDirections() async {
    final rawLoc = widget.hotel['Hotel_Location'] ??
        widget.hotel['location'] ??
        widget.hotel['Hotel_Location'.toLowerCase()];

    if (rawLoc == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No location available for this hotel')));
      }
      return;
    }

    final loc = rawLoc.toString().trim();

    // Expect "lat,lon"
    final parts = loc.split(',').map((s) => s.trim()).toList();
    if (parts.length < 2) {
      // not lat/lon format: try using as freeform address
      final url = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(loc)}");
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open maps for this location')));
        }
        return;
      }
    }

    final lat = parts[0];
    final lon = parts[1];
    final destination = '$lat,$lon';

    // Use Google Maps directions URL. Omitting origin uses device current location.
    final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=driving');

    // On Android this should open the Google Maps app; on iOS the Maps app or browser.
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open maps app')));
      }
    }
  }

  // -----------------------
  // Call phone number
  // -----------------------
  Future<void> _callContact(String? contact) async {
    if (contact == null || contact.toString().trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No contact available')));
      return;
    }
    final Uri url = Uri(scheme: 'tel', path: contact.toString().trim());
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place call')));
    }
  }

  // -----------------------
  // Address joiner
  // -----------------------
  String _joinAddress() {
    final h = widget.hotel;
    final a = (h['Address'] ?? h['Hotel_Address'] ?? '').toString();
    final city = (h['City'] ?? '').toString();
    final state = (h['State'] ?? '').toString();
    final country = (h['Country'] ?? '').toString();
    final pin = (h['Pincode'] ?? h['PinCode'] ?? '').toString();
    final parts = [a, city, state, country, pin].where((e) => e.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  // -----------------------
  // Amenity icon mapper
  // -----------------------
  IconData _amenityIcon(String amenity) {
    final s = amenity.toLowerCase();
    if (s.contains('wifi')) return Icons.wifi;
    if (s.contains('ac')) return Icons.ac_unit;
    if (s.contains('parking')) return Icons.local_parking;
    if (s.contains('meals') || s.contains('food') || s.contains('restaurant')) return Icons.restaurant;
    if (s.contains('pool')) return Icons.pool;
    if (s.contains('gym')) return Icons.fitness_center;
    if (s.contains('elevator') || s.contains('lift')) return Icons.elevator;
    if (s.contains('geyser') || s.contains('hot water') || s.contains('water')) return Icons.water;
    if (s.contains('fridge') || s.contains('refrigerator')) return Icons.kitchen;
    if (s.contains('tv')) return Icons.tv;
    if (s.contains('washing') || s.contains('laundry')) return Icons.local_laundry_service;
    if (s.contains('power') || s.contains('backup')) return Icons.battery_charging_full;
    return Icons.check_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final user = widget.user;
    final address = _joinAddress();

    // Rooms parsing (keeps original behavior)
    List<String> roomTypes = [];
    List<String> roomPrices = [];
    if (hotel['Room_Type'] != null) {
      roomTypes = hotel['Room_Type'].toString().split(',').map((e) => e.trim()).toList();
    }
    if (hotel['Room_Price'] != null) {
      roomPrices = hotel['Room_Price'].toString().split(',').map((e) => e.trim()).toList();
    }

    // Amenities list
    List<String> amenities = [];
    if (hotel['Amenities'] != null && hotel['Amenities'].toString().isNotEmpty) {
      amenities = hotel['Amenities'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final hotelName = hotel['Hotel_Name'] ?? hotel['hotelName'] ?? 'Unknown Hotel';
    final ratingVal = (hotel['Rating'] ?? hotel['rating'] ?? '0').toString();
    final ratingDouble = double.tryParse(ratingVal) ?? 0.0;
    final ratingInt = ratingDouble.floor();
    final contact = hotel['Hotel_Contact'] ?? hotel['hotel_contact'] ?? hotel['Contact'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FFEA),
      appBar: AppBar(
        title: Text(hotelName, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.green[700],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images carousel
              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.isEmpty ? 1 : images.length,
                      onPageChanged: (index) => setState(() => currentImageIndex = index),
                      itemBuilder: (context, index) {
                        if (images.isEmpty) {
                          return Container(
                            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                            child: const Center(child: Icon(Icons.image, size: 80, color: Colors.grey)),
                          );
                        }

                        final imgUrl = images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imgUrl,
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
                                child: const Center(child: Icon(Icons.broken_image, size: 60)),
                              );
                            },
                          ),
                        );
                      },
                    ),

                    // Left arrow
                    if (images.length > 1 && currentImageIndex > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (currentImageIndex > 0) {
                              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            }
                          },
                          child: Container(width: 40, color: Colors.black.withOpacity(0.2), child: const Icon(Icons.chevron_left, color: Colors.white, size: 36)),
                        ),
                      ),

                    // Right arrow
                    if (images.length > 1 && currentImageIndex < images.length - 1)
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () {
                            if (currentImageIndex < images.length - 1) {
                              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                            }
                          },
                          child: Container(width: 40, color: Colors.black.withOpacity(0.2), child: const Icon(Icons.chevron_right, color: Colors.white, size: 36)),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Hotel title + rating row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(hotelName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  // Always show 5 stars; filled count based on ratingInt
                  Row(
                    children: List.generate(5, (i) {
                      if (i < ratingInt) {
                        return const Icon(Icons.star, size: 20, color: Colors.orangeAccent);
                      } else {
                        return const Icon(Icons.star_border, size: 20, color: Colors.orangeAccent);
                      }
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              if ((hotel['Hotel_Type'] ?? '').toString().isNotEmpty)
                Text(hotel['Hotel_Type'].toString(), style: TextStyle(color: Colors.grey[700])),

              const SizedBox(height: 12),

              // Highlights row (unchanged)
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: const [
                _HighlightIcon(icon: Icons.settings, label: "Customization"),
                _HighlightIcon(icon: Icons.restaurant, label: "Meals"),
                _HighlightIcon(icon: Icons.wifi, label: "WiFi"),
              ]),

              const SizedBox(height: 16),

              // Address + map icon (map icon opens directions using Hotel_Location lat,lon)
              Row(
                children: [
                  GestureDetector(
                    onTap: _openDirections,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.location_on, color: Colors.green, size: 26),
                    ),
                  ),
                  Expanded(child: Text(address, style: const TextStyle(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ],
              ),

              const SizedBox(height: 8),

              // Contact row: telephone icon + contact
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _callContact(contact?.toString()),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(Icons.call, color: Colors.green, size: 26),
                    ),
                  ),
                  Expanded(child: Text(contact?.toString() ?? 'N/A', style: const TextStyle(fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),

              const SizedBox(height: 18),

              // Room Cards (unchanged), but show "Starts from ₹{value}/month" in listing
              roomTypes.isEmpty
                  ? Text("No rooms available", style: TextStyle(fontSize: 16, color: Colors.grey.shade600))
                  : SizedBox(
                height: 260,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.88),
                  itemCount: roomTypes.length,
                  itemBuilder: (context, index) {
                    final roomType = roomTypes[index];
                    final roomPrice = index < roomPrices.length ? roomPrices[index] : 'N/A';
                    return LayoutBuilder(builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth;
                      return Center(
                        child: Container(
                          width: cardWidth,
                          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Card(
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(
                                    child: Text(roomType, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Text("₹$roomPrice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                ]),
                                const SizedBox(height: 10),
                                Flexible(
                                  child: SingleChildScrollView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    child: Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: amenities
                                          .map((e) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(_amenityIcon(e), size: 14, color: Colors.green.shade800),
                                          const SizedBox(width: 6),
                                          Text(e, style: const TextStyle(fontSize: 12)),
                                        ]),
                                      ))
                                          .toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  SizedBox(
                                    height: 42,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final selectedHotel = Map<String, dynamic>.from(hotel);
                                        selectedHotel['Room_Type'] = roomType;
                                        selectedHotel['Room_Price'] = roomPrice;
                                        selectedHotel['Hotel_Address'] = address;

                                        Navigator.pushNamed(context, '/booking', arguments: {
                                          'hotel': selectedHotel,
                                          'user': user,
                                          'userId': user['userId'] ?? '',
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: const Text("Book", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              // About
              const Text("About Hotel", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(hotel['Description'] ?? hotel['description'] ?? 'No description available.', style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HighlightIcon({required this.icon, required this.label, Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Colors.green, size: 28),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
