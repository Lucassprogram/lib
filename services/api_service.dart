import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://poosd24.live/api';

  static Future<Map<String, dynamic>> login(
    String login,
    String password,
  ) async {
    final Map<String, dynamic> result = await _post('/login', <String, dynamic>{
      'login': login.trim(),
      'password': password.trim(),
    });

    final String? token = result['token']?.toString();
    if (token != null && token.isNotEmpty) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      final Object? id = result['id'];
      if (id != null) {
        await prefs.setString('userId', id.toString());
      }

      final Object? firstName = result['firstName'];
      if (firstName != null) {
        await prefs.setString('firstName', firstName.toString());
      }

      final Object? lastName = result['lastName'];
      if (lastName != null) {
        await prefs.setString('lastName', lastName.toString());
      }
    }

    return result;
  }

  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final List<String> nameParts = name.trim().split(RegExp(r'\s+'));
    final String firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final String lastName = nameParts.length > 1
        ? nameParts.sublist(1).join(' ')
        : '';

    return _post('/register', <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'login': email.trim(),
      'password': password.trim(),
    });
  }

  static Future<Map<String, dynamic>> requestPasswordReset(String login) async {
    return _post('/request-reset', <String, dynamic>{'login': login.trim()});
  }

  static Future<List<dynamic>> getSkills() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      return <dynamic>[];
    }

    try {
      final http.Response response = await http.get(
        Uri.parse('$baseUrl/myskills'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _logResponse('GET /myskills', response);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['mySkills'] is List) {
          return List<dynamic>.from(decoded['mySkills'] as List<dynamic>);
        }
      }

      return <dynamic>[];
    } catch (e) {
      print('Network error in getSkills: $e');
      return <dynamic>[];
    }
  }

  static Future<Map<String, dynamic>> addSkill(String skill) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      return <String, dynamic>{'error': 'Missing authentication token'};
    }

    try {
      final http.Response response = await http.post(
        Uri.parse('$baseUrl/addskill'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, String>{'card': skill}),
      );

      _logResponse('POST /addskill', response);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic>? decoded = _decodeMap(response.body);
        if (decoded != null) {
          return decoded;
        }
      }

      return <String, dynamic>{'error': 'Unexpected response from server'};
    } catch (e) {
      print('Network error in addSkill: $e');
      return <String, dynamic>{'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteSkill(String skillName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      return <String, dynamic>{'error': 'Missing authentication token'};
    }

    try {
      final http.Response response = await http.delete(
        Uri.parse('$baseUrl/deleteskill/$skillName'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _logResponse('DELETE /deleteskill', response);

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final Map<String, dynamic>? decoded = _decodeMap(response.body);
        if (decoded != null) {
          return decoded;
        }
      }

      return <String, dynamic>{'error': 'Unexpected response from server'};
    } catch (e) {
      print('Network error in deleteSkill: $e');
      return <String, dynamic>{'error': 'Network error: $e'};
    }
  }

  static Future<List<dynamic>> fetchMatchSkills() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    if (token.isEmpty) {
      return <dynamic>[];
    }

    try {
      final http.Response response = await http.get(
        Uri.parse('$baseUrl/matchskills'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      _logResponse('GET /matchskills', response);
      final Map<String, dynamic>? decoded = _decodeMap(response.body);

      if (response.statusCode == 200 && decoded != null) {
        final dynamic matches = decoded['matches'];
        if (matches is List<dynamic>) {
          return List<dynamic>.from(matches);
        }
      }

      return <dynamic>[];
    } catch (error) {
      print('Network error in fetchMatchSkills: $error');
      return <dynamic>[];
    }
  }

  static Future<List<dynamic>> fetchBrowseSkills() async {
    try {
      final http.Response response = await http.get(
        Uri.parse('$baseUrl/browseskills'),
        headers: const <String, String>{'Content-Type': 'application/json'},
      );

      _logResponse('GET /browseskills', response);
      final Map<String, dynamic>? decoded = _decodeMap(response.body);

      if (response.statusCode == 200 && decoded != null) {
        final dynamic skills = decoded['skills'];
        if (skills is List<dynamic>) {
          return List<dynamic>.from(skills);
        }
      }

      return <dynamic>[];
    } catch (error) {
      print('Network error in fetchBrowseSkills: $error');
      return <dynamic>[];
    }
  }

  static Future<List<dynamic>> fetchUsers() async {
    try {
      final http.Response response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: const <String, String>{'Content-Type': 'application/json'},
      );

      _logResponse('GET /users', response);
      final Map<String, dynamic>? decoded = _decodeMap(response.body);

      if (response.statusCode == 200 && decoded != null) {
        final dynamic users = decoded['users'];
        if (users is List<dynamic>) {
          return List<dynamic>.from(users);
        }
      }

      return <dynamic>[];
    } catch (error) {
      print('Network error in fetchUsers: $error');
      return <dynamic>[];
    }
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final http.Response response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      _logResponse('POST $endpoint', response);

      final Map<String, dynamic>? decoded = _decodeMap(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded ?? <String, dynamic>{};
      }

      final String message = decoded != null && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Unexpected response from server (${response.statusCode})';
      return <String, dynamic>{'error': message};
    } catch (e) {
      return <String, dynamic>{'error': 'Network error: $e'};
    }
  }

  static Map<String, dynamic>? _decodeMap(String body) {
    if (body.isEmpty) {
      return null;
    }
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      print('JSON decode error: $e');
    }
    return null;
  }

  static void _logResponse(String label, http.Response response) {
    print('[$label] Status: ${response.statusCode}');
    if (response.body.isNotEmpty) {
      print('[$label] Body: ${response.body}');
    }
  }
}
