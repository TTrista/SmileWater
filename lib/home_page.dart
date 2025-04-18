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
  final _characteristicUuid = Uuid.parse("abcd1234-1234-1234-1234-abcdef123456");

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
        const SnackBar(content: Text('需要位置权限来使用蓝牙')),
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
    _connectSub = flutterReactiveBle.connectToDevice(id: device.id).listen(
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
            SnackBar(content: Text("已连接：${device.name}")),
          );
        }
      },
      onError: (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("连接失败：$e")),
        );
      },
    );
  }

  void _startListening() {
    if (_rxChar == null) return;

    _dataSub = flutterReactiveBle.subscribeToCharacteristic(_rxChar!).listen(
      (value) {
        _latestValue = value;
        if (!_firstReadDone) {
          _parseAndUpdate(); // 首次读取
          _firstReadDone = true;
        }
      },
      onError: (e) {
        debugPrint("监听数据失败: $e");
      },
    );
  }

  void _parseAndUpdate() {
  if (_latestValue == null) return;

  final str = String.fromCharCodes(_latestValue!);
  final match = RegExp(r'pH:(\d+\.\d+),Turb:(\d+\.\d+)V').firstMatch(str);

  if (match != null) {
    final double? ph = double.tryParse(match.group(1)!);
    final double? turb = double.tryParse(match.group(2)!);
    final now = DateTime.now();

    setState(() {
      _ph = ph;
      _turb = turb;
      lastMeasured = now;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && ph != null && turb != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records')
          .add({
        'ph': ph,
        'turbidity': turb,
        'time': now.toIso8601String(),
      });
    }
  }
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color.fromARGB(255, 87, 142, 159),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 蓝牙卡片
            Card(
              color: const Color.fromARGB(255, 235, 248, 255),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: _startBleScan,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_searching, size: 30, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectedDeviceName != null
                              ? '已连接设备：$_connectedDeviceName'
                              : '请连接设备',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            buildQualityWidget(),
            const SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.only(left: infoBlockPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last measured: ${lastMeasured.toString().substring(0, 16)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("点此获取最新读数", style: TextStyle(fontSize: 16)),
                      IconButton(
                        onPressed: _parseAndUpdate,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text('Detailed Data', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text('pH Value', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              _ph?.toStringAsFixed(2) ?? '---',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text('Turbidity', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              _turb != null ? '${_turb!.toStringAsFixed(2)} NTU' : '---',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
