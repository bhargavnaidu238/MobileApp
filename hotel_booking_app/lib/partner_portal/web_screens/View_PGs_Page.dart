import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'add_PGs_page.dart';
import 'package:hotel_booking_app/services/api_service.dart';

class ViewPGsPage extends StatefulWidget {
  final String partnerId;
  const ViewPGsPage({required this.partnerId, Key? key}) : super(key: key);

  @override
  State<ViewPGsPage> createState() => _ViewPGsPageState();
}

class _ViewPGsPageState extends State<ViewPGsPage> {
  List<Map<String, String>> pgs = [];
  List<String> selectedPGs = [];
  bool isLoading = true;
  bool selectAll = false;

  @override
  void initState() {
    super.initState();
    fetchPgs();
  }

  Future<void> fetchPgs() async {
    setState(() => isLoading = true);
    pgs.clear();

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webviewpgs'),
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

            pgs.add({
              "PG_ID": cols.length > 0 ? cols[0] : '',
              "Partner_ID": cols.length > 1 ? cols[1] : '',
              "PG_Name": cols.length > 2 ? cols[2] : '',
              "PG_Type": cols.length > 3 ? cols[3] : '',
              "Room_Type": cols.length > 4 ? cols[4] : '',
              "Address": cols.length > 5 ? cols[5] : '',
              "City": cols.length > 6 ? cols[6] : '',
              "State": cols.length > 7 ? cols[7] : '',
              "Country": cols.length > 8 ? cols[8] : '',
              "Pincode": cols.length > 9 ? cols[9] : '',
              "Total_Single_Sharing_Rooms": cols.length > 10 ? cols[10] : '0',
              "Total_Double_Sharing_Rooms": cols.length > 11 ? cols[11] : '0',
              "Total_Three_Sharing_Rooms": cols.length > 12 ? cols[12] : '0',
              "Total_Four_Sharing_Rooms": cols.length > 13 ? cols[13] : '0',
              "Total_Five_Sharing_Rooms": cols.length > 14 ? cols[14] : '0',
              "Room_Price": cols.length > 15 ? cols[15] : '0',
              "Amenities": cols.length > 16 ? cols[16] : '',
              "Description": cols.length > 17 ? cols[17] : '',
              "Rating": cols.length > 18 ? cols[18] : '0',
              "Hotel_Contact": cols.length > 19 ? cols[19] : '',
              "Status": cols.length > 20 ? cols[20] : '',
              "Total_Rooms": cols.length > 21 ? cols[21] : '0',    // <-- Total Rooms
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching pgs: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      selectedPGs = selectAll ? pgs.map((h) => h['PG_ID']!).toList() : [];
    });
  }

  void togglePGSelection(String pgId, bool? value) {
    setState(() {
      if (value == true) selectedPGs.add(pgId);
      else selectedPGs.remove(pgId);
      selectAll = selectedPGs.length == pgs.length;
    });
  }

  Future<void> confirmDelete() async {
    if (selectedPGs.isEmpty) return;

    bool confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${selectedPGs.length} PG(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    try {
      final idsStr = selectedPGs.join(",");
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/webviewpgs'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: "pg_ids=${Uri.encodeComponent(idsStr)}",
      );

      fetchPgs();
      selectedPGs.clear();
      selectAll = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PGs deleted successfully.")),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting: $e")),
      );
    }
  }

  Widget buildPGRow(Map<String, String> pg) {
    String fullAddress =
        "${pg['Address']}, ${pg['City']}, ${pg['State']}, ${pg['Country']} - ${pg['Pincode']}";
    bool isSelected = selectedPGs.contains(pg['PG_ID']);

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
              onChanged: (v) => togglePGSelection(pg['PG_ID']!, v),
              activeColor: Colors.green.shade900,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pg['PG_Name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text("PG Type: ${pg['PG_Type']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text(fullAddress, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Room Types: ${pg['Room_Type']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Total Rooms: ${pg['Total_Rooms']} | Price: ₹${pg['Room_Price']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Amenities: ${pg['Amenities']}", style: const TextStyle(color: Colors.white70)),
                  Text("Description: ${pg['Description']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text("Status: ${pg['Status']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade300, size: 18),
                      const SizedBox(width: 4),
                      Text(pg['Rating'] ?? "N/A", style: const TextStyle(color: Colors.white70)),
                      const SizedBox(width: 15),
                      Icon(Icons.phone, color: Colors.white70, size: 18),
                      const SizedBox(width: 4),
                      Text(pg['Hotel_Contact'] ?? "N/A", style: const TextStyle(color: Colors.white70)),
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
                const Text("View PGs", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: selectedPGs.length == 1
                      ? () {
                    final pg = pgs.firstWhere((h) => h['PG_ID'] == selectedPGs[0]);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddPGSPage(partnerId: widget.partnerId, pgData: pg),
                      ),
                    ).then((value) {
                      fetchPgs();
                      selectedPGs.clear();
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
                  onPressed: selectedPGs.isNotEmpty ? confirmDelete : null,
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.8),
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddPGSPage(partnerId: widget.partnerId))),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text("Add PG"),
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
                  : pgs.isEmpty
                  ? const Center(child: Text("No PG's found.", style: TextStyle(color: Colors.white, fontSize: 18)))
                  : ListView.builder(
                itemCount: pgs.length,
                itemBuilder: (context, i) => buildPGRow(pgs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
