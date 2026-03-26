#!/bin/bash

# Voice AI Lambda Deployment Script
# This script deploys the Lambda function and API Gateway using AWS CLI

echo "========================================="
echo "Voice AI Lambda Deployment"
echo "========================================="

# Configuration
FUNCTION_NAME="VoiceAIFunction"
API_NAME="VoiceAIApi"
STAGE_NAME="prod"
REGION="us-east-1"

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "AWS Account: $AWS_ACCOUNT_ID"

# Create Lambda function
echo "Creating Lambda function..."
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime nodejs20.x \
    --role arn:aws:iam::$AWS_ACCOUNT_ID:role/lambda-execution-role \
    --handler index.handler \
    --zip-file fileb://function.zip \
    --description "Voice AI Lambda for Flutter app" \
    --timeout 30 \
    --memory-size 256 \
    --region $REGION

if [ $? -eq 0 ]; then
    echo "✓ Lambda function created successfully"
else
    echo "✗ Failed to create Lambda function"
    exit 1
fi

# Create API Gateway REST API
echo "Creating API Gateway..."
API_ID=$(aws apigateway create-rest-api \
    --name $API_NAME \
    --region $REGION \
    --query 'id' \
    --output text)

echo "API ID: $API_ID"

# Get resource ID for root
RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION \
    --query 'items[0].id' \
    --output text)

# Create /chat resource
CHAT_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $RESOURCE_ID \
    --path-part chat \
    --region $REGION \
    --query 'id' \
    --output text)

# Create POST method
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method POST \
    --authorization-type NONE \
    --region $REGION

# Set Lambda integration (use proxy integration so Lambda receives proxy event)
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method POST \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:$AWS_ACCOUNT_ID:function:$FUNCTION_NAME/invocations \
    --region $REGION

# Create OPTIONS method for CORS
aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $REGION

# Set mock integration for OPTIONS
aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region $REGION

# Add CORS headers to OPTIONS method response
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true" \
    --region $REGION

# Add CORS headers to POST method response
aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method POST \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin=true" \
    --region $REGION

# Add CORS headers to integration response
aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin='*',method.response.header.Access-Control-Allow-Headers='Content-Type,Authorization',method.response.header.Access-Control-Allow-Methods='GET,POST,OPTIONS'" \
    --region $REGION

aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $CHAT_RESOURCE_ID \
    --http-method POST \
    --status-code 200 \
    --response-parameters "method.response.header.Access-Control-Allow-Origin='*'" \
    --region $REGION

# Deploy API
echo "Deploying API..."
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name $STAGE_NAME \
    --region $REGION

# Grant API Gateway permission to invoke the Lambda (ignore error if exists)
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id apigateway-invoke-permissions \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:$AWS_ACCOUNT_ID:$API_ID/*/POST/chat" \
    --region $REGION || true

# Get the API endpoint URL
API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/$STAGE_NAME/chat"
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "API Endpoint: $API_URL"
echo ""
echo "Update your Flutter app with this URL:"
echo "final String _apiUrl = '$API_URL';"
echo ""
