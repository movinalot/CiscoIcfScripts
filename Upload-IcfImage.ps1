<#
.SYNOPSIS
Upload-IcfImage, Upload ICF Image
.DESCRIPTION
Upload-IcfImage, Upload ICF Image
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Upload-IcfImage.ps1 -IcfHost 10.10.10.10 -IcfAdmin admin -IcfAdminPass password -IcfImageName centos63min1 -IcfImagePath /root/centos-6.3-minimal.ova -IcfImageHost 10.10.10.20 -IcfImageHostUser root -IcfImageHostUserPass password
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an Image Name")]
      [string] $IcfImageName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Image Path")]
      [string] $IcfImagePath,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Image Host")]
      [string] $IcfImageHost,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Image Host User")]
      [string] $IcfImageHostUser,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Image Host User Password")]
      [string] $IcfImageHostUserPass,

    [Parameter(Mandatory=$false,HelpMessage="Enter the Image Host Transfer Protocol")]
      [string] $IcfImageHostUploadProtocol = 'SCP',

    [Parameter(Mandatory=$false,HelpMessage="Show ICF API responses")]
      [switch] $showResponse = $false
);

$icfAPIUrl  = 'http://' + $IcfHost
$icfAPIPath = '/icfb'
$icfAPIVer  = '/v1'

# Login / Get Token / Start Session
$icfOp = '/token'
$json = @"
{
    "username":"$IcfAdmin",
    "password":"$IcfAdminPass"
}
"@

$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Body $json -ContentType 'application/json' -SessionVariable myIcfSession
if ($showResponse) {$response}

# Show the token and the Session Cookie
if ($showResponse) {
    $response.BaseResponse
    $myIcfSession.Cookies.GetCookies($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp)
}

# Set the token in the header
$headers=@{
    'x_icfb_token' = $response.BaseResponse.Headers.Get('x_icfb_token')
}

$icfOp = '/images'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfImageName) {
        "Image Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $IcfImageNameOid = $fromJson.value[$i].properties.oid
        break
    }
}

if ($IcfImageNameOid.Length -eq 0) {

    Write-Host "Uploading image Template: $IcfImageName"

    $icfOp = '/images'
    $json = @"
        {
            "name":"$IcfImageName",
            "ip_address":"$IcfImageHost",
            "user_name":"$IcfImageHostUser",
            "password":"$IcfImageHostUserPass",
            "protocol":"$IcfImageHostUploadProtocol",
            "image_path":"$IcfImagePath"
        }
"@
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json
    $icfSR = $fromJson.success.links.service_request

    # Query the SR checking status. Timeout after 10 mins
    $SrStatus = ''
    $timeout = new-timespan -Minutes 10
    $sw = [diagnostics.stopwatch]::StartNew()
    while ($sw.elapsed -lt $timeout){

        $response = Invoke-WebRequest $icfSR -Method Get -Headers $headers -WebSession $myIcfSession
        if ($showResponse) {$response}
        $fromJson = $response.Content | ConvertFrom-Json
        $SrStatus = $fromJson.value[0].properties.execution_status

        Write-Host "SR Status: " + $SrStatus

        if ($SrStatus -match 'SUCCESS') {
            break
        }
 
        start-sleep -seconds 30
    }

    if (!($SrStatus -match 'SUCCESS')) {
        write-host "SR Process Timed out"
        # Logout
        $icfOp = '/logout'
        $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
        if ($showResponse) {$response}
        exit
    }


    $icfOp = '/images'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfImageName) {
            "Image Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
            $IcfImageNameOid = $fromJson.value[$i].properties.oid
            break
        }
    }
    Write-Host "Image $IcfImageName created in ICF"

} else {
    Write-Host "Image $IcfImageName already exists in ICF"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}