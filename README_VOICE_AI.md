# Voice AI - AWS Lambda Integration

This project connects your Flutter voice agent to AWS Lambda backend.

## Architecture

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   Flutter App   │ ───► │  API Gateway   │ ───► │  Lambda Func   │
│  (Speech-to-Text│      │  (REST API)     │      │  (Voice AI)    │
│   + TTS)        │ ◄──── │  (CORS enabled)│ ◄──── │  (Node.js)     │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

## Files Created

### Lambda Backend (`lambda/voice-agent/`)
- `index.js` - Lambda function handler with voice AI logic
- `package.json` - NPM package configuration
- `serverless.yml` - Serverless Framework configuration
- `deploy.sh` - Linux/macOS deployment script
- `deploy.bat` - Windows deployment script
- `test.js` - Local test file

### Flutter App (`lib/`)
- `aws_config.dart` - AWS configuration and models
- `main.dart` - Updated to use AWS config

## Deployment Steps

### Option 1: Using Serverless Framework (Recommended)

1. Install Serverless:
```bash
npm install -g serverless
```

2. Deploy:
```bash
cd lambda/voice-agent
serverless deploy
```

3. Copy the API endpoint URL from the output

### Option 2: Using AWS CLI Scripts

1. Create a ZIP file of the Lambda function:
```bash
cd lambda/voice-agent
zip -r function.zip index.js
```

2. Run the deployment script:
```bash
# Windows
deploy.bat

# Linux/macOS
chmod +x deploy.sh
./deploy.sh
```

3. Copy the API endpoint URL from the output

### Option 3: Manual AWS Console

1. **Create Lambda Function**:
   - Go to AWS Lambda → Create function
   - Runtime: Node.js 20.x
   - Handler: index.handler
   - Upload the `index.js` file

2. **Create API Gateway**:
   - Go to API Gateway → Create API → REST API
   - Create resource `/chat`
   - Add POST method, integrate with Lambda
   - Add OPTIONS method for CORS
   - Enable CORS
   - Deploy to a stage (e.g., "prod")

3. **Copy the API endpoint URL** (e.g., `https://abc123.execute-api.us-east-1.amazonaws.com/prod/chat`)

## Update Flutter App

After deployment, update `lib/aws_config.dart` with your API endpoint:

```dart
static const String apiEndpoint = 'https://your-api-id.execute-api.us-east-1.amazonaws.com/prod/chat';
```

## Test the Integration

1. Run the Lambda test:
```bash
cd lambda/voice-agent
node test.js
```

2. Run Flutter app:
```bash
flutter run
```

3. Tap the microphone and speak - you should get a response from the Lambda!

## Advanced: Adding AWS AI Services

### Amazon Lex (Conversational AI)
Update `index.js` to use Lex:
```javascript
const LexRuntime = require('@aws-sdk/client-lex-runtime');
// Add Lex V2 client for conversation
```

### Amazon Polly (Text-to-Speech)
Send Polly audio URL back to Flutter:
```javascript
const Polly = require('@aws-sdk/client-polly');
// Generate speech and return audio URL
```

### Amazon Bedrock (LLM)
Integrate with Claude/Llama for smarter responses:
```javascript
const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
```

## Permissions Required

The Lambda execution role needs:
- `lambda.amazonaws.com` (execution)
- For advanced services:
  - `lex:*` (Lex permissions)
  - `polly:*` (Polly permissions)
  - `bedrock:*` (Bedrock permissions)

## Troubleshooting

### CORS Errors
- Ensure Lambda returns proper CORS headers
- Check API Gateway CORS is enabled
- For API Gateway, enable CORS in the console or add mock integration for OPTIONS

### 403 Errors
- Check API Gateway method is configured
- Verify Lambda function name in integration
- Check API Gateway resource policy

### 500 Errors
- Check CloudWatch logs
- Verify Lambda handler path is correct
- Check Lambda execution role permissions

### "Failed to fetch" Error
This is usually a CORS issue. To fix:
1. Go to API Gateway Console
2. Select your API
3. Go to Resources → /chat → OPTIONS method
4. Enable CORS
5. Deploy the API again