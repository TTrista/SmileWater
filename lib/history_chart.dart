
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'models/history_entry.dart';

class HistoryChartPage extends StatefulWidget {
  const HistoryChartPage({super.key});

  @override
  State<HistoryChartPage> createState() => _HistoryChartPageState();
}

class _HistoryChartPageState extends State<HistoryChartPage> {
  List<HistoryEntry> _records = [];
  final DateFormat formatter = DateFormat('MM-dd HH:mm');
  DateTimeRange? _selectedRange;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('records')
        .orderBy('time', descending: false)
        .get();

    final data = snapshot.docs.map((doc) {
      final raw = doc.data();
      final rawTime = raw['time'];
      final parsedTime = rawTime is Timestamp
          ? rawTime.toDate()
          : DateTime.tryParse(rawTime.toString()) ?? DateTime.now();
      return HistoryEntry(
        ph: (raw['ph'] as num).toDouble(),
        turbidity: (raw['turbidity'] as num).toDouble(),
        time: parsedTime,
      );
    }).toList();

    setState(() {
      _records = data;
      _isLoading = false;
    });
  }

  List<HistoryEntry> get _filteredRecords {
    if (_selectedRange == null) return _records;
    return _records.where((entry) {
      return entry.time.isAfter(_selectedRange!.start.subtract(const Duration(seconds: 1))) &&
             entry.time.isBefore(_selectedRange!.end.add(const Duration(seconds: 1)));
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (range != null) {
      setState(() {
        _selectedRange = range;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('History Chart')),
        body: const Center(child: Text('Please log in to view the chart')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Chart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
            tooltip: 'Select date range',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredRecords.isEmpty
              ? const Center(child: Text('No data in the selected range'))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (_selectedRange != null)
                        Text(
                          'Date Range:: ${DateFormat('MM/dd').format(_selectedRange!.start)} - ${DateFormat('MM/dd').format(_selectedRange!.end)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                axisNameWidget: const Text('	pH Value', style: TextStyle(fontSize: 12)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                              rightTitles: AxisTitles(
                                axisNameWidget: const Text('Turbidity (NTU)', style: TextStyle(fontSize: 12)),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 36,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    int i = value.toInt();
                                    if (i >= 0 && i < _filteredRecords.length) {
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Transform.rotate(
                                          angle: -0.5,
                                          child: Text(
                                            formatter.format(_filteredRecords[i].time),
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _filteredRecords.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.ph)).toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: _filteredRecords.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.turbidity)).toList(),
                                isCurved: true,
                                color: Colors.orange,
                                barWidth: 2,
                                dotData: FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, color: Colors.blue),
                          SizedBox(width: 6),
                          Text('	pH Trend'),
                          SizedBox(width: 20),
                          Icon(Icons.show_chart, color: Colors.orange),
                          SizedBox(width: 6),
                          Text('Turbidity Trend'),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}
