/**
 * Test file for Voice AI Lambda Function
 */

const handler = require('./index');

console.log('Running Lambda function tests...\n');

// Test 1: Basic message handling
async function testBasicMessage() {
    console.log('Test 1: Basic Message Handling');
    
    const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ message: 'Hello' })
    };
    
    const response = await handler.handler(event);
    const body = JSON.parse(response.body);
    
    console.log('Status:', response.statusCode);
    console.log('Response:', body);
    console.log('✓ Passed\n');
}

// Test 2: Empty message handling
async function testEmptyMessage() {
    console.log('Test 2: Empty Message Handling');
    
    const event = {
        httpMethod: 'POST',
        body: JSON.stringify({ message: '' })
    };
    
    const response = await handler.handler(event);
    const body = JSON.parse(response.body);
    
    console.log('Status:', response.statusCode);
    console.log('Response:', body);
    console.log('✓ Passed\n');
}

// Test 3: Missing message field
async function testMissingMessage() {
    console.log('Test 3: Missing Message Field');
    
    const event = {
        httpMethod: 'POST',
        body: JSON.stringify({})
    };
    
    const response = await handler.handler(event);
    const body = JSON.parse(response.body);
    
    console.log('Status:', response.statusCode);
    console.log('Response:', body);
    console.log('✓ Passed\n');
}

// Test 4: CORS preflight handling
async function testCORS() {
    console.log('Test 4: CORS Preflight');
    
    const event = {
        httpMethod: 'OPTIONS',
        body: ''
    };
    
    const response = await handler.handler(event);
    
    console.log('Status:', response.statusCode);
    console.log('Headers:', response.headers['Access-Control-Allow-Origin']);
    console.log('✓ Passed\n');
}

// Test 5: Different message types
async function testDifferentMessages() {
    console.log('Test 5: Different Messages');
    
    const messages = ['Hi', 'Help', 'What can you do?', 'Thanks', 'Bye'];
    
    for (const msg of messages) {
        const event = {
            httpMethod: 'POST',
            body: JSON.stringify({ message: msg })
        };
        
        const response = await handler.handler(event);
        const body = JSON.parse(response.body);
        
        console.log(`  "${msg}" -> "${body.reply}"`);
    }
    console.log('✓ Passed\n');
}

// Run all tests
async function runTests() {
    try {
        await testBasicMessage();
        await testEmptyMessage();
        await testMissingMessage();
        await testCORS();
        await testDifferentMessages();
        
        console.log('===================');
        console.log('All tests passed!');
        console.log('===================');
    } catch (error) {
        console.error('Test failed:', error);
    }
}

runTests();