/**
 * AWS Environment Configuration
 * Replace the placeholder values with your actual AWS deployed values
 */

class AwsConfig {
  // API Gateway endpoint - UPDATE THIS AFTER DEPLOYING LAMBDA
  // The deployment script will output the actual URL
  static const String apiEndpoint =
      'https://zk3wybvw4l.execute-api.eu-north-1.amazonaws.com/default/voice-agent-api';

  // AWS Region
  static const String region = 'eu-north-1';

  // API Configuration
  static const int timeout = 30; // seconds

  // CORS settings (must match Lambda CORS configuration)
  static const Map<String, String> corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  };
}

/**
 * API Request/Response models
 */
class ChatRequest {
  final String message;

  ChatRequest({required this.message});

  Map<String, dynamic> toJson() => {'message': message};
}

class ChatResponse {
  final String reply;
  final String? timestamp;
  final String? error;

  ChatResponse({required this.reply, this.timestamp, this.error});

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      reply: json['reply'] ?? 'No response',
      timestamp: json['timestamp'],
      error: json['error'],
    );
  }
}
