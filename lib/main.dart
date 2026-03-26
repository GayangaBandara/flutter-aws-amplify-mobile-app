import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'aws_config.dart';

void main() {
  runApp(VoiceAIApp());
}

class Message {
  final String text;
  final bool isUser; // true = user message, false = AI response

  Message({required this.text, required this.isUser});
}

class VoiceAIApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Voice AI Assistant',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: VoiceAIHomePage(),
    );
  }
}

class VoiceAIHomePage extends StatefulWidget {
  @override
  _VoiceAIHomePageState createState() => _VoiceAIHomePageState();
}

class _VoiceAIHomePageState extends State<VoiceAIHomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';

  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  List<Message> _messages = []; // Chat messages list
  bool _isLoading = false; // Loading indicator for API calls

  // API Endpoint - Use config
  final String _apiUrl = AwsConfig.apiEndpoint;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeSpeech() {
    _speech = stt.SpeechToText();
    _speech.initialize(
      onError: (error) {
        print('Speech recognition error: $error');
        _showError('Speech recognition failed');
        setState(() {
          _isListening = false;
        });
      },
      onStatus: (status) {
        print('Speech status: $status');
        // Stop listening when speech is done
        if (status == 'done' || status == 'notListening') {
          setState(() {
            _isListening = false;
          });
        }
      },
    );
  }

  void _initializeTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
    _flutterTts.setErrorHandler((error) {
      print('TTS error: $error');
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _startListening() async {
    // Check if speech recognition is available
    bool available = await _speech.initialize();

    if (!available) {
      _showError('Speech recognition not available');
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    // Start listening for speech
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        // When user stops speaking, process the message
        if (result.finalResult) {
          _processUserMessage(_recognizedText);
        }
      },
      listenFor: Duration(seconds: 30), // Listen for up to 30 seconds
      pauseFor: Duration(seconds: 3), // Pause after 3 seconds of silence
      partialResults: true, // Show partial results while speaking
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
    });

    // If we have recognized text, process it
    if (_recognizedText.isNotEmpty) {
      _processUserMessage(_recognizedText);
    }
  }

  void _processUserMessage(String text) {
    if (text.trim().isEmpty) return;

    // Add user message to chat
    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
    });

    // Send to AI API
    _sendToAI(text);
  }

  Future<void> _sendToAI(String text) async {
    try {
      print('🔵 [API Request] Sending to: $_apiUrl');
      print('📝 [API Request] Body: {"message": "$text"}');

      // Make POST request to API with explicit headers for web CORS
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'message': text}),
          )
          .timeout(Duration(seconds: AwsConfig.timeout));

      print('✅ [API Response] Status: ${response.statusCode}');
      print('📦 [API Response] Body: ${response.body}');
      print('🔗 [API Response] Headers: ${response.headers}');

      // Check for successful response
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          String aiReply =
              data['reply'] ?? data['message'] ?? 'No response received';

          print('💬 [AI Response] $aiReply');

          // Add AI response to chat
          setState(() {
            _messages.add(Message(text: aiReply, isUser: false));
            _isLoading = false;
          });

          // Speak the AI response
          await _speakResponse(aiReply);
        } catch (parseError) {
          print('❌ [Parse Error] JSON parse failed: $parseError');
          print('📄 [Parse Error] Body: ${response.body}');
          _showError('API returned invalid response');
          _addFallbackMessage('Could not parse API response');
        }
      } else {
        print('⚠️ [HTTP Error] Status: ${response.statusCode}');
        _showError('API Error: ${response.statusCode}');
        _addFallbackMessage('API returned status ${response.statusCode}');
      }
    } on TimeoutException {
      print('⏱️ [Timeout] Request exceeded ${AwsConfig.timeout}s');
      _showError('Request timeout - API not responding');
      _addFallbackMessage('Request timeout after ${AwsConfig.timeout}s');
    } on http.ClientException catch (e) {
      print('❌ [Network Error] ${e.message}');
      print('💡 [Hint] This is a CORS error. Check API Gateway CORS settings');
      _showError('Network error: ${e.message}');
      _addFallbackMessage(
        'Network error - Verify API Gateway CORS is deployed',
      );
    } catch (e) {
      print('❌ [Unexpected Error] $e');
      print('🔍 [Stack Trace] ${e.runtimeType}');
      _showError('Unexpected error: $e');
      _addFallbackMessage('Unexpected error occurred');
    }
  }

  void _addFallbackMessage([String? customMessage]) {
    setState(() {
      _messages.add(
        Message(
          text: customMessage ?? 'Something went wrong, please try again.',
          isUser: false,
        ),
      );
      _isLoading = false;
    });
  }

  Future<void> _speakResponse(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice AI Assistant'),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // Chat messages list
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessagesList(),
          ),

          // Loading indicator
          if (_isLoading) _buildLoadingIndicator(),

          // Status text (listening/speaking)
          _buildStatusBar(),
        ],
      ),

      // Floating Microphone Button
      floatingActionButton: _buildMicButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 80, color: Colors.blue.shade200),
          SizedBox(height: 16),
          Text(
            'Tap the microphone to start',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            'I\'m ready to listen!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(Message message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar icon
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.green.shade400,
              radius: 18,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 20),
            ),
            SizedBox(width: 8),
          ],

          // Message container
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Colors.blue.shade600
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomRight: message.isUser ? Radius.circular(4) : null,
                  bottomLeft: !message.isUser ? Radius.circular(4) : null,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // User avatar
          if (message.isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade400,
              radius: 18,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Thinking...',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    String statusText = '';
    Color statusColor = Colors.transparent;
    IconData? statusIcon;

    if (_isListening) {
      statusText = 'Listening... Speak now';
      statusColor = Colors.red.shade100;
      statusIcon = Icons.mic;
    } else if (_isSpeaking) {
      statusText = 'Speaking...';
      statusColor = Colors.green.shade100;
      statusIcon = Icons.volume_up;
    }

    if (statusText.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8),
      color: statusColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (statusIcon != null) ...[
            Icon(statusIcon, size: 16, color: Colors.grey.shade700),
            SizedBox(width: 8),
          ],
          Text(
            statusText,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return FloatingActionButton.extended(
      onPressed: _isListening ? _stopListening : _startListening,
      backgroundColor: _isListening ? Colors.red : Colors.blue.shade600,
      icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 28),
      label: Text(
        _isListening ? 'Stop' : 'Speak',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
