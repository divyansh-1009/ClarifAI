import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/topic_model.dart';
import '../models/assessment_model.dart';
import '../models/query_model.dart';

// ─────────────────────────────────────────────
//  Custom exceptions
// ─────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([String message = 'Session expired. Please log in again.'])
      : super(message, statusCode: 401);
}

class NotFoundException extends ApiException {
  const NotFoundException([String message = 'Resource not found.'])
      : super(message, statusCode: 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic> errors;

  const ValidationException(String message, this.errors)
      : super(message, statusCode: 400);
}

// ─────────────────────────────────────────────
//  Auth response
// ─────────────────────────────────────────────

class AuthTokens {
  final String access;
  final String refresh;

  const AuthTokens({required this.access, required this.refresh});
}

class RegisterResponse {
  final UserModel user;
  final AuthTokens tokens;
  final String message;

  const RegisterResponse({
    required this.user,
    required this.tokens,
    required this.message,
  });
}

// ─────────────────────────────────────────────
//  Storage keys
// ─────────────────────────────────────────────

class _StorageKeys {
  static const accessToken = 'access_token';
  static const refreshToken = 'refresh_token';
  static const cachedUser = 'cached_user';
}

// ─────────────────────────────────────────────
//  API Service
// ─────────────────────────────────────────────

class ApiService {
  // Use http://10.0.2.2:8000 for Android emulator,
  // http://localhost:8000 for iOS simulator / web.
  // static const String _baseUrl = 'http://192.168.137.1/api';
  static const String _baseUrl = 'http://10.0.2.2:8000/api';

  static const Duration _timeout = Duration(seconds: 30);

  // ── Token helpers ───────────────────────────

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_StorageKeys.accessToken);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_StorageKeys.refreshToken);
  }

  Future<void> _saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_StorageKeys.accessToken, access);
    await prefs.setString(_StorageKeys.refreshToken, refresh);
  }

  Future<void> _saveAccessToken(String access) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_StorageKeys.accessToken, access);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_StorageKeys.accessToken);
    await prefs.remove(_StorageKeys.refreshToken);
    await prefs.remove(_StorageKeys.cachedUser);
  }

  // ── Auth headers ────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Token refresh ───────────────────────────

  /// Silently refreshes the access token. Returns true on success.
  Future<bool> refreshAccessToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/accounts/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccess = json['access'] as String;
        await _saveAccessToken(newAccess);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Generic request with auto-refresh ───────

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestBuilder,
  ) async {
    var headers = await _authHeaders();
    var response = await requestBuilder(headers).timeout(_timeout);

    // On 401 try refreshing once
    if (response.statusCode == 401) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        headers = await _authHeaders();
        response = await requestBuilder(headers).timeout(_timeout);
      }
      if (response.statusCode == 401) {
        throw const UnauthorizedException();
      }
    }

    return response;
  }

  // ── Error parsing helper ─────────────────────

  ApiException _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        // DRF validation errors come back as {field: [msgs]} or {detail: "msg"}
        if (body.containsKey('detail')) {
          return ApiException(
            body['detail'].toString(),
            statusCode: response.statusCode,
          );
        }
        // Flatten field errors
        final messages = <String>[];
        body.forEach((key, value) {
          if (value is List) {
            messages.add(value.join(' '));
          } else {
            messages.add(value.toString());
          }
        });
        return ValidationException(
          messages.join('\n'),
          body,
        );
      }
    } catch (_) {}
    return ApiException(
      'An unexpected error occurred (${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  // ════════════════════════════════════════════
  //  AUTHENTICATION
  // ════════════════════════════════════════════

  /// Step 1 of registration: send OTP to [email].
  Future<void> sendOtp(String email) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/accounts/register/send-otp/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw _parseError(response);
    }
  }

  /// Step 2 of registration: verify OTP and create account.
  Future<RegisterResponse> verifyOtpAndRegister({
    required String email,
    required String username,
    required String password,
    required String password2,
    required String otp,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/accounts/register/verify-otp/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'username': username,
            'password': password,
            'password2': password2,
            'otp': otp,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tokens = AuthTokens(
        access: json['access'] as String,
        refresh: json['refresh'] as String,
      );
      await _saveTokens(tokens.access, tokens.refresh);
      return RegisterResponse(
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
        tokens: tokens,
        message: (json['message'] as String?) ?? 'Registration successful.',
      );
    }

    throw _parseError(response);
  }

  /// Login with [username] and [password]. Stores tokens locally.
  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/accounts/login/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      await _saveTokens(
        json['access'] as String,
        json['refresh'] as String,
      );
      // Fetch and return the user profile
      return await getCurrentUser();
    }

    if (response.statusCode == 401) {
      throw const ApiException('Invalid username or password.', statusCode: 401);
    }

    throw _parseError(response);
  }

  /// Returns the currently authenticated user's profile.
  Future<UserModel> getCurrentUser() async {
    final response = await _authenticatedRequest(
      (headers) => http.get(
        Uri.parse('$_baseUrl/accounts/me/'),
        headers: headers,
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      // Cache locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_StorageKeys.cachedUser, response.body);
      return UserModel.fromJson(json);
    }

    throw _parseError(response);
  }

  /// Returns the cached user from local storage (no network call).
  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_StorageKeys.cachedUser);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Blacklists the refresh token and clears local storage.
  Future<void> logout() async {
    final refresh = await getRefreshToken();
    if (refresh != null) {
      try {
        final headers = await _authHeaders();
        await http
            .post(
              Uri.parse('$_baseUrl/accounts/logout/'),
              headers: headers,
              body: jsonEncode({'refresh': refresh}),
            )
            .timeout(_timeout);
      } catch (_) {
        // Proceed even if network call fails
      }
    }
    await clearTokens();
  }

  // ════════════════════════════════════════════
  //  TOPICS
  // ════════════════════════════════════════════

  /// Creates a new topic. Optionally attaches a [pdfFile] (must be a PDF).
  Future<TopicModel> createTopic({
    required String className,
    required String topic,
    File? pdfFile,
  }) async {
    final token = await getAccessToken();
    if (token == null) throw const UnauthorizedException();

    final uri = Uri.parse('$_baseUrl/topic/create/');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['class_name'] = className
      ..fields['topic'] = topic;

    if (pdfFile != null) {
      final stream = http.ByteStream(pdfFile.openRead());
      final length = await pdfFile.length();
      final fileName = pdfFile.path.split(Platform.pathSeparator).last;
      request.files.add(http.MultipartFile(
        'notes',
        stream,
        length,
        filename: fileName,
      ));
    }

    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      return TopicModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    if (response.statusCode == 401) throw const UnauthorizedException();
    throw _parseError(response);
  }

  // ════════════════════════════════════════════
  //  KNOWLEDGE NOTES
  // ════════════════════════════════════════════

  /// Adds a plain-text note to [topicId]'s knowledge base.
  Future<void> createKnowledgeNote({
    required String topicId,
    required String content,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/knowledge/create/'),
        headers: headers,
        body: jsonEncode({'topic': topicId, 'content': content}),
      ),
    );

    if (response.statusCode == 201) return;
    throw _parseError(response);
  }

  // ════════════════════════════════════════════
  //  QUERY / Q&A
  // ════════════════════════════════════════════

  /// Sends a [question] scoped to [topicId] and returns a [ChatMessage].
  Future<ChatMessage> askQuestion({
    required String question,
    required String topicId,
    required String messageId,
  }) async {
    final response = await _authenticatedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/query/ask/'),
        headers: headers,
        body: jsonEncode({'question': question, 'topic': topicId}),
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatMessage.fromQueryResponse(id: messageId, json: json);
    }

    if (response.statusCode == 403) {
      throw const ApiException('You do not have access to this topic.', statusCode: 403);
    }

    throw _parseError(response);
  }

  // ════════════════════════════════════════════
  //  ASSESSMENT
  // ════════════════════════════════════════════

  /// Generates an assessment from the provided subject/topic inputs.
  Future<Assessment> generateAssessment({
    required String subject,
    required String topic,
    String difficulty = 'medium',
  }) async {
    final response = await _authenticatedRequest(
      (headers) => http.post(
        Uri.parse('$_baseUrl/assessment/generate-from-topic/'),
        headers: headers,
        body: jsonEncode({
          'subject': subject,
          'topic': topic,
          'difficulty': difficulty,
        }),
      ),
    );

    if (response.statusCode == 200) {
      final outer = jsonDecode(response.body) as Map<String, dynamic>;
      if (outer['success'] != true) {
        throw ApiException(
          (outer['error'] as String?) ?? 'Assessment generation failed.',
        );
      }
      // Backend returns assessment_data as a JSON *string* — parse it.
      final rawData = outer['assessment_data'];
      final Map<String, dynamic> assessmentJson;
      if (rawData is String) {
        assessmentJson = jsonDecode(rawData) as Map<String, dynamic>;
      } else if (rawData is Map<String, dynamic>) {
        assessmentJson = rawData;
      } else {
        throw const ApiException('Unexpected assessment data format.');
      }
      return Assessment.fromJson(assessmentJson);
    }

    throw _parseError(response);
  }

  // ════════════════════════════════════════════
  //  UTILITY
  // ════════════════════════════════════════════

  /// Quick health-check: returns true if the backend is reachable.
  Future<bool> isBackendReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/accounts/me/'))
          .timeout(const Duration(seconds: 5));
      // Any response (even 401) means the server is up.
      return response.statusCode != 0;
    } catch (_) {
      return false;
    }
  }
}
