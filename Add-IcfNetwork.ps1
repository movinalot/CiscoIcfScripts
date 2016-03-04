<#
.SYNOPSIS
Add-IcfNetwork, Add ICF Network
.DESCRIPTION
Add-IcfNetwork, Add ICF Network
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Add-IcfNetwork.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password -IcfGroup dev-group -IcfGroupDescr "The Dev Users Group"
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Network name")]
      [string] $IcfDataNetWorkName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF Network CIDR")]
      [string] $IcfDataNetWorkCidr = '',

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF Network gateway")]
      [string] $IcfDataNetWorkGate = '',

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF Network IP pool")]
      [string] $IcfDataNetPoolName = '',

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF Network IP address range")]
      [string] $IcfDataNetPoolAddr = '',

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

# Get the Networks
Write-Host "Checking for Exisitng ICF Data $IcfDataNetWorkName Network"
$icfOp = '/networks'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.segment_id.Length -ge 1) {
        $IcfNetworkSegmentId = $fromJson.value[$i].properties.segment_id
        "Segment ID: " + $IcfNetworkSegmentId, $IcfNetworkSegmentId.Length
    }
    
    if ($fromJson.value[$i].properties.name -match $IcfDataNetWorkName) {
        Write-Host "Exisitng ICF Data Network Found"
        "ICF Data Network Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $IcfDataNetWorkNameOid = $fromJson.value[$i].properties.oid

        for ($j=0; $j -le $fromJson.value[0].properties.ip_pools.Count; $j++) {
            if ($fromJson.value[$i].properties.ip_pools[$j].name -match $icfDataNetPoolName) {
                Write-Host "Exisitng ICF Data Network IP Pool Found"
                "ICF Data IP Pool Name and OID: " + $fromJson.value[$i].properties.ip_pools[$j].name, $fromJson.value[$i].properties.ip_pools[$j].oid
                $IcfDataNetPoolNameOid = $fromJson.value[$i].properties.ip_pools[$j].oid
                break
            }
        }
    }
}

if ($IcfDataNetWorkNameOid.Length -eq 0) {

Write-Host "Create ICF Management Network $IcfDataNetWorkName"

    $IcfNetworkSegmentId++

    $json = @"
    {
        "object_type":"network",
        "name":"$IcfDataNetWorkName",
        "segment_id":"$IcfNetworkSegmentId",
        "cidr":"$IcfDataNetWorkCidr",
        "enterprise_gateway":"$IcfDataNetWorkGate",
        "enterprise_network_partitions":[],
        "is_data_network":true,
        "is_management_network":false,
        "is_l3_connected":true,
        "is_extended":true,
        "is_transport":false,
        "is_dhcp_enabled":false,
        "description":"",
        "ip_pools":[{
            "ip_version":"4",
            "name":"$IcfDataNetPoolName",
            "ips_in_pool":"$IcfDataNetPoolAddr"
        }]
    }
"@
    if ($showResponse) {$json}
    $icfOp = '/networks'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    # Get the Networks
    $icfOp = '/networks'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfDataNetWorkName) {
            Write-Host "ICF Data Network Created"
            "ICF Data Network Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
            $IcfDataNetWorkNameOid = $fromJson.value[$i].properties.oid

            for ($j=0; $j -le $fromJson.value[0].properties.ip_pools.Count; $j++) {
                if ($fromJson.value[$i].properties.ip_pools[$j].name -match $IcfDataNetPoolName) {
                    Write-Host "ICF Data Network IP Pool Created"
                    "ICF Data IP Pool Name and OID: " + $fromJson.value[$i].properties.ip_pools[$j].name, $fromJson.value[$i].properties.ip_pools[$j].oid
                    $IcfDataNetPoolNameOid = $fromJson.value[$i].properties.ip_pools[$j].oid
                    break
                }
            }
            break
        }
    }
    if ($IcfDataNetWorkNameOid.Length -gt 0 -and $IcfDataNetPoolNameOid.Length -gt 0) {
        Write-Host "ICF Network $IcfDataNetWorkName and IP Pool $IcfDataNetPoolName Created"
    }
}
 else {
    Write-Host "Network $IcfDataNetWorkName and IP Pool $IcfDataNetPoolName already exists in ICF"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}