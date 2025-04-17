import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
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
  DiscoveredDevice? _targetDevice;
  String? _connectedDeviceName;

  double? _ph;
  double? _turb;
  DateTime lastMeasured = DateTime.now();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 如果已经连接了设备，但监听被清理了（页面跳转），则恢复监听
    if (_rxChar != null && _dataSub == null) {
      debugPrint("⚡ 页面切回 Home，重新恢复监听...");
      _startListening();
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要位置权限来使用蓝牙')));
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
    _targetDevice = device;

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
              setState(() {}); // 更新设备名显示
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("已连接：${device.name}")));
            }
          },
          onError: (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("连接失败：$e")));
          },
        );
  }

  void _startListening() {
    if (_rxChar == null || _dataSub != null) return;

    _dataSub = flutterReactiveBle
        .subscribeToCharacteristic(_rxChar!)
        .listen(
          (value) {
            final str = String.fromCharCodes(value);
            final match = RegExp(
              r'pH:(\d+\.\d+),Turb:(\d+\.\d+)V',
            ).firstMatch(str);
            if (match != null) {
              setState(() {
                _ph = double.tryParse(match.group(1)!);
                _turb = double.tryParse(match.group(2)!);
                lastMeasured = DateTime.now();
              });
            }
          },
          onError: (e) {
            debugPrint("监听数据失败：$e");
          },
        );
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectSub?.cancel();
    _dataSub?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushNamed(context, '/history');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color.fromARGB(255, 87, 142, 159),
        centerTitle: false,
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
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _startBleScan,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bluetooth_searching,
                        size: 30,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _connectedDeviceName != null
                              ? '已连接设备：$_connectedDeviceName'
                              : '请连接设备',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 水质状态
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.opacity, size: 60, color: Colors.lightBlue),
                SizedBox(width: 16),
                Text(
                  'Water Quality: Good',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 更新时间 + 刷新
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Last measured: ${lastMeasured.toString().substring(0, 16)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    setState(() {
                      lastMeasured = DateTime.now(); // 手动刷新
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 数据卡片
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Detailed Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'pH Value',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _ph?.toStringAsFixed(2) ?? '---',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Turbidity',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _turb != null
                                  ? '${_turb!.toStringAsFixed(2)} NTU'
                                  : '---',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.history_edu),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_emotions),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
