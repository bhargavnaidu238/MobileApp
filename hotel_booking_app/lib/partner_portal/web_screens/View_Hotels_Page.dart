import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'add_hotels_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class ViewHotelsPage extends StatefulWidget {
  final String partnerId;
  const ViewHotelsPage({required this.partnerId, Key? key}) : super(key: key);

  @override
  State<ViewHotelsPage> createState() => _ViewHotelsPageState();
}

// ========= Fetch or View Hotels Section ===================
class _ViewHotelsPageState extends State<ViewHotelsPage> {
  List<Map<String, String>> hotels = [];
  List<String> selectedHotels = [];
  bool isLoading = true;
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    fetchHotels();
  }

  Future<void> fetchHotels() async {
    setState(() => isLoading = true);
    hotels.clear();

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webviewhotels'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: "partner_id=${Uri.encodeComponent(widget.partnerId)}",
      );

      String body = res.body.trim();
      if (body.contains("status=success&data=")) {
        String dataPart = body.split("data=").length > 1 ? body.split("data=")[1] : '';
        if (dataPart.isNotEmpty) {
          List<String> rows = dataPart.trim().split("\n");
          for (var row in rows) {
            List<String> cols = row.split("|").map((e) => e.trim()).toList();
            hotels.add({
              "Hotel_ID": cols.length > 0 ? cols[0] : '',
              "Partner_ID": cols.length > 1 ? cols[1] : '',
              "Hotel_Name": cols.length > 2 ? cols[2] : '',
              "Hotel_Type": cols.length > 3 ? cols[3] : '',
              "Address": cols.length > 4 ? cols[4] : '',
              "City": cols.length > 5 ? cols[5] : '',
              "State": cols.length > 6 ? cols[6] : '',
              "Country": cols.length > 7 ? cols[7] : '',
              "Pincode": cols.length > 8 ? cols[8] : '',
              "Total_Rooms": cols.length > 9 ? cols[9] : '',
              "Room_Price": cols.length > 10 ? cols[10] : '',
              "Amenities": cols.length > 11 ? cols[11] : '',
              "Description": cols.length > 12 ? cols[12] : '',
              "Rating": cols.length > 13 ? cols[13] : '0',
              "Hotel_Contact": cols.length > 14 ? cols[14] : '',
              "Status": cols.length > 15 ? cols[15] : '',
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching hotels: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      selectedHotels = selectAll ? hotels.map((h) => h['Hotel_ID']!).toList() : [];
    });
  }

  void toggleHotelSelection(String hotelId, bool? value) {
    setState(() {
      if (value == true) selectedHotels.add(hotelId);
      else selectedHotels.remove(hotelId);
      selectAll = selectedHotels.length == hotels.length;
    });
  }

  // =============== Delete Hotels Section =====================
  Future<void> confirmDelete() async {
    if (selectedHotels.isEmpty) return;

    bool confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${selectedHotels.length} hotel(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final idsStr = selectedHotels.join(",");
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webviewhotels'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: "hotel_ids=${Uri.encodeComponent(idsStr)}", // <-- multi-delete
      );

      fetchHotels();
      selectedHotels.clear();
      selectAll = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Hotels deleted successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  }

  Widget buildHotelRow(Map<String, String> hotel) {
    String fullAddress =
        "${hotel['Address']}, ${hotel['City']}, ${hotel['State']}, ${hotel['Country']} - ${hotel['Pincode']}";
    bool isSelected = selectedHotels.contains(hotel['Hotel_ID']);
    return Card(
      color: Colors.white.withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => toggleHotelSelection(hotel['Hotel_ID']!, v),
              activeColor: Colors.green.shade900,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel['Hotel_Name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(fullAddress, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Rooms: ${hotel['Total_Rooms']} | Price: ₹${hotel['Room_Price']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Hotel Type: ${hotel['Hotel_Type']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Amenities: ${hotel['Amenities']}", style: const TextStyle(color: Colors.white70)),
                  Text("Description: ${hotel['Description']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Status: ${hotel['Status']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade300, size: 18),
                      const SizedBox(width: 4),
                      Text(hotel['Rating'] ?? "N/A", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(width: 15),
                      Icon(Icons.phone, color: Colors.white70, size: 18),
                      const SizedBox(width: 4),
                      Text(hotel['Hotel_Contact'] ?? "N/A", style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C853), Color(0xFFB2FF59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white)),
                const SizedBox(width: 8),
                const Text("View Hotels", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: selectedHotels.length == 1
                      ? () {
                    final hotel = hotels.firstWhere((h) => h['Hotel_ID'] == selectedHotels[0]);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddHotelsPage(
                          partnerId: widget.partnerId,
                          hotelData: hotel,
                        ),
                      ),
                    ).then((value) {
                      fetchHotels();
                      selectedHotels.clear();
                      selectAll = false;
                    });
                  }
                      : null,
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: selectedHotels.isNotEmpty ? confirmDelete : null,
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddHotelsPage(partnerId: widget.partnerId))),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("Add Hotel"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(value: selectAll, onChanged: toggleSelectAll, activeColor: Colors.green.shade900),
                const Text("Select All", style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : hotels.isEmpty
                  ? const Center(child: Text("No hotels found.", style: TextStyle(color: Colors.white, fontSize: 18)))
                  : ListView.builder(
                itemCount: hotels.length,
                itemBuilder: (context, i) => buildHotelRow(hotels[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
