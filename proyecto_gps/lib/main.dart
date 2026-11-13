import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

// Cambia esta URL por la IP de tu servidor FastAPI
const String baseUrl = "https://9wc8k4l0-8000.usw3.devtunnels.ms";

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pase de Lista GPS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}

// --- PANTALLA DE LOGIN Y REGISTRO ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _authenticate(String endpoint) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$endpoint/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "username": _userController.text.trim(),
          "password": _passController.text.trim(),
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceScreen(userId: data['user_id']),
          ),
        );
      } else {
        _showMessage(data['detail'] ?? 'Error de autenticación');
      }
    } catch (e) {
      _showMessage('Error de conexión con el servidor');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso al Sistema')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _userController,
              decoration: const InputDecoration(labelText: 'Usuario'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _authenticate('login'),
                    child: const Text('Iniciar Sesión'),
                  ),
                  OutlinedButton(
                    onPressed: () => _authenticate('register'),
                    child: const Text('Registrarse'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- PANTALLA PRINCIPAL DE ASISTENCIA ---
class AttendanceScreen extends StatefulWidget {
  final int userId;
  const AttendanceScreen({super.key, required this.userId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _address = "";
  bool _isLoading = false;

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están desactivados.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permisos de ubicación denegados.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permisos denegados permanentemente.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _registerAttendance() async {
    setState(() => _isLoading = true);
    try {
      Position position = await _determinePosition();

      final response = await http.post(
        Uri.parse('$baseUrl/attendance/'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "latitude": position.latitude,
          "longitude": position.longitude,
        }),
      );

      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200) {
        setState(() {
          _address = data['address'];
        });
      } else {
        _showError(data['detail'] ?? 'No se pudo registrar la asistencia');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FB),
      appBar: AppBar(
        title: const Text('Registro de Asistencia'),
        backgroundColor: const Color(0xFF28589C),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerAttendance,
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'Obteniendo ubicación...'
                      : 'Registrar asistencia',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF23478A),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AttendanceHistoryScreen(userId: widget.userId),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text('Historial de asistencias'),
              ),
              const SizedBox(height: 24),
              if (_address.isNotEmpty)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "📍 $_address",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttendanceHistoryScreen extends StatefulWidget {
  final int userId;

  const AttendanceHistoryScreen({super.key, required this.userId});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<_AttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/attendance/').replace(
        queryParameters: {'user_id': widget.userId.toString()},
      );
      final response = await http.get(uri);
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (response.statusCode != 200) {
        final detail = data is Map<String, dynamic> ? data['detail'] : null;
        throw Exception(
          detail is String
              ? detail
              : 'Error del servidor (${response.statusCode})',
        );
      }

      final List<dynamic> items;
      if (data is List<dynamic>) {
        items = data;
      } else if (data is Map<String, dynamic> &&
          data['attendances'] is List<dynamic>) {
        items = data['attendances'] as List<dynamic>;
      } else {
        throw const FormatException(
          'La respuesta del historial debe ser una lista de asistencias.',
        );
      }

      final records = items.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
              'Una asistencia tiene un formato inválido.');
        }
        return _AttendanceRecord.fromJson(item);
      }).toList();

      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1FB),
      appBar: AppBar(
        title: const Text('Historial de asistencias'),
        backgroundColor: const Color(0xFF28589C),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 300,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_records.isEmpty)
              const SizedBox(
                height: 300,
                child:
                    Center(child: Text('Aún no hay asistencias registradas.')),
              )
            else
              ..._records.map(
                (record) => Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Color(0xFF28589C),
                    ),
                    title: Text(record.address),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (record.date != null)
                          Text(_formatDateTime(record.date!)),
                        if (record.latitude != null && record.longitude != null)
                          Text(
                            '${record.latitude!.toStringAsFixed(5)}, '
                            '${record.longitude!.toStringAsFixed(5)}',
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRecord {
  final String address;
  final DateTime? date;
  final double? latitude;
  final double? longitude;

  const _AttendanceRecord({
    required this.address,
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  factory _AttendanceRecord.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    if (address is! String || address.trim().isEmpty) {
      throw const FormatException(
        'Cada asistencia debe incluir una dirección válida.',
      );
    }

    final rawDate = json['created_at'] ?? json['timestamp'] ?? json['date'];
    DateTime? date;
    if (rawDate != null) {
      if (rawDate is! String || DateTime.tryParse(rawDate) == null) {
        throw const FormatException('La fecha de una asistencia no es válida.');
      }
      date = DateTime.parse(rawDate);
    }

    double? coordinate(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num) {
        throw FormatException('La coordenada "$key" no es válida.');
      }
      return value.toDouble();
    }

    return _AttendanceRecord(
      address: address,
      date: date,
      latitude: coordinate('latitude'),
      longitude: coordinate('longitude'),
    );
  }
}

String _formatDateTime(DateTime date) {
  final localDate = date.toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${localDate.year}-${twoDigits(localDate.month)}-'
      '${twoDigits(localDate.day)} ${twoDigits(localDate.hour)}:'
      '${twoDigits(localDate.minute)}';
}
