﻿<#
.SYNOPSIS
Add-IcfUserGroup, Add ICF User Group
.DESCRIPTION
Add-IcfUserGroup, Add ICF User Group
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Add-IcfUserGroup.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password -IcfGroup dev-group -IcfGroupDescr "The Dev Users Group"
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Group")]
      [string] $IcfGroup,

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF Group Description")]
      [string] $IcfGroupDescr = '',

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

$icfOp = '/user-groups'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfGroup) {
        "User Group Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $icfUserGroupOid = $fromJson.value[$i].properties.oid
        break
    }
}

if ($icfUserGroupOid.Length -eq 0) {

    Write-Host "Creating User Group $IcfGroup in ICF"

    $icfOp = '/user-groups'
    $json = @"
        {
            "name" : "$IcfGroup",
            "description" : "$IcfGroupDescr"

        }
"@
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    $icfOp = '/user-groups'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfGroup) {
            "User Group Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
            $icfUserGroupOid = $fromJson.value[$i].properties.oid
            break
        }
    }

    Write-Host "User Group $IcfGroup created in ICF"
} else {
    Write-Host "User Group $IcfGroup already exists in ICF"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}