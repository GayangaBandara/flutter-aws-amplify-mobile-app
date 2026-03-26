# Quick Redeploy Script for Voice AI Lambda
# This updates the Lambda function with the latest code without full re-deployment

param(
    [string]$FunctionName = "VoiceAIFunction",
    [string]$Region = "eu-north-1"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Voice AI Lambda Quick Redeploy" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "❌ AWS CLI not found. Please install it first." -ForegroundColor Red
    exit 1
}

# Create function.zip with updated code
Write-Host ""
Write-Host "📦 Creating function.zip..." -ForegroundColor Yellow

# Remove old zip if exists
if (Test-Path "function.zip") {
    Remove-Item "function.zip" -Force
}

# Create zip with index.mjs and node_modules
Write-Host "" 
Write-Host "📦 Creating function.zip..." -ForegroundColor Yellow

# Remove old zip if exists
if (Test-Path "function.zip") {
    Remove-Item "function.zip" -Force
}

# Create zip with index.mjs and node_modules
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open("$PWD\function.zip", [System.IO.Compression.ZipArchiveMode]::Create)
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$PWD\index.mjs", "index.mjs") | Out-Null
[System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, "$PWD\package.json", "package.json") | Out-Null

# Add node_modules from installed packages
$nodeModulesPath = "$PWD\node_modules"
if (Test-Path $nodeModulesPath) {
    Get-ChildItem -Path $nodeModulesPath -Recurse | ForEach-Object {
        if (-not $_.PSIsContainer) {
            $relativePath = $_.FullName.Substring($nodeModulesPath.Length + 1)
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, "node_modules\$relativePath") | Out-Null
        }
    }
}
$zip.Dispose()

Write-Host "✅ function.zip created" -ForegroundColor Green

# Update Lambda function
Write-Host ""
Write-Host "🚀 Updating Lambda function: $FunctionName..." -ForegroundColor Yellow

try {
    aws lambda update-function-code `
        --function-name $FunctionName `
        --zip-file fileb://function.zip `
        --region $Region | Out-Null
    
    Write-Host "✅ Lambda function updated successfully" -ForegroundColor Green
    
    # Wait for update to finish
    Write-Host ""
    Write-Host "⏳ Waiting for function update to complete..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    
    # Get function info
    $funcInfo = aws lambda get-function --function-name $FunctionName --region $Region | ConvertFrom-Json
    Write-Host "📝 Function State: $($funcInfo.Configuration.State)" -ForegroundColor Green
    Write-Host "📝 Last Modified: $($funcInfo.Configuration.LastModified)" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "✅ Redeploy Complete!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next step: Test your Flutter app with a hot reload (Ctrl+/)." -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "❌ Error updating Lambda function: $_" -ForegroundColor Red
    exit 1
}
