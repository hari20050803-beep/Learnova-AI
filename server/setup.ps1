# Deploys the Learnova AI password reset endpoint.
#
# Everything that can be automated is automated. Two things cannot be, because
# they are sign-ins to your own accounts:
#
#   1. `wrangler login`  — approve Cloudflare in the browser (free, no card)
#   2. the Firebase service account key — download it from the console
#
# Do those two, then run this script. It creates the store, reads the keys,
# sets every secret, deploys, and writes the address into the app.
#
#   cd server
#   .\setup.ps1 -ServiceAccountJson "C:\path\to\downloaded-key.json"

param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceAccountJson,

    # Any long random string. Only ever has to match itself.
    [string]$TicketSecret = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Step($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Ok($text) { Write-Host "    $text" -ForegroundColor Green }

# ---------------------------------------------------------------------------
Step 1 'Checking what is already in place'

if (-not (Test-Path $ServiceAccountJson)) {
    throw "Service account file not found: $ServiceAccountJson"
}
$sa = Get-Content $ServiceAccountJson -Raw | ConvertFrom-Json
foreach ($field in 'project_id', 'client_email', 'private_key') {
    if (-not $sa.$field) { throw "The JSON has no '$field'. Is it a service account key?" }
}
Ok "service account for $($sa.project_id)"

$who = npx --yes wrangler whoami 2>&1 | Out-String
if ($who -match 'not authenticated') {
    throw "Cloudflare is not signed in. Run  npx wrangler login  first, approve it in the browser, then run this again."
}
Ok 'Cloudflare signed in'

# The EmailJS ids already live in the app; read them rather than asking again.
$emailConfig = Get-Content '..\lib\config\email_config.dart' -Raw
function ReadDart([string]$name) {
    if ($emailConfig -match "$name\s*=\s*'([^']*)'") { return $Matches[1] }
    throw "Could not read $name from lib/config/email_config.dart"
}
$serviceId = ReadDart 'serviceId'
$templateId = ReadDart 'resetTemplateId'
if (-not $templateId -or $templateId -eq 'templateId') { $templateId = ReadDart 'templateId' }
$publicKey = ReadDart 'publicKey'
Ok "EmailJS service $serviceId, template $templateId"

# ---------------------------------------------------------------------------
Step 2 'Creating the store for pending codes'

$toml = Get-Content 'wrangler.toml' -Raw
if ($toml -match 'PASTE_THE_KV_NAMESPACE_ID_HERE') {
    $created = npx --yes wrangler kv namespace create OTP_KV 2>&1 | Out-String
    if ($created -notmatch 'id\s*=\s*"([0-9a-f]{32})"') {
        Write-Host $created
        throw 'Could not read the namespace id from wrangler output.'
    }
    $kvId = $Matches[1]
    (Get-Content 'wrangler.toml' -Raw).Replace('PASTE_THE_KV_NAMESPACE_ID_HERE', $kvId) |
        Set-Content 'wrangler.toml' -Encoding utf8 -NoNewline
    Ok "namespace $kvId"
}
else {
    Ok 'already created'
}

# ---------------------------------------------------------------------------
Step 3 'Storing the secrets on Cloudflare'

$secrets = [ordered]@{
    FIREBASE_PROJECT_ID  = $sa.project_id
    FIREBASE_CLIENT_EMAIL = $sa.client_email
    FIREBASE_PRIVATE_KEY = $sa.private_key
    EMAILJS_SERVICE_ID   = $serviceId
    EMAILJS_TEMPLATE_ID  = $templateId
    EMAILJS_PUBLIC_KEY   = $publicKey
    TICKET_SECRET        = $TicketSecret
}

foreach ($name in $secrets.Keys) {
    # wrangler reads the value from stdin, so nothing lands in the shell history.
    $secrets[$name] | npx --yes wrangler secret put $name 2>&1 | Out-Null
    Ok $name
}

Write-Host "`n    EMAILJS_PRIVATE_KEY is the one value not in the app." -ForegroundColor Yellow
Write-Host "    EmailJS -> Account -> API Keys -> Private Key" -ForegroundColor Yellow
$emailJsPrivate = Read-Host '    Paste it here'
if ($emailJsPrivate) {
    $emailJsPrivate | npx --yes wrangler secret put EMAILJS_PRIVATE_KEY 2>&1 | Out-Null
    Ok 'EMAILJS_PRIVATE_KEY'
}
else {
    Write-Host '    Skipped. EmailJS must then have "Use Private Key" switched OFF.' -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
Step 4 'Deploying'

$deploy = npx --yes wrangler deploy 2>&1 | Out-String
Write-Host $deploy
if ($deploy -notmatch 'https://[a-z0-9.\-]+\.workers\.dev') {
    throw 'Deploy finished but no address was printed. Read the output above.'
}
$url = $Matches[0].TrimEnd('/')
Ok $url

# ---------------------------------------------------------------------------
Step 5 'Telling the app where it is'

$configPath = '..\lib\config\reset_config.dart'
(Get-Content $configPath -Raw).Replace('PASTE_YOUR_WORKER_URL_HERE', $url) |
    Set-Content $configPath -Encoding utf8 -NoNewline
Ok "written into lib/config/reset_config.dart"

# ---------------------------------------------------------------------------
Step 6 'Checking it answers'

try {
    $probe = Invoke-RestMethod -Method Post -Uri "$url/otp" `
        -ContentType 'application/json' `
        -Body '{"email":"definitely-not-a-real-account@example.com"}' `
        -ErrorAction Stop
    Write-Host "    unexpected success: $($probe | ConvertTo-Json -Compress)" -ForegroundColor Yellow
}
catch {
    $body = ''
    if ($_.ErrorDetails.Message) { $body = $_.ErrorDetails.Message }
    if ($body -match 'no-account') {
        Ok 'the endpoint is live and talking to Firebase'
    }
    else {
        Write-Host "    unexpected reply: $body" -ForegroundColor Yellow
        Write-Host '    Check the secrets with:  npx wrangler tail' -ForegroundColor Yellow
    }
}

Write-Host "`nDone. Now rebuild the app:" -ForegroundColor Cyan
Write-Host "  cd ..; flutter build apk --release --target-platform android-arm64"
