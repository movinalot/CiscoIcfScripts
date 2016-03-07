<#
.SYNOPSIS
Create-IcfCatalog, Create ICF Catalog
.DESCRIPTION
Create-IcfCatalog, Create ICF Catalog
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Create-IcfCatalog.ps1 -IcfHost 10.10.10.100 -IcfAdmin admin -IcfAdminPass password -IcfCatalogName CentOS63-us-east -IcfImageName centos63min -IcfUserGroup user-group -IcfCloud cloud-01
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

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Image name")]
      [string] $IcfImageName,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF User Group")]
      [string] $IcfUserGroup,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Cloud")]
      [string] $IcfCloud,

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
$IcfImageNameOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource images -IcfObjectName $IcfImageName)
$IcfUserGroupOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource user-groups -IcfObjectName $IcfUserGroup)
$IcfCloudOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource icf-clouds -IcfObjectName $IcfCloud)

if ($showResponse) {
    Write-Host "Catalog $IcfCatalogName and OID: $IcfCatalogNameOid"
    Write-Host "Image $IcfImageName and OID: $IcfImageNameOid"
    Write-Host "Group $IcfUserGroup and OID: $IcfUserGroupOid"
    Write-Host "Cloud $IcfCloud and OID: $IcfCloudOid"
}

if ($IcfCatalogNameOid -eq 0 -and ($IcfImageNameOid.Length -gt 0 -and $IcfUserGroupOid.Length -gt 0 -and $IcfCloudOid.Length -gt 0)) {

    Write-Host "Creating Catalog Item $IcfCatalogName in ICF"

    $icfOp = '/catalog-items'
    $json = @"
        {  
            "name":"$IcfCatalogName",
            "image_oid":"$IcfImageNameOid",
            "usergroup_oids":[  
                "$IcfUserGroupOid"
            ],
            "icf_cloud_oids":[  
                "$IcfCloudOid"
            ]
        }
"@
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json
    $icfSR = $fromJson.success.links.service_request

    # Query the SR checking status. Timeout after 60 mins
    $SrStatus = ''
    $timeout = new-timespan -Minutes 120
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

    $IcfCatalogNameOid = $(..\Get-IcfObjectOid.ps1 -IcfHost $IcfHost -IcfAdmin $IcfAdmin -IcfAdminPass $IcfAdminPass -IcfObjectResource catalog-items -IcfObjectName $IcfCatalogName)

    if ($IcfCatalogNameOid -gt 0) {
        Write-Host "Catalog Item $IcfCatalogName created in ICF"
    }
} else {
    Write-Host "Catalog Item $IcfCatalogName already exists in ICF"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}