/**
 * Voice AI Lambda Function
 * Handles voice agent requests from Flutter app
 * 
 * This Lambda function processes user messages and returns AI responses
 * Can be extended to integrate with AWS AI services (Lex, Polly, etc.)
 */

exports.handler = async (event) => {
  console.log('Event received:', JSON.stringify(event, null, 2));
  
  // Handle CORS preflight requests
  if (event.httpMethod === 'OPTIONS') {
      return {
          statusCode: 200,
          headers: getCorsHeaders(),
          body: JSON.stringify({ message: 'OK' }),
          isBase64Encoded: false
      };
  }
  
  try {
      // Parse the request body
      let body = event.body;
      if (typeof body === 'string') {
          body = JSON.parse(body || '{}');
      } else if (!body) {
          body = {};
      }
      
      const userMessage = body.message || body.text || '';
      
      if (!userMessage.trim()) {
          console.log('No message provided');
          return createResponse(400, { 
              error: 'No message provided',
              reply: 'Please provide a message to process.'
          });
      }
      
      console.log('Processing message:', userMessage);
      
      // Process the message and generate response
      const aiResponse = await processMessage(userMessage);
      
      console.log('Generated response:', aiResponse);
      
      return createResponse(200, {
          reply: aiResponse,
          timestamp: new Date().toISOString(),
          success: true
      });
      
  } catch (error) {
      console.error('Error processing request:', error);
      return createResponse(500, {
          error: 'Internal server error',
          reply: 'Sorry, something went wrong. Please try again.',
          message: error.message
      });
  }
};

/**
* Process user message and generate AI response
* Extend this function to integrate with AWS AI services
*/
async function processMessage(message) {
  const lowerMessage = message.toLowerCase().trim();
  
  // Simple rule-based responses - extend with AWS AI services
  // For production, integrate with Amazon Lex, Bedrock, or other AI services
  
  const responses = {
      // Greetings
      'hello': 'Hello! How can I help you today?',
      'hi': 'Hi there! What can I do for you?',
      'hey': 'Hey! How are you doing?',
      'good morning': 'Good morning! How can I assist you?',
      'good afternoon': 'Good afternoon! What can I help you with?',
      'good evening': 'Good evening! How may I help you?',
      
      // Help
      'help': 'I can help you with various tasks. Just tell me what you need!',
      'what can you do': 'I can answer questions, provide information, and assist with various tasks. Just ask!',
      
      // Weather (mock - extend with AWS Weather service)
      'weather': 'I cannot check the weather at the moment. Please check your weather app for accurate forecasts.',
      
      // Time
      'time': `The current time is ${new Date().toLocaleTimeString()}.`,
      'date': `Today's date is ${new Date().toLocaleDateString()}.`,
      
      // Farewell
      'bye': 'Goodbye! It was nice talking to you!',
      'goodbye': 'Goodbye! Have a great day!',
      'see you': 'See you later! Take care!',
      
      // Thanks
      'thank': 'You\'re welcome! Happy to help!',
      'thanks': 'You\'re welcome! Any other questions?',
      
      // Default fallback
      'default': 'I understand you said: "' + message + '". How can I help you further?'
  };
  
  // Check for matching responses
  for (const [key, response] of Object.entries(responses)) {
      if (lowerMessage.includes(key)) {
          return response;
      }
  }
  
  // Default response
  return responses.default;
}

/**
* Create API Gateway response with CORS headers
*/
function createResponse(statusCode, body) {
  const response = {
      statusCode: statusCode,
      headers: {
          ...getCorsHeaders(),
          'Content-Type': 'application/json'
      },
      body: typeof body === 'string' ? body : JSON.stringify(body),
      isBase64Encoded: false
  };
  console.log('Returning response with status:', statusCode);
  return response;
}

/**
* Get CORS headers for cross-origin requests
*/
function getCorsHeaders() {
  return {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
      'Access-Control-Max-Age': '86400'
  };
}
