<#
.SYNOPSIS
Build-IcfInfra, Build ICF Infrastructure
.DESCRIPTION
Build-IcfInfra, Build ICF Infrastructure
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Build-IcfInfra.ps1 -VCenter 10.10.10.10 -VcUser administrator -VcPass "C1sco12345" -IcfHost 173.36.252.127 -IcfAdmin admin -IcfAdminPass "C1sco12345*" -IcfVmmVaName vcenter -IcfVmmVaType vmware -IcfHypervisorHost 173.36.252.38 -IcfHypervisorDatastore Nexsan-Lun-00 -IcfHypervisorMgmtPg icf-mgmt -IcfMgmtNetWorkName mgmt -IcfMgmtNetWorkCidr "173.36.252.0/24" -IcfMgmtNetWorkGate 173.36.252.1 -IcfMgmtNetPoolName infra -IcfMgmtNetPoolAddr "173.36.252.129-173.36.252.134"
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter a vCenter hostname or IP address")]
      [string] $VCenter,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter vCenter admin")]
      [string] $VcUser,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter vCenter admin's Password")]
      [string] $VcPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF hostname or IP address")]
      [string] $IcfHost,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin")]
      [string] $IcfAdmin,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter ICF admin's Password")]
      [string] $IcfAdminPass,

    [Parameter(Mandatory=$true,HelpMessage="Enter a VMM Virtual Account Name")]
      [string] $IcfVmmVaName,

    [Parameter(Mandatory=$true,HelpMessage="Enter a VMM Type")]
      [string] $IcfVmmVaType,

    [Parameter(Mandatory=$true,HelpMessage="Enter a Hypervisor host on which to deploy ICF Infrastucture")]
      [string] $IcfHypervisorHost,

    [Parameter(Mandatory=$true,HelpMessage="Enter a Hypervisor host datastore on which to deploy ICF Infrastructure")]
      [string] $IcfHypervisorDatastore,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Hypervisor Management Port Group")]
      [string] $IcfHypervisorMgmtPg,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network name")]
      [string] $IcfMgmtNetWorkName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network CIDR")]
      [string] $IcfMgmtNetWorkCidr,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network Gateway")]
      [string] $IcfMgmtNetWorkGate,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network IP pool name")]
      [string] $IcfMgmtNetPoolName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network IP pool range")]
      [string] $IcfMgmtNetPoolAddr,

    [Parameter(Mandatory=$false,HelpMessage="Show ICF API responses")]
      [switch] $showResponse = $false
);

$icfAPIUrl  = 'http://' + $IcfHost
$icfAPIPath = '/icfb'
$icfAPIVer  = '/v1'

# Login / Get Token / Start Session
$json = @"
{
    "username":"$IcfAdmin",
    "password":"$IcfAdminPass"
}
"@

Write-Host "Logging into ICF Host"
$icfOp = '/token'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Body $json -ContentType 'application/json' -SessionVariable myIcfSession
if ($showResponse) {$response}

# Show the token and the Session Cookie
if ($showResponse) {
    $response.BaseResponse
    $myIcfSession.Cookies.GetCookies($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp)
}

# Set the token in the header
$headers = @{
    'x_icfb_token' = $response.BaseResponse.Headers.Get('x_icfb_token')
}


# Get the Virtual Accounts
Write-Host "Checking for a VMM Virtual Account"
$icfOp = '/virtual-accounts'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfVmmVaName) {
        Write-Host "Existing VMM Virtual Account Found"
        "VMM Virtual Account Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $IcfVmmVaNameOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Create the VMware Virtual Account
if ($IcfVmmVaNameOid.Length -eq 0) {

Write-Host "No Existing VMM Virtual Account Found, Creating One"

    $json = @"
    {
        "name":"$IcfVmmVaName",
        "description":"",
        "virtual_account_type":"$IcfVmmVaType",
        "server":"$VCenter",
        "port_number":"443",
        "username":"$VcUser",
        "password":"$VcPass",
        "sdk_url":"/sdk"
    }
"@
    if ($showResponse) {$json}
    $icfOp = '/virtual-accounts'
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

    # Get the Virtual Accounts
    $icfOp = '/virtual-accounts'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfVmmVaName) {
            Write-Host "VMM Virtual Account Created"
            "VMM Virtual Account Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
            $IcfVmmVaNameOid = $fromJson.value[$i].properties.oid
            break
        }
    }
}

# Get the Networks
Write-Host "Checking for Exisitng ICF Management Network"
$icfOp = '/networks'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfMgmtNetWorkName) {
        Write-Host "Exisitng ICF Management Network Found"
        "ICF Management Network Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $IcfMgmtNetWorkNameOid = $fromJson.value[$i].properties.oid

        for ($j=0; $j -le $fromJson.value[0].properties.ip_pools.Count; $j++) {
            if ($fromJson.value[$i].properties.ip_pools[$j].name -match $icfMgmtNetPoolName) {
                Write-Host "Exisitng ICF Management Network IP Pool Found"
                "ICF Management IP Pool Name and OID: " + $fromJson.value[$i].properties.ip_pools[$j].name, $fromJson.value[$i].properties.ip_pools[$j].oid
                $IcfMgmtNetPoolNameOid = $fromJson.value[$i].properties.ip_pools[$j].oid
                break
            }
        }
        break
    }
}


# Create the Management Network
if ($IcfMgmtNetWorkNameOid.Length -eq 0) {

Write-Host "Create ICF Management Network"

    $json = @"
    {
        "object_type":"network",
        "name":"$IcfMgmtNetWorkName",
        "segment_id":"1",
        "cidr":"$IcfMgmtNetWorkCidr",
        "enterprise_gateway":"$IcfMgmtNetWorkGate",
        "enterprise_network_partitions":[],
        "is_data_network":false,
        "is_management_network":true,
        "is_l3_connected":true,
        "is_extended":true,
        "is_transport":true,
        "is_dhcp_enabled":false,
        "description":"",
        "ip_pools":[{
            "ip_version":"4",
            "name":"$IcfMgmtNetPoolName",
            "ips_in_pool":"$IcfMgmtNetPoolAddr"
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

        if ($fromJson.value[$i].properties.name -match $IcfMgmtNetWorkName) {
            Write-Host "ICF Management Network Created"
            "ICF Management Network Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
            $IcfHypervisorMgmtPgOid = $fromJson.value[$i].properties.oid

            for ($j=0; $j -le $fromJson.value[0].properties.ip_pools.Count; $j++) {
                if ($fromJson.value[$i].properties.ip_pools[$j].name -match $IcfMgmtNetPoolName) {
                    Write-Host "ICF Management Network IP Pool Created"
                    "ICF Management IP Pool Name and OID: " + $fromJson.value[$i].properties.ip_pools[$j].name, $fromJson.value[$i].properties.ip_pools[$j].oid
                    $IcfMgmtNetPoolNameOid = $fromJson.value[$i].properties.ip_pools[$j].oid
                    break
                }
            }
            break
        }
    }
}

# Get the ICF Infrastructure
Write-Host "Checking for Exisitng ICF Infrastructure"
$icfOp = '/infrastructure'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json
$icfInfraOid = $fromJson.value[0].properties.oid

if ($icfInfraOid.Length -gt 0) {
    Write-Host "ICF Infrastructure Already Exists"
    "Infra OID: " + $icfInfraOid
    $icfInfraExists = $true
}

if ($icfInfraOid.Length -eq 0) {

Write-Host "Creating ICF Infrastucture"
        
    # Get the Hypervisor Hosts
    $icfOp = '/virtual-accounts' + '/' + $IcfVmmVaNameOid + '/compute'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfHypervisorHost) {
            Write-Host "Retrieve ICF Hypervisor Deployment Host OID"
            "Vmm Hypervisor Host Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
            $IcfHypervisorHostOid = $fromJson.value[$i].properties.oid
            break
        }
    }

    # Get the Hypervisor Host Storage
    $icfOp = '/virtual-accounts' + '/' + $IcfVmmVaNameOid + '/storage'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfHypervisorDatastore) {
            Write-Host "Retrieve ICF Hypervisor Deployment Host Datastore OID"
            "Vmm Hypervisor Host Storage Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
            $IcfHypervisorDatastoreOid = $fromJson.value[$i].properties.oid
            break
        }
    }

    # Get the Local Networks
    $icfOp = '/virtual-accounts' + '/' + $IcfVmmVaNameOid + '/networks'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfHypervisorMgmtPg) {
            Write-Host "Retrieve ICF Hypervisor Deployment Port Group OID"
            "Vmm Port Group Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
            $IcfHypervisorMgmtPgOid = $fromJson.value[$i].properties.oid
            break
        }
    }

    # Create the ICF Infrastructure

    Write-Host "Creating ICF Infrastructure"

    $json = @"
    {
        "high_availability":false,
        "ip_pool_oid":"$icfMgmtNetPoolNameOid",
        "name":"Infrastructure-Setup",
        "icf_vsm":{"domain_id":601},
        "placement":{
            "virtual_account_oid":"$IcfVmmVaNameOid",
            "instances":[{
                 "ha_role":"standalone",
                 "compute":{"host_oid":"$IcfHypervisorHostOid"},
                 "network":{"mgmt":{"port_group_oid":"$IcfHypervisorMgmtPgOid"}},
                 "storage":{"datastore_oid":"$IcfHypervisorDatastoreOid"}
             }]
        }
    }
"@

    $icfOp = '/infrastructure'
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
}

if (!$icfInfraExists) {
    Write-Host "ICF Infrstructure Successfully Deployed"
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}