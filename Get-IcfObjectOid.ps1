<#
.SYNOPSIS
Get-IcfObjectOid, Get ICF Object OID
.DESCRIPTION
Get-IcfObjectOid, Get ICF Object OID
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Get-IcfObjectOid.ps1 -IcfHost 173.36.252.119 -IcfAdmin admin -IcfAdminPass "C1sco12345*" -IcfObjectResource images -IcfObjectName centos63min
Get-IcfObjectOid.ps1 -IcfHost 173.36.252.119 -IcfAdmin admin -IcfAdminPass "C1sco12345*" -IcfObjectResource user-groups -IcfObjectName tme-group
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Object Resource type")]
      [string] $IcfObjectResource,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Object name")]
      [string] $IcfObjectName,

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

$icfOp = '/' + $IcfObjectResource
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -eq $IcfObjectName) {
        $IcfObjectNameOid = $fromJson.value[$i].properties.oid
        break
    }
}

if ($IcfObjectNameOid.Length -gt 0) {
    $IcfObjectNameOid
} else {
  "0"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}