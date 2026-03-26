import { BedrockRuntimeClient, InvokeModelCommand } from "@aws-sdk/client-bedrock-runtime";

const bedrockClient = new BedrockRuntimeClient({ region: 'eu-north-1' });
const modelId = 'anthropic.claude-3-haiku-20240307-v1:0';

async function handler(event) {
    console.log('========== HANDLER INVOKED ==========');
    console.log('Raw event:', JSON.stringify(event, null, 2));
    
    // Handle CORS preflight
    if (event.httpMethod === 'OPTIONS') {
        console.log('CORS preflight request');
        return {
            statusCode: 200,
            headers: getCorsHeaders(),
            body: JSON.stringify({ message: 'OK' })
        };
    }
    
    try {
        let body = event.body;
        console.log('Raw body type:', typeof body, 'value:', body);
        
        if (typeof body === 'string') {
            console.log('Parsing JSON string body');
            body = JSON.parse(body || '{}');
        }
        
        const userMessage = body?.message || '';
        console.log('Extracted message:', userMessage);
        
        if (!userMessage.trim()) {
            console.log('ERROR: Empty message');
            return {
                statusCode: 400,
                headers: getCorsHeaders(),
                body: JSON.stringify({ error: 'No message provided' })
            };
        }
        
        // Get response from Bedrock
        console.log('Calling Bedrock...');
        const reply = await getBedrocResponse(userMessage);
        console.log('Bedrock returned:', reply);
        
        return {
            statusCode: 200,
            headers: getCorsHeaders(),
            body: JSON.stringify({ reply }),
            isBase64Encoded: false
        };
    } catch (error) {
        console.error('ERROR in handler:', error);
        console.error('Error stack:', error.stack);
        return {
            statusCode: 500,
            headers: getCorsHeaders(),
            body: JSON.stringify({ 
                error: error.message,
                reply: 'I apologize, but I encountered an error. Please try again.',
                details: error.code || 'Unknown error'
            })
        };
    }
}

async function getBedrocResponse(userMessage) {
    try {
        console.log('===== BEDROCK CLAUDE 3 CALL START =====');
        console.log('Model ID:', modelId);
        console.log('User message:', userMessage);
        
        const params = {
            body: JSON.stringify({
                anthropic_version: '2023-05-03',
                max_tokens: 300,
                messages: [
                    {
                        role: 'user',
                        content: [
                            {
                                type: 'text',
                                text: `You are a helpful and accurate AI assistant. Give direct and accurate answers without repeating the question. Keep responses short and clear.\n\nUser: ${userMessage}\n\nAssistant:`
                            }
                        ]
                    }
                ],
                temperature: 0.7,
                top_p: 0.9
            }),
            contentType: 'application/json',
            modelId: modelId
        };
        
        console.log('Params prepared. Calling Bedrock Claude 3...');
        const command = new InvokeModelCommand(params);
        console.log('Command created. Sending...');
        
        const response = await bedrockClient.send(command);
        console.log('Bedrock response received');
        console.log('Response status:', response.$metadata?.httpStatusCode);
        
        // Parse Claude 3 response
        const responseBody = JSON.parse(new TextDecoder().decode(response.body));
        console.log('Parsed response:', JSON.stringify(responseBody, null, 2));
        
        // Extract generated text from Claude 3 response
        const textContent = responseBody.content?.[0]?.text?.trim() || responseBody.generation?.trim() || 'I could not generate a response.';
        console.log('Extracted text:', textContent);
        console.log('===== BEDROCK CLAUDE 3 CALL END =====');
        
        return textContent;
    } catch (error) {
        console.error('===== BEDROCK ERROR =====');
        console.error('Error name:', error.name);
        console.error('Error code:', error.code);
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);
        console.error('===== BEDROCK ERROR END =====');
        throw error;
    }
}

function getCorsHeaders() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    };
}

export default handler;
export { handler };
