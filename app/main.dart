import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const LeafDeviceApp());
}

class LeafDeviceApp extends StatelessWidget {
  const LeafDeviceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // If you require fine location for scan, set usesFineLocation: true and add permission
  final FlutterBlueClassic blue = FlutterBlueClassic();

  BluetoothConnection? _connection;
  String? _connectedName;
  StreamSubscription<List<int>>? _inputSub;
  final List<_ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _inputSub?.cancel();
    _connection?.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _attachInputListener(BluetoothConnection connection) {
    _inputSub?.cancel();
    _inputSub = connection.input?.listen(
      (data) {
        final text = utf8.decode(data);
        if (mounted) {
          setState(() {
            _messages.add(
              _ChatMessage(sender: MessageSender.device, text: text),
            );
          });
        }
      },
      onError: (e) {
        if (kDebugMode) print('Input error: $e');
      },
      onDone: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _navigateToConnect() async {
    final result = await Navigator.push<ConnectionInfo?>(
      context,
      MaterialPageRoute(builder: (_) => ConnectPage(blue: blue)),
    );

    if (result != null && result.connection.isConnected) {
      setState(() {
        _connection = result.connection;
        _connectedName = result.name;
      });
      _attachInputListener(result.connection);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _connection == null || !_connection!.isConnected)
      return;
    try {
      _connection!.writeString(text + '\n');
      setState(() {
        _messages.add(_ChatMessage(sender: MessageSender.me, text: text));
        _textController.clear();
      });
    } catch (e) {
      if (kDebugMode) print('Write error: $e');
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Failed to send.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connection?.isConnected == true;
    final deviceLabel = _connectedName?.isNotEmpty == true
        ? _connectedName
        : _connection?.address;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isConnected
              ? 'Connected: ${deviceLabel ?? 'Unknown'}'
              : 'Leaf Device',
        ),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.link_off),
              tooltip: 'Disconnect',
              onPressed: () {
                _connection?.dispose();
                setState(() {
                  _connection = null;
                  _connectedName = null;
                });
              },
            ),
        ],
      ),
      body: isConnected ? _buildChat() : _buildDisconnected(),
      floatingActionButton: isConnected
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToConnect,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Connect'),
            ),
    );
  }

  Widget _buildDisconnected() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No Bluetooth device connected',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToConnect,
            icon: const Icon(Icons.bluetooth_searching),
            label: const Text('Scan and connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final align = m.sender == MessageSender.me
                  ? Alignment.centerRight
                  : Alignment.centerLeft;
              final color = m.sender == MessageSender.me
                  ? Colors.blue[200]
                  : Colors.grey[300];
              return Align(
                alignment: align,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(m.text),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Type a message…',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum MessageSender { me, device }

class _ChatMessage {
  final MessageSender sender;
  final String text;

  _ChatMessage({required this.sender, required this.text});
}

class ConnectionInfo {
  final BluetoothConnection connection;
  final String? name;

  ConnectionInfo({required this.connection, this.name});
}

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.blue});

  final FlutterBlueClassic blue;

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  final Set<BluetoothDevice> _scanResults = {};
  StreamSubscription<BluetoothDevice>? _scanSub;
  StreamSubscription<bool>? _scanningStateSub;
  bool _isScanning = false;
  int? _connectingIndex;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _ensurePermissions() async {
    if (!Platform.isAndroid) return;
    try {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
    } catch (e) {
      if (kDebugMode) print('Permission request error: $e');
    }
  }

  Future<void> _init() async {
    try {
      await _ensurePermissions();
      final state = await widget.blue.adapterStateNow;
      _adapterSub = widget.blue.adapterState.listen((s) {
        if (mounted) setState(() => _adapterState = s);
      });
      _scanSub = widget.blue.scanResults.listen((d) {
        if (mounted) setState(() => _scanResults.add(d));
      });
      _scanningStateSub = widget.blue.isScanning.listen((isScanning) {
        if (mounted) setState(() => _isScanning = isScanning);
      });
      if (mounted) setState(() => _adapterState = state);
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _scanningStateSub?.cancel();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      widget.blue.stopScan();
    } else {
      _scanResults.clear();
      widget.blue.startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _scanResults.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Scan and connect')),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_bluetooth),
            title: const Text('Bluetooth adapter'),
            subtitle: const Text('Tap to enable'),
            trailing: Text(_adapterState.name),
            onTap: () => widget.blue.turnOn(),
          ),
          const Divider(),
          if (results.isEmpty)
            const Expanded(child: Center(child: Text('No devices found yet')))
          else
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final d = results[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text('${d.name ?? 'Unknown'} (${d.address})'),
                    subtitle: Text(
                      'Bond: ${d.bondState.name}, Type: ${d.type.name}',
                    ),
                    trailing: _connectingIndex == index
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('${d.rssi} dBm'),
                    onTap: () async {
                      setState(() => _connectingIndex = index);
                      BluetoothConnection? conn;
                      try {
                        conn = await widget.blue.connect(d.address);
                        if (!mounted) return;
                        setState(() => _connectingIndex = null);
                        if (conn != null && conn.isConnected) {
                          Navigator.of(
                            context,
                          ).pop(ConnectionInfo(connection: conn, name: d.name));
                        }
                      } catch (e) {
                        if (kDebugMode) print(e);
                        setState(() => _connectingIndex = null);
                        conn?.dispose();
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(content: Text('Error connecting')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
        label: Text(_isScanning ? 'Scanning…' : 'Start scan'),
      ),
    );
  }
}
