# API Gateway CORS Fix - Complete Guide

## Issue
Flutter web app is getting "ClientException: Failed to fetch" - this is a CORS (Cross-Origin Resource Sharing) error. The browser is blocking the request because API Gateway is not returning proper CORS headers.

## Solution: API Gateway CORS Configuration

### Step 1: Go to API Gateway Console
1. Open AWS Console: https://console.aws.amazon.com/apigateway/
2. Find your API: `voice-agent-api-API`
3. Click on it to open

### Step 2: Configure CORS for POST Method
1. In the left panel, click **Resources**
2. Select the `/voice-agent-api` resource
3. Click on the **POST** method
4. Click on **Integration Response** (NOT Method Response)
5. Expand the **200** response arrow
6. Click on **Add Header** and add these headers:

| Header Name | Mapped from |
|---|---|
| Access-Control-Allow-Headers | 'Content-Type,Authorization' |
| Access-Control-Allow-Methods | 'POST,OPTIONS' |
| Access-Control-Allow-Origin | '*' |

7. Repeat this for the **OPTIONS** method if it exists
8. Click on **Integration Response** for OPTIONS → expand **200** → add same headers

### Step 3: Deploy API
1. Click the **Deploy API** button (orange, top-right)
2. Select stage: `default`
3. Click **Deploy**
4. Wait for confirmation message

### Step 4: Test the Endpoint

#### Option A: Browser Test
1. Open new tab: `https://zk3wybbw4l.execute-api.eu-north-1.amazonaws.com/default/voice-agent-api`
2. You should see: `{"message":"OK"}` or similar
3. If you see CORS error in console, CORS is not deployed yet

#### Option B: PowerShell Test
```powershell
$body = @{ message = "hello" } | ConvertTo-Json
$response = Invoke-WebRequest `
  -Uri "https://zk3wybbw4l.execute-api.eu-north-1.amazonaws.com/default/voice-agent-api" `
  -Method POST `
  -Headers @{"Content-Type"="application/json"} `
  -Body $body

Write-Host "Status: $($response.StatusCode)"
Write-Host "Response: $($response.Content)"
```

### Step 5: Test Flutter App
1. Save any unsaved work
2. Hot reload Flutter app (Ctrl+/ or in terminal: r)
3. Try voice command again
4. Check DevTools console for new detailed logging

## Troubleshooting

### Still getting "Failed to fetch"?
- **Check 1**: Did you click **Deploy API**? (Most common mistake)
- **Check 2**: In the Integration Response, are ALL 3 CORS headers added?
- **Check 3**: Is the stage `default` (not `prod`)?
- **Check 4**: Did you wait 30 seconds after deploying?

### Getting 404 or 403?
- Check if resource path is exactly `/voice-agent-api`
- Check if Lambda function exists and is accessible
- Check Lambda execution role permissions

### Getting 500?
- Check Lambda CloudWatch logs: https://console.aws.amazon.com/logs/
- Look for errors in the `voice-agent-api` log group
- Common cause: Lambda environment or code issue

## Verification Checklist
- [ ] Clicked "Deploy API" in API Gateway console
- [ ] API Gateway stage is "default"
- [ ] POST method has Integration Response with 3 CORS headers
- [ ] OPTIONS method has Integration Response with 3 CORS headers
- [ ] Waited 30+ seconds after deployment
- [ ] Tested endpoint in browser or PowerShell
- [ ] Hot-reloaded Flutter app

## Still Not Working?
Share your findings:
1. Status code from PowerShell test or browser
2. Exact error message
3. Response headers shown in browser DevTools (F12 → Network tab)
