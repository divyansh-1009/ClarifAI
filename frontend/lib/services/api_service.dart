import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assessment_model.dart';

class ApiService {
  // Use http://10.0.2.2:8000 for Android Emulator to reach localhost
  final String _baseUrl = 'http://10.0.2.2:8000/assessment/generate-from-topic/';

  Future<Assessment> fetchAssessment() async {
    // Add logic for authentication if required
    final response = await http.get(Uri.parse(_baseUrl));

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // Backend returns string, then parse that string into JSON
      final assessmentJson = json.decode(jsonResponse['assessment_data']);
      return Assessment.fromJson(assessmentJson);
    } else {
      throw Exception('Failed to load assessment. ${response.body}');
    }
  }
}
