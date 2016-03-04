<#
.SYNOPSIS
Create-IcfVM, Create ICF Cloud VM
.DESCRIPTION
Create-IcfVM, Create ICF Cloud VM
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Create-IcfVM.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password -IcfCatalogName CentOS63-us-east -IcfVdcName tme-us-west -IcfDataNetwork
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Catalog name")]
      [string] $IcfCatalogName,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Cloud VDC name")]
      [string] $IcfVdcName,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF User Group")]
      [string] $IcfDataNetwork,

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

$IcfCatalogNameOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource catalog-items -IcfObjectName $IcfCatalogName)
$IcfVdcNameOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource vdcs -IcfObjectName $IcfVdcName)
$IcfDataNetworkOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource networks -IcfObjectName $IcfDataNetwork)


if ($showResponse) {
    Write-Host "Catalog $IcfCatalogName and OID: $IcfCatalogNameOid"
    Write-Host "Vdc $IcfVdcName and OID: $IcfVdcNameOid"
    Write-Host "Data Network $IcfDataNetwork and OID: $IcfDataNetworkOid"
}

if ($IcfCatalogNameOid.Length -gt 0 -and $IcfVdcNameOid.Length -gt 0 -and $IcfDataNetworkOid.Length -gt 0) {

    Write-Host "Creating an ICF Cloud VM"

    $icfOp = '/instances'
    $json = @"
        {  
            "vdc_oid":"$IcfVdcNameOid",
            "catalog_oid":"$IcfCatalogNameOid",
            "nic_configurations" : [{  
                "nic_index":1,
                "is_dhcp":false,
                "network_oid":"$IcfDataNetworkOid"
            }]
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

        Write-Host "SR Status: " $SrStatus

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
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}