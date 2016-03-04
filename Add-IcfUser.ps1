<#
.SYNOPSIS
Add-IcfUser, Add ICF User
.DESCRIPTION
Add-IcfUser, Add ICF User
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Add-IcfUser.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password -IcfUser username -IcfUserPass password -IcfGroup dev-group
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF user")]
      [string] $IcfUser,

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF user Password")]
      [string] $IcfUserPass,

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF user role")]
      [string] $IcfUserRole = 'end_user',

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF user Group")]
      [string] $IcfGroup,

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF user email")]
      [string] $IcfUserEmail = $IcfUser + '@email.com',

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF user first name")]
      [string] $IcfUserFName = '',

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF user last name")]
      [string] $IcfUserLName = '',

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF user phone")]
      [string] $IcfUserPhone = '',

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF user address")]
      [string] $IcfUserAddress = '',

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

# Get User Groups
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
    Write-Host "User Group $IcfGroup was not found, Please Create the User Group before creating Users"
    # Logout
    $icfOp = '/logout'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    exit
}

$icfOp = '/users'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.username -match $IcfUser) {
        "User Name and OID: " + $fromJson.value[$i].properties.username + " " + $fromJson.value[$i].properties.oid
        $icfUserOid = $fromJson.value[$i].properties.oid
        break
    }
}

if ($icfUserGroupOid.Length -gt 0 -and $icfUserOid.Length -eq 0) {

    Write-Host "Creating User $IcfUser in ICF"

    $icfOp = '/users'
    $json = @"
        {
            "username" : "$IcfUser",
            "password" : "$IcfUserPass",
            "role" : "$IcfUserRole",
            "usergroup_oid" : "$icfUserGroupOid",
            "email": "$IcfUserEmail",
            "first_name": "$IcfUserFName",
            "last_name": "$IcfUserLName",
            "phone_number" : "$IcfUserPhone",
            "address": "$IcfUserAddress"
        }
"@
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    $icfOp = '/users'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json
    
    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.username -match $IcfUser) {
            "User Name and OID: " + $fromJson.value[$i].properties.username + " " + $fromJson.value[$i].properties.oid
            $icfUserOid = $fromJson.value[$i].properties.oid
            break
        }
    }
    Write-Host "User $IcfUser created in ICF"
} else {
    Write-Host "User $IcfUser already exists in ICF"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}