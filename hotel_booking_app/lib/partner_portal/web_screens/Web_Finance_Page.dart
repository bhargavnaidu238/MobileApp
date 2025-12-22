import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:hotel_booking_app/services/api_service.dart';

class FinancePage extends StatefulWidget {
  final String partnerId;
  const FinancePage({required this.partnerId, Key? key}) : super(key: key);

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool isLoading = true;
  bool bankExpanded = false;

  Map<String, dynamic> financeData = {};
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> filteredBookings = [];
  String selectedBookingFilter = "All";
  String bookingDateRange = "All"; // All, 30, 90

  // Pagination for transactions
  int txPage = 1;
  int txPageSize = 10;

  final TextEditingController accountHolderController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController panController = TextEditingController();
  final TextEditingController commentsController = TextEditingController();
  final TextEditingController payoutAmountController = TextEditingController();

  // Dropdown selected values (local state)
  String selectedAccountType = 'Savings';
  String selectedPayoutType = 'Monthly';
  bool autoPayout = false;

  final double minimumWithdrawal = 5000.0;

  // Helper lists
  final List<String> payoutTypeOptions = [
    "Daily",
    "Weekly",
    "Fornight",
    "Monthly",
    "Quarterly"
  ];
  final List<String> accountTypeOptions = ["Savings", "Current"];

  @override
  void initState() {
    super.initState();
    fetchFinanceData();
    fetchTransactions();
  }

  // ---------- Backend Calls ----------
  Future<void> fetchFinanceData() async {
    setState(() => isLoading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/getPartnerFinance?partner_id=${widget
            .partnerId}'),
      );
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final data = jsonDecode(res.body);
        setState(() {
          financeData = Map<String, dynamic>.from(data ?? {});
          // Populate controllers & local dropdowns with safe defaults
          accountHolderController.text =
              financeData['Account_Holder_Name']?.toString() ?? '';
          bankNameController.text = financeData['Bank_Name']?.toString() ?? '';
          accountNumberController.text =
              financeData['Account_Number']?.toString() ?? '';
          ifscController.text = financeData['IFSC_SWIFT']?.toString() ?? '';
          panController.text = financeData['PAN_Tax_ID']?.toString() ?? '';
          selectedAccountType =
              financeData['Account_Type']?.toString() ?? selectedAccountType;
          selectedPayoutType =
              financeData['Payout_Type']?.toString() ?? selectedPayoutType;
          autoPayout = (financeData['Auto_Payout'] == true ||
              financeData['Auto_Payout']?.toString() == '1');
          filteredBookings = _applyBookingFilters(
              List<Map<String, dynamic>>.from(financeData['Bookings'] ?? []));
        });
      }
    } catch (e) {
      //debugPrint("Error fetching finance data: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching finance data: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchTransactions() async {
    try {
      final res = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/getPartnerTransactions?partner_id=${widget
                .partnerId}'),
      );

      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);

        List txList = [];

        // Case 1: backend returns {"transactions":[]}
        if (decoded is Map && decoded["transactions"] is List) {
          txList = decoded["transactions"];
        }

        // Case 2: backend returns {"data":[]}
        else if (decoded is Map && decoded["data"] is List) {
          txList = decoded["data"];
        }

        // Case 3: backend returns plain list []
        else if (decoded is List) {
          txList = decoded;
        }

        setState(() {
          transactions = List<Map<String, dynamic>>.from(txList);
          txPage = 1;
        });
      }
    } catch (e) {
      //debugPrint("❌ fetchTransactions ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ fetchTransactions ERROR: $e")));
    }
  }


  // ---------- Utilities ----------
  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(',', '').replaceAll('₹', '').trim();
    return double.tryParse(s) ?? 0.0;
  }

  String _formatCurrency(dynamic val) {
    final d = _parseDouble(val);
    final fixed = d.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      final pos = intPart.length - i;
      buf.write(intPart[i]);
      if (pos > 1 && pos % 3 == 1) buf.write(',');
    }
    return '₹$fixed';
  }

  List<Map<String, dynamic>> _applyBookingFilters(
      List<Map<String, dynamic>> bookings) {
    var list = bookings;
    if (bookingDateRange == "30") {
      final cutoff = DateTime.now().subtract(Duration(days: 30));
      list = list.where((b) {
        final dt = _tryParseDate(
            b['Booking_Date'] ?? b['Check_In'] ?? b['Transaction_Date']);
        return dt != null && dt.isAfter(cutoff);
      }).map((b) => Map<String, dynamic>.from(b)).toList();
    } else if (bookingDateRange == "90") {
      final cutoff = DateTime.now().subtract(Duration(days: 90));
      list = list.where((b) {
        final dt = _tryParseDate(
            b['Booking_Date'] ?? b['Check_In'] ?? b['Transaction_Date']);
        return dt != null && dt.isAfter(cutoff);
      }).map((b) => Map<String, dynamic>.from(b)).toList();
    } else {
      list = list.map((b) => Map<String, dynamic>.from(b)).toList();
    }

    if (selectedBookingFilter != "All") {
      list = list
          .where((b) =>
      (b['Booking_Status'] ?? '').toString().toLowerCase() ==
          selectedBookingFilter.toLowerCase())
          .map((b) => Map<String, dynamic>.from(b))
          .toList();
    }
    return list;
  }

  DateTime? _tryParseDate(dynamic x) {
    if (x == null) return null;
    try {
      if (x is DateTime) return x;
      final s = x.toString();
      return DateTime.parse(s);
    } catch (e) {
      try {
        final s = x.toString();
        if (s.contains('-') || s.contains('/')) {
          final sep = s.contains('-') ? '-' : '/';
          final parts = s.split(sep);
          if (parts.length >= 3) {
            final d = int.tryParse(parts[0]);
            final m = int.tryParse(parts[1]);
            final y = int.tryParse(parts[2]);
            if (d != null && m != null && y != null) return DateTime(y, m, d);
          }
        }
      } catch (_) {}
      return null;
    }
  }

  // ---------- UI Helper Widgets ----------
  Widget buildFinanceCard(String title, String value, Color color,
      {IconData? icon}) {
    double parsedValue = 0;
    bool isPercent = value.contains('%');
    if (isPercent) {
      parsedValue =
          double.tryParse(value.replaceAll('%', '').replaceAll(',', '')) ?? 0;
    } else {
      parsedValue =
          double.tryParse(value.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white70, size: 32),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                    color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: parsedValue),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, val, child) {
                    final display = isPercent
                        ? '${val.toStringAsFixed(2)}%'
                        : _formatCurrency(val);
                    return Text(display,
                        style: const TextStyle(color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold));
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTextField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white.withOpacity(0.12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.shade900, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _statusChip(String text) {
    final t = text.toLowerCase();
    Color bg = Colors.grey;
    Color fg = Colors.white;
    if (t.contains('paid') || t.contains('success') ||
        t.contains('completed')) {
      bg = Colors.green.shade700;
    } else if (t.contains('pending') || t.contains('processing')) {
      bg = Colors.orange.shade700;
    } else if (t.contains('failed') || t.contains('cancel')) {
      bg = Colors.red.shade700;
    } else if (t.contains('confirmed')) {
      bg = Colors.blue.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
          text, style: TextStyle(color: fg, fontWeight: FontWeight.bold)),
    );
  }

  // ---------- Update Bank Details ----------
  Future<void> updateBankDetails() async {
    final body = {
      'partner_id': widget.partnerId,
      'Account_Holder_Name': accountHolderController.text.trim(),
      'Bank_Name': bankNameController.text.trim(),
      'Account_Number': accountNumberController.text.trim(),
      'IFSC_SWIFT': ifscController.text.trim(),
      'PAN_Tax_ID': panController.text.trim(),
      'Account_Type': selectedAccountType,
      'Payout_Type': selectedPayoutType,
      'Auto_Payout': autoPayout ? '1' : '0',
    };
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/updateBankDetails'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
      final data = jsonDecode(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(data['message']?.toString() ?? "Update complete")),
      );
      if (data['status'] == 'success') fetchFinanceData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ---------- Request Payout ----------
  Future<void> requestPayout() async {
    double pending = _parseDouble(
        financeData['Pending_Payout'] ?? financeData['PendingPayout'] ?? 0);

    // ❗ Block empty request
    if (payoutAmountController.text
        .trim()
        .isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter withdrawal amount")),
      );
      return;
    }

    double? requestedAmount = double.tryParse(
        payoutAmountController.text.trim());
    if (requestedAmount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invalid amount entered")),
      );
      return;
    }

    if (requestedAmount > pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "Requested amount cannot exceed available pending ${_formatCurrency(
                pending)}")),
      );
      return;
    }

    if (requestedAmount < minimumWithdrawal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "Minimum withdrawal is ${_formatCurrency(minimumWithdrawal)}")),
      );
      return;
    }

    final body = {
      'partner_id': widget.partnerId,
      'amount': requestedAmount.toString(),
      'comments': commentsController.text.trim(),
    };

    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/requestPayout'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      final data = jsonDecode(res.body);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? "Error")),
      );

      if (data['status'] == 'success') {
        fetchFinanceData();
        fetchTransactions();
        commentsController.clear();
        payoutAmountController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }


  // ---------- Transactions: CSV Export ----------
  Future<void> exportTransactionsCSV() async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No transactions to export")));
      return;
    }

    final cols = <String>{};
    for (var t in transactions)
      cols.addAll(t.keys);
    final headers = cols.toList();

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (var t in transactions) {
      final row = headers.map((h) {
        final v = t[h];
        final s = v == null ? '' : v.toString().replaceAll('"', '""');
        if (s.contains(',') || s.contains('\n')) return '"$s"';
        return s;
      }).join(',');
      buffer.writeln(row);
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("CSV copied to clipboard (paste into a file).")),
    );
  }

  // ---------- UI Builders for Tables ----------
  Widget buildBookingsTable() {
    if (filteredBookings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text("No bookings found", style: TextStyle(color: Colors.white)),
      );
    }

    final columns = <String>{};
    for (var b in filteredBookings) {
      columns.addAll(b.keys);
    }

    final headers = columns.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.green.shade700),
        headingTextStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold),
        dataRowHeight: 60,
        columns: headers
            .map((key) =>
            DataColumn(
                label: Text(key, style: const TextStyle(color: Colors.white))))
            .toList(),
        rows: filteredBookings.map((b) {
          final status = (b['Booking_Status'] ?? b['Status'] ?? '').toString();
          return DataRow(
            color: MaterialStateProperty.resolveWith<Color?>((states) {
              final s = status.toLowerCase();
              if (s.contains('completed'))
                return Colors.green.withOpacity(0.18);
              if (s.contains('pending')) return Colors.orange.withOpacity(0.18);
              if (s.contains('confirmed')) return Colors.blue.withOpacity(0.18);
              if (s.contains('cancel')) return Colors.red.withOpacity(0.18);
              return Colors.grey.withOpacity(0.08);
            }),
            cells: headers.map((key) {
              String value = b[key]?.toString() ?? '';
              if (key.toLowerCase() == 'booking_status' ||
                  key.toLowerCase() == 'status') {
                return DataCell(_statusChip(value));
              }
              return DataCell(Text(value, style: const TextStyle(color: Colors
                  .white)));
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget buildTransactionsTable() {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
            "No transactions found", style: TextStyle(color: Colors.white)),
      );
    }

    final columns = <String>{};
    for (var tx in transactions) {
      columns.addAll(tx.keys);
    }
    final headers = headersFromSet(columns);

    final totalPages = max(1, (transactions.length / txPageSize).ceil());
    final start = (txPage - 1) * txPageSize;
    final end = min(start + txPageSize, transactions.length);
    final pageItems = transactions.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.green.shade700),
            headingTextStyle: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            columns: headers
                .map((key) =>
                DataColumn(label: Text(key, style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold))))
                .toList(),
            rows: pageItems.map((tx) {
              return DataRow(
                cells: headers.map((key) {
                  String value = tx[key]?.toString() ?? '';
                  Color textColor = Colors.white;
                  if (key.toLowerCase() == 'status') {
                    final v = value.toLowerCase();
                    if (v.contains('paid') || v.contains('success'))
                      textColor = Colors.greenAccent;
                    else if (v.contains('pending'))
                      textColor = Colors.yellowAccent;
                    else if (v.contains('failed') || v.contains('fail'))
                      textColor = Colors.redAccent;
                  }
                  return DataCell(Text(
                      value, style: TextStyle(color: textColor)));
                }).toList(),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Showing ${start + 1} - $end of ${transactions.length}",
                style: const TextStyle(color: Colors.white70)),
            Row(
              children: [
                IconButton(
                  onPressed: txPage > 1 ? () => setState(() => txPage--) : null,
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                ),
                Text("$txPage / $totalPages",
                    style: const TextStyle(color: Colors.white)),
                IconButton(
                  onPressed: txPage < totalPages ? () =>
                      setState(() => txPage++) : null,
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  dropdownColor: Colors.green.shade700,
                  value: txPageSize,
                  items: [5, 10, 25, 50]
                      .map((s) =>
                      DropdownMenuItem(value: s,
                          child: Text("$s",
                              style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() {
                      txPageSize = v;
                      txPage = 1;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: exportTransactionsCSV,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade800),
                  child: const Text("Export CSV"),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<String> headersFromSet(Set<String> set) {
    // Keep stable order when rendering headers
    return set.toList();
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final pending = _parseDouble(
        financeData['Pending_Payout'] ?? financeData['PendingPayout'] ?? 0);
    final totalRevenue = _parseDouble(
        financeData['Total_Revenue'] ?? financeData['TotalRevenue'] ?? 0);
    final netRevenue = _parseDouble(
        financeData['Net_Revenue'] ?? financeData['NetRevenue'] ?? 0);
    final paidPayout = _parseDouble(
        financeData['Paid_Payout'] ?? financeData['PaidPayout'] ?? 0);
    final commission = _parseDouble(financeData['Commission_Percentage'] ??
        financeData['CommissionPercentage'] ?? 0);
    final lastPayoutDateRaw = financeData['Last_Payout_Date'] ??
        financeData['LastPayoutDate'];
    String lastPayoutDate = '';
    try {
      final dt = _tryParseDate(lastPayoutDateRaw);
      if (dt != null) lastPayoutDate = dt.toLocal().toString().split(' ')[0];
    } catch (_) {}

    final balancePayout = netRevenue - paidPayout;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Partner Finance"),
        backgroundColor: Colors.green.shade700,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00C853), Color(0xFFB2FF59)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
          onRefresh: () async {
            await fetchFinanceData();
            await fetchTransactions();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Summary", style: TextStyle(color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final spacing = 16.0;
                  final totalSpacing = spacing * 2; // left/right rough
                  final cardWidth = max(
                      240.0, (constraints.maxWidth - totalSpacing) / 3 - 12);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Total Revenue", _formatCurrency(totalRevenue),
                          Colors.blueAccent, icon: Icons.show_chart)),
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Commission %", "${commission.toStringAsFixed(2)}%",
                          Colors.deepPurple, icon: Icons.monetization_on)),
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Net Revenue", _formatCurrency(netRevenue),
                          Colors.green.shade700,
                          icon: Icons.account_balance_wallet)),
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Pending Payout", _formatCurrency(pending),
                          Colors.orange.shade700, icon: Icons.schedule)),
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Last Paid Payout", _formatCurrency(paidPayout),
                          Colors.redAccent, icon: Icons.calendar_today)),
                      SizedBox(width: cardWidth, child: buildFinanceCard(
                          "Balance Payout", _formatCurrency(balancePayout),
                          Colors.teal.shade700, icon: Icons.account_balance)),
                    ],
                  );
                }),
                const SizedBox(height: 20),

                Card(
                  color: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    initiallyExpanded: bankExpanded,
                    onExpansionChanged: (val) =>
                        setState(() => bankExpanded = val),
                    title: const Text("Update Bank Details",
                        style: TextStyle(color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            buildTextField(
                                accountHolderController, "Account Holder Name"),
                            const SizedBox(height: 12),
                            buildTextField(bankNameController, "Bank Name"),
                            const SizedBox(height: 12),
                            buildTextField(
                                accountNumberController, "Account Number",
                                isNumber: true),
                            const SizedBox(height: 12),
                            buildTextField(ifscController, "IFSC / SWIFT"),
                            const SizedBox(height: 12),
                            // Account Type Dropdown (ensure visible items)
                            DropdownButtonFormField<String>(
                              value: selectedAccountType,
                              dropdownColor: Colors.white,
                              decoration: InputDecoration(
                                labelText: "Account Type",
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              style: const TextStyle(color: Colors.black),
                              items: accountTypeOptions
                                  .map((v) =>
                                  DropdownMenuItem(value: v,
                                      child: Text(v, style: const TextStyle(
                                          color: Colors.black))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() =>
                                selectedAccountType = v);
                              },
                            ),
                            const SizedBox(height: 12),
                            buildTextField(panController, "PAN / Tax ID"),
                            const SizedBox(height: 12),
                            // Payout Type Dropdown (fixed visibility)
                            DropdownButtonFormField<String>(
                              value: selectedPayoutType,
                              dropdownColor: Colors.white,
                              decoration: InputDecoration(
                                labelText: "Payout Type",
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              style: const TextStyle(color: Colors.black),
                              items: payoutTypeOptions
                                  .map((v) =>
                                  DropdownMenuItem(value: v,
                                      child: Text(v, style: const TextStyle(
                                          color: Colors.black))))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() =>
                                selectedPayoutType = v);
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text("Auto Payout",
                                        style: TextStyle(color: Colors.white)),
                                    const SizedBox(width: 12),
                                    Switch(
                                      value: autoPayout,
                                      onChanged: (v) =>
                                          setState(() => autoPayout = v),
                                      activeColor: Colors.greenAccent,
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: updateBankDetails,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade800),
                                  child: const Text("Save Bank Details"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Card(
                  color: Colors.white.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Request Payout", style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text("Available Balance: ${_formatCurrency(pending)}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: payoutAmountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Enter Amount",
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: commentsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: "Comments (optional)",
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: requestPayout,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade800),
                          child: const Text("Submit Payout Request"),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Transactions", style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                    Row(children: [
                      IconButton(
                        onPressed: fetchTransactions,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                    ])
                  ],
                ),
                const SizedBox(height: 12),
                buildTransactionsTable(),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Bookings", style: TextStyle(color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: selectedBookingFilter,
                          dropdownColor: Colors.green.shade700,
                          items: [
                            "All",
                            "Confirmed",
                            "Pending",
                            "Completed",
                            "Cancelled"
                          ]
                              .map((e) =>
                              DropdownMenuItem(value: e,
                                  child: Text(e, style: const TextStyle(
                                      color: Colors.white))))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() {
                              selectedBookingFilter = v;
                              filteredBookings = _applyBookingFilters(
                                  List<Map<String, dynamic>>.from(
                                      financeData['Bookings'] ?? []));
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: bookingDateRange,
                          dropdownColor: Colors.green.shade700,
                          items: [
                            DropdownMenuItem(value: "All",
                                child: Text("All", style: const TextStyle(
                                    color: Colors.white))),
                            DropdownMenuItem(value: "30",
                                child: Text("Last 30d", style: const TextStyle(
                                    color: Colors.white))),
                            DropdownMenuItem(value: "90",
                                child: Text("Last 90d", style: const TextStyle(
                                    color: Colors.white))),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() {
                              bookingDateRange = v;
                              filteredBookings = _applyBookingFilters(
                                  List<Map<String, dynamic>>.from(
                                      financeData['Bookings'] ?? []));
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              filteredBookings = _applyBookingFilters(
                                  List<Map<String, dynamic>>.from(
                                      financeData['Bookings'] ?? []));
                            });
                          },
                          icon: const Icon(Icons.filter_list, color: Colors
                              .white),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                buildBookingsTable(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}