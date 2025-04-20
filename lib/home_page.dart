import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'models/history_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatefulWidget {
  final Function(HistoryEntry)? onNewRecord;

  const HomePage({super.key, this.onNewRecord});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  final _targetDeviceName = "SmileWater";
  final _serviceUuid = Uuid.parse("12345678-1234-1234-1234-1234567890ab");
  final _characteristicUuid = Uuid.parse(
    "abcd1234-1234-1234-1234-abcdef123456",
  );

  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectSub;
  StreamSubscription<List<int>>? _dataSub;
  QualifiedCharacteristic? _rxChar;

  String? _connectedDeviceName;
  double? _ph;
  double? _turb;
  List<int>? _latestValue;
  DateTime lastMeasured = DateTime.now();
  bool _firstReadDone = false;

  final double infoBlockPadding = 16.0;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for Bluetooth.'),
        ),
      );
    }
  }

  void _startBleScan() {
    _scanSub?.cancel();
    _scanSub = flutterReactiveBle
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .listen((device) {
          if (device.name == _targetDeviceName) {
            _scanSub?.cancel();
            _connectToDevice(device);
          }
        });
  }

  void _connectToDevice(DiscoveredDevice device) {
    _connectedDeviceName = device.name;
    _connectSub?.cancel();
    _connectSub = flutterReactiveBle
        .connectToDevice(id: device.id)
        .listen(
          (event) {
            if (event.connectionState == DeviceConnectionState.connected) {
              _rxChar = QualifiedCharacteristic(
                deviceId: device.id,
                serviceId: _serviceUuid,
                characteristicId: _characteristicUuid,
              );
              _startListening();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Connected: ${device.name}")),
              );
            }
          },
          onError: (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Connection failed: $e")));
          },
        );
  }

  void _startListening() {
    if (_rxChar == null) return;

    _dataSub = flutterReactiveBle
        .subscribeToCharacteristic(_rxChar!)
        .listen(
          (value) {
            _latestValue = value;
            if (!_firstReadDone) {
              _parseAndUpdate();
              _firstReadDone = true;
            }
          },
          onError: (e) {
            debugPrint("Failed to listen: $e");
          },
        );
  }

  double mapVoltageToNTU(double voltage) {
    if (voltage > 4.2 && voltage <= 4.5) {
      return (voltage - 4.2) * (5 / 0.3);
    } else if (voltage > 3.0 && voltage <= 4.2) {
      return 5 + (voltage - 3.0) * (45 / 1.2);
    } else if (voltage > 1.0 && voltage <= 3.0) {
      return 50 + (voltage - 1.0) * (50 / 2);
    } else if (voltage <= 1.0) {
      return 100;
    } else {
      return 0;
    }
  }

  void _parseAndUpdate() {
    if (_latestValue == null) return;

    final str = String.fromCharCodes(_latestValue!);
    final match = RegExp(r'pH:(\d+\.\d+),\s*Turb:(\d+\.\d+)V').firstMatch(str);

    if (match != null) {
      final double? ph = double.tryParse(match.group(1)!);
      final double? turbVoltage = double.tryParse(match.group(2)!);
      final double? turbNTU =
          turbVoltage != null ? mapVoltageToNTU(turbVoltage) : null;
      final now = DateTime.now();

      setState(() {
        _ph = ph;
        _turb = turbNTU;
        lastMeasured = now;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && ph != null && turbNTU != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('records')
            .add({
              'ph': ph,
              'turbidity': turbNTU,
              'time': now.toIso8601String(),
            });
      }
    }
  }

  Color getPhColor(double? ph) {
    if (ph == null) return Colors.black;
    if (ph >= 6.5 && ph <= 8.5) return Colors.green;
    if ((ph >= 6.0 && ph < 6.5) || (ph > 8.5 && ph <= 9.0))
      return Colors.orange;
    return Colors.red;
  }

  Color getTurbidityColor(double? turb) {
    if (turb == null) return Colors.black;
    if (turb <= 5) return Colors.green;
    if (turb <= 50) return Colors.cyan;
    if (turb <= 100) return Colors.orange;
    return Colors.red.shade800;
  }

  Widget buildQualityWidget() {
    final total = getWaterScore(_ph, _turb);
    String text = "Water Quality: ?";
    IconData icon = Icons.help_outline;
    Color color = Colors.black;

    if (total >= 9) {
      text = "Water Quality: Excellent";
      icon = Icons.sentiment_very_satisfied;
      color = Colors.green;
    } else if (total >= 6) {
      text = "Water Quality: Good";
      icon = Icons.sentiment_satisfied;
      color = Colors.blue;
    } else if (total >= 2) {
      text = "Water Quality: Poor";
      icon = Icons.clear;
      color = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Row(
        children: [
          const Icon(Icons.opacity, size: 40, color: Colors.lightBlue),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFB),
      appBar: AppBar(
        title: const Text('Water Quality Monitor'),
        backgroundColor: const Color.fromARGB(255, 60, 106, 156),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBluetoothCard(),
            const SizedBox(height: 24),
            _buildQualityHeader(),
            const SizedBox(height: 12),
            _buildLastMeasuredRow(),
            const SizedBox(height: 12),
            _buildDataCard(),
            const SizedBox(height: 24),
            _buildExplanationTile(),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothCard() {
    final isConnected = _connectedDeviceName != null;
    final cardColor =
        isConnected
            ? const Color(0xFFE0F7E9)
            : const Color(0xFFFFF4E5); // light green / light orange
    final iconColor = isConnected ? Colors.green : Colors.orange;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.bluetooth, color: Colors.blue),
        title:
            isConnected
                ? Text(
                  "Connected: $_connectedDeviceName",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "No device connected",
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 163, 48, 22),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Tap to connect",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color.fromARGB(255, 61, 61, 61),
                      ),
                    ),
                  ],
                ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _startBleScan,
      ),
    );
  }

  Widget _buildQualityHeader() {
    final total = getWaterScore(_ph, _turb);
    String text = "?";
    if (total >= 9)
      text = "Excellent";
    else if (total >= 6)
      text = "Good";
    else if (total >= 2)
      text = "Poor";
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 60, 106, 156), Color(0xFFADE6EF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.water_drop, size: 36, color: Colors.white),
          const SizedBox(height: 10),
          Text(
            'Water Quality: $text',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Based on pH and Turbidity',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLastMeasuredRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Last measured: ${lastMeasured.toString().substring(0, 16)}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton.icon(
          onPressed: _parseAndUpdate,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildDataCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Detailed data',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDataBox(
                  'pH Value',
                  _ph?.toStringAsFixed(2) ?? '---',
                  getPhColor(_ph),
                ),
                _buildDataBox(
                  'Turbidity',
                  _turb != null ? '${_turb!.toStringAsFixed(2)} NTU' : '---',
                  getTurbidityColor(_turb),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationTile() {
    return ExpansionTile(
      title: const Text(
        'Interpretation of Values',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent),
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turbidity (NTU):',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('0-5: Clear 👏🏻'),
              Text('5-50: Cloudy ☁️'),
              Text('50-100: Very Cloudy 🚫'),
              Text('>100: Extremely Polluted ⚠️'),
              SizedBox(height: 12),
              Text('pH Value:', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('6.5-8.5: Optimal ✅'),
              Text('6.0-6.5 or 8.5-9.0: Acceptable ⚠️'),
              Text('<6.0 or >9.0: Unhealthy ❌'),
            ],
          ),
        ),
      ],
    );
  }

  int getWaterScore(double? ph, double? turb) {
    int phScore = 0, turbScore = 0;
    if (ph != null) {
      if (ph >= 6.5 && ph <= 8.5)
        phScore = 5;
      else if ((ph >= 6.0 && ph < 6.5) || (ph > 8.5 && ph <= 9.0))
        phScore = 3;
      else
        phScore = 1;
    }
    if (turb != null) {
      if (turb <= 1.0)
        turbScore = 5;
      else if (turb <= 3.0)
        turbScore = 4;
      else if (turb <= 5.0)
        turbScore = 3;
      else if (turb <= 10.0)
        turbScore = 2;
      else
        turbScore = 1;
    }
    return phScore + turbScore;
  }
}
