<#
.SYNOPSIS
Check-IcfApi, Check For ICF API
.DESCRIPTION
Check-IcfApi, Check For ICF API
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Check-IcfApi.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

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


While ($true) {

    Write-Host "Checking Availability of ICF API"

    try {
        $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Body $json -ContentType 'application/json' -SessionVariable myIcfSession -TimeoutSec 10 -ErrorVariable icfLoginError
    }
    catch [Net.WebException] {
        $icfWebException = $_.Exception.ToString()
    }
  
    #$icfLoginError

    if ($response.Length -gt 0) {
        if ($showResponse) {$response}
        break
    }

    Write-Host "ICF API not yet availability, check again in 30 seconds"
    start-sleep -seconds 30
}

# Show the token and the Session Cookie
if ($showResponse) {
    $response.BaseResponse
    $myIcfSession.Cookies.GetCookies($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp)
}

# Set the token in the header
$headers=@{
    'x_icfb_token' = $response.BaseResponse.Headers.Get('x_icfb_token')
}


# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession -TimeoutSec 3
if ($showResponse) {$response}

Write-Host "ICF API is avaialble"