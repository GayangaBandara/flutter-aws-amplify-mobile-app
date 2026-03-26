@echo off
REM Voice AI Lambda Deployment Script for Windows
REM This script deploys the Lambda function and API Gateway using AWS CLI

echo =========================================
echo Voice AI Lambda Deployment
echo =========================================

REM Configuration
set FUNCTION_NAME=VoiceAIFunction
set API_NAME=VoiceAIApi
set STAGE_NAME=prod
set REGION=eu-north-1

REM Get AWS account ID
for /f "delims=" %%i in ('aws sts get-caller-identity --query Account --output text') do set AWS_ACCOUNT_ID=%%i
echo AWS Account: %AWS_ACCOUNT_ID%

REM Create Lambda function
echo Creating Lambda function...
aws lambda create-function ^
    --function-name %FUNCTION_NAME% ^
    --runtime nodejs20.x ^
    --role arn:aws:iam::%AWS_ACCOUNT_ID%:role/lambda-execution-role ^
    --handler index.handler ^
    --zip-file fileb://function.zip ^
    --description "Voice AI Lambda for Flutter app" ^
    --timeout 30 ^
    --memory-size 256 ^
    --region %REGION%

if %ERRORLEVEL% EQU 0 (
    echo Lambda function created successfully
) else (
    echo Failed to create Lambda function
    exit /b 1
)

REM Create API Gateway REST API
echo Creating API Gateway...
for /f "delims=" %%i in ('aws apigateway create-rest-api --name %API_NAME% --region %REGION% --query id --output text') do set API_ID=%%i
echo API ID: %API_ID%

REM Get resource ID for root
for /f "delims=" %%i in ('aws apigateway get-resources --rest-api-id %API_ID% --region %REGION% --query "items[0].id" --output text') do set RESOURCE_ID=%%i

REM Create /chat resource
for /f "delims=" %%i in ('aws apigateway create-resource --rest-api-id %API_ID% --parent-id %RESOURCE_ID% --path-part chat --region %REGION% --query id --output text') do set CHAT_RESOURCE_ID=%%i

REM Create POST method
aws apigateway put-method --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method POST --authorization-type NONE --region %REGION%

REM Set Lambda integration (use proxy integration so Lambda receives proxy event)
aws apigateway put-integration --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method POST --type AWS_PROXY --integration-http-method POST --uri arn:aws:apigateway:%REGION%:lambda:path/2015-03-31/functions/arn:aws:lambda:%REGION%:%AWS_ACCOUNT_ID%:%FUNCTION_NAME%/invocations --region %REGION%

REM Create OPTIONS method for CORS
aws apigateway put-method --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method OPTIONS --authorization-type NONE --region %REGION%

REM Set mock integration for OPTIONS
aws apigateway put-integration --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method OPTIONS --type MOCK --request-templates "{\"application/json\":\"{\\\"statusCode\\\": 200}\"}" --region %REGION%

REM Add CORS headers to OPTIONS method response
aws apigateway put-method-response --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method OPTIONS --status-code 200 --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Headers=true,method.response.header.Access-Control-Allow-Methods=true" --region %REGION%

REM Add CORS headers to POST method response
aws apigateway put-method-response --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method POST --status-code 200 --response-parameters "method.response.header.Access-Control-Allow-Origin=true" --region %REGION%

REM Add CORS headers to integration response
aws apigateway put-integration-response --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method OPTIONS --status-code 200 --response-parameters "method.response.header.Access-Control-Allow-Origin='*',method.response.header.Access-Control-Allow-Headers='Content-Type,Authorization',method.response.header.Access-Control-Allow-Methods='GET,POST,OPTIONS'" --region %REGION%

aws apigateway put-integration-response --rest-api-id %API_ID% --resource-id %CHAT_RESOURCE_ID% --http-method POST --status-code 200 --response-parameters "method.response.header.Access-Control-Allow-Origin='*'" --region %REGION%

REM Deploy API
echo Deploying API...
aws apigateway create-deployment --rest-api-id %API_ID% --stage-name %STAGE_NAME% --region %REGION%

REM Grant API Gateway permission to invoke the Lambda (ignore error if exists)
aws lambda add-permission --function-name %FUNCTION_NAME% --statement-id apigateway-invoke-permissions --action lambda:InvokeFunction --principal apigateway.amazonaws.com --source-arn "arn:aws:execute-api:%REGION%:%AWS_ACCOUNT_ID%:%API_ID%/*/POST/chat" --region %REGION% || exit /b 0

REM Get the API endpoint URL
set API_URL=https://%API_ID%.execute-api.%REGION%.amazonaws.com/%STAGE_NAME%/chat

echo.
echo =========================================
echo Deployment Complete!
echo =========================================
echo API Endpoint: %API_URL%
echo.
echo Update your Flutter app with this URL:
echo final String _apiUrl = '%API_URL%';
echo.

pause