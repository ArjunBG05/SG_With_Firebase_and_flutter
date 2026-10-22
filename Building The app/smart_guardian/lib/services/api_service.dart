
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Latest values from the ESP32 bridge.
/// Prototype data, not medically validated.
class SensorReadings {
  final int? ir;
  final double? bpm;
  final double? spo2;
  final double? temperatureC;
  final double? ageSeconds;

  const SensorReadings({
    this.ir,
    this.bpm,
    this.spo2,
    this.temperatureC,
    this.ageSeconds,
  });

  factory SensorReadings.fromJson(Map<String, dynamic> json) {
    return SensorReadings(
      ir: (json['ir'] as num?)?.toInt(),
      bpm: (json['bpm'] as num?)?.toDouble(),
      spo2: (json['spo2'] as num?)?.toDouble(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      ageSeconds: (json['age_seconds'] as num?)?.toDouble(),
    );
  }
}

class ApiService {
  // Android Emulator → computer running the Python bridge
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> testBackend() async {
    final response = await http.get(
      Uri.parse('$baseUrl/test'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'];
    } else {
      throw Exception(
        'Backend request failed: ${response.statusCode}',
      );
    }
  }

  static Future<SensorReadings> fetchReadings() async {
    final response = await http
        .get(Uri.parse('$baseUrl/readings'))
        .timeout(const Duration(seconds: 3));

    if (response.statusCode == 200) {
      return SensorReadings.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } else {
      throw Exception(
        'Readings request failed: ${response.statusCode}',
      );
    }
  }
}
