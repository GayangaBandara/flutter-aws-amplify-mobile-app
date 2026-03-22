import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// VOICE AI AGENT - Main Entry Point
// ============================================================================
// This is a complete Voice AI Assistant application that:
// 1. Listens to user's voice input (Speech-to-Text)
// 2. Sends text to an AI API endpoint
// 3. Receives AI response and speaks it out loud (Text-to-Speech)
// ============================================================================

void main() {
  runApp(VoiceAIApp());
}

// ============================================================================
// Message Class - Represents a single chat message
// ============================================================================
class Message {
  final String text;
  final bool isUser; // true = user message, false = AI response

  Message({required this.text, required this.isUser});
}

// ============================================================================
// Main Application Widget
// ============================================================================
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

// ============================================================================
// Home Page - Contains all the Voice AI logic and UI
// ============================================================================
class VoiceAIHomePage extends StatefulWidget {
  @override
  _VoiceAIHomePageState createState() => _VoiceAIHomePageState();
}

class _VoiceAIHomePageState extends State<VoiceAIHomePage> {
  // --------------------------------------------------------------------------
  // Voice Recognition (Speech-to-Text)
  // --------------------------------------------------------------------------
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _recognizedText = '';

  // --------------------------------------------------------------------------
  // Text-to-Speech (TTS)
  // --------------------------------------------------------------------------
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  // --------------------------------------------------------------------------
  // State Management
  // --------------------------------------------------------------------------
  List<Message> _messages = []; // Chat messages list
  bool _isLoading = false; // Loading indicator for API calls

  // API Endpoint - Replace with your actual API URL
  // Format: https://your-api-id.execute-api.region.amazonaws.com/prod/chat
  final String _apiUrl =
      'https://your-api-id.execute-api.region.amazonaws.com/prod/chat';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  // --------------------------------------------------------------------------
  // Initialize Speech-to-Text
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Initialize Text-to-Speech
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Start Voice Recognition
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Stop Voice Recognition
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Process User Message - Add to list and send to API
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Send Message to AI API
  // --------------------------------------------------------------------------
  Future<void> _sendToAI(String text) async {
    try {
      // Make POST request to API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': text}),
      );

      // Check if request was successful
      if (response.statusCode == 200) {
        // Parse response
        final Map<String, dynamic> data = jsonDecode(response.body);
        String aiReply = data['reply'] ?? 'No response received';

        // Add AI response to chat
        setState(() {
          _messages.add(Message(text: aiReply, isUser: false));
          _isLoading = false;
        });

        // Speak the AI response
        await _speakResponse(aiReply);
      } else {
        // API error
        _showError('API request failed: ${response.statusCode}');
        _addFallbackMessage();
      }
    } catch (e) {
      // Network or parsing error
      print('Error sending to AI: $e');
      _showError('Something went wrong');
      _addFallbackMessage();
    }
  }

  // --------------------------------------------------------------------------
  // Add Fallback Error Message
  // --------------------------------------------------------------------------
  void _addFallbackMessage() {
    setState(() {
      _messages.add(Message(text: 'Something went wrong', isUser: false));
      _isLoading = false;
    });
  }

  // --------------------------------------------------------------------------
  // Speak AI Response (Text-to-Speech)
  // --------------------------------------------------------------------------
  Future<void> _speakResponse(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.speak(text);
  }

  // --------------------------------------------------------------------------
  // Stop Speaking
  // --------------------------------------------------------------------------
  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

  // --------------------------------------------------------------------------
  // Show Error Message
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Clean up resources
  // --------------------------------------------------------------------------
  @override
  void dispose() {
    _speech.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  // ===========================================================================
  // UI - Build the Interface
  // ===========================================================================
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

  // --------------------------------------------------------------------------
  // Empty State - Shown when no messages yet
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Messages List - Shows chat conversation
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Message Bubble - Individual message design
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Loading Indicator
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Status Bar - Shows current state (listening/speaking)
  // --------------------------------------------------------------------------
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

  // --------------------------------------------------------------------------
  // Microphone Button
  // --------------------------------------------------------------------------
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
