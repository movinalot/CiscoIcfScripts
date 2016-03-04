<#
.SYNOPSIS
Build-IcfInfra, Build ICF Infrastructure
.DESCRIPTION
Build-IcfInfra, Build ICF Infrastructure
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Build-IcfInfra.ps1 -IcfHost 173.36.252.127 -IcfAdmin admin -IcfAdminPass "C1sco12345*" -IcfVmmVaName vcenter -IcfVmmVaType vmware -IcfHypervisorHost 173.36.252.38 -IcfHypervisorDatastore Nexsan-Lun-00 -IcfHypervisorMgmtPg icf-mgmt -IcfMgmtNetWorkName mgmt -IcfMgmtNetWorkCidr "173.36.252.0/24" -IcfMgmtNetWorkGate 173.36.252.1 -IcfMgmtNetPoolName infra -IcfMgmtNetPoolAddr "173.36.252.129-173.36.252.134"
#>
param(
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

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Cloud Link Name")]
      [string] $IcfCloudLink,

    [Parameter(Mandatory=$true,HelpMessage="Enter a Hypervisor host on which to deploy ICF Infrastucture")]
      [string] $IcfHypervisorHost,

    [Parameter(Mandatory=$true,HelpMessage="Enter a Hypervisor host datastore on which to deploy ICF Infrastructure")]
      [string] $IcfHypervisorDatastore,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Hypervisor Management Port Group")]
      [string] $IcfHypervisorMgmtPg,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Hypervisor Trunk Port Group")]
      [string] $IcfHypervisorTrunkPg,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network name")]
      [string] $IcfMgmtNetWorkName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Management network IP pool name")]
      [string] $IcfMgmtNetPoolName,

    [Parameter(Mandatory=$true,HelpMessage="Enter the cloud security group")]
      [string] $CloudSecurityGroup,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider")]
      [string] $CloudProvider,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Type")]
      [string] $CloudProviderTyp,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Style")]
      [string] $CloudProviderSty,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Location")]
      [string] $CloudProviderLoc,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Location VPC name")]
      [string] $CloudProviderVpc,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Location VPC Subnet")]
      [string] $CloudProviderSub,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Access Key")]
      [string] $CloudProviderKey,

    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provider Access ID")]
      [string] $CloudProviderAID,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter the Cloud Provier MAC Pool")]
      [string] $CloudProviderMAC,

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

Write-Host "Logging into ICF Host"
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

# Get the Virtual Accounts
Write-Host "Checking for a Cloud Provider Virtual Account"
$icfOp = '/virtual-accounts'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $cloudProvider) {
        Write-Host "Existing Cloud Provider Virtual Account Found"
        "Cloud Provider Virtual Account Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $cloudProviderVAOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Create Cloud Provider Virtual Account if it does not already exist.
if ($cloudProviderVAOid.Length -eq 0) {

    Write-Host "No Existing CLoud Provider Virtual Account Found, Creating One"

    $icfOp = '/virtual-accounts'
    $json = @"
    {  
       "virtual_account_type":"$cloudProviderTyp",
       "name":"$cloudProvider",
       "description":"",
       "access_id":"$cloudProviderAID",
       "access_key":"$cloudProviderKey"
    }
"@
    # Wait for the Service Request to complete, check every 30 seconds
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

# Get the Virtual Accounts
$icfOp = '/virtual-accounts'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $cloudProvider) {
        Write-Host "Cloud Provider Virtual Account Created"
        "Cloud Provider Virtual Account Name OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $cloudProviderOid = $fromJson.value[$i].properties.oid
        break
    }
}
for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfVmmVaName) {
        "VMM Provider Virtual Account OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $IcfVmmVaNameOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Get the virtual account location, vpc and subnet OIDs
$icfOp = '/virtual-accounts' + '/' + $cloudProviderOid + '/locations'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $cloudProviderLoc) {
        "Cloud Provider Location and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $cloudProviderLocOid = $fromJson.value[$i].properties.oid

        for ($j=0; $j -le $fromJson.value[$i].properties.provider_vpcs.Count; $j++) {

            if ($showResponse) {
                $fromJson.value[$i].properties.provider_vpcs[$j].name
                $fromJson.value[$i].properties.provider_vpcs[$j].oid
                $fromJson.value[$i].properties.provider_vpcs[$j].subnets
            }

            if ($fromJson.value[$i].properties.provider_vpcs[$j].name -match $cloudProviderVpc) {
                "Cloud Provider Location VPC Name and OID: " + $fromJson.value[$i].properties.provider_vpcs[$j].name, $fromJson.value[$i].properties.provider_vpcs[$j].oid
                $cloudProviderVpcOid = $fromJson.value[$i].properties.provider_vpcs[$j].oid

                if ($showResponse) {
                    $fromJson.value[$i].properties.provider_vpcs[$j].subnets
                }
            
                for ($k=0; $k -le $fromJson.value[$i].properties.provider_vpcs[$j].subnets.Count; $k++) {
                    if ($fromJson.value[$i].properties.provider_vpcs[$j].subnets[$k].name -match $cloudProviderSub) {
                        "Cloud Provider Location VPC Subnet Name and OID: " + $fromJson.value[$i].properties.provider_vpcs[$j].subnets[$k].name, $fromJson.value[$i].properties.provider_vpcs[$j].subnets[$k].oid
                        $cloudProviderSubOid = $fromJson.value[$i].properties.provider_vpcs[$j].subnets[$k].oid
                        break
                    }
                }
            }
        }
        break
    }
}


# Get the MAC Pools
Write-Host "Check for Existing Cloud Provider MAC Pool"
$icfOp = '/mac-pools'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $cloudProvider) {
        Write-Host "Existing Cloud Provider MAC Pool Found"
        "Cloud Provider MAC Pool Name and OID: " + $fromJson.value[$i].properties.name, $fromjson.value[$i].properties.oid
        $macPoolOid = $fromjson.value[$i].properties.oid
        break
    }
}

# Create a MAC Pool
if ($macPoolOid.Length -eq 0) {

    Write-Host "Creating Cloud Provider MAC Pool"

    $icfOp = '/mac-pools'
    $json = @"
{
    "name":"$cloudProvider",
    "object_type":"mac-pool",
    "start_mac_address":"$cloudProviderMAC",
    "num_addresses":1000,
    "description":"ICF MAC POOL"
}
"@

    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    # Get the MAC Pools
    $icfOp = '/mac-pools'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $cloudProvider) {
            Write-Host "Created Cloud Provider MAC Pool"
            "Cloud Provider MAC Pool Name and OID: " + $fromJson.value[$i].properties.name, $fromjson.value[$i].properties.oid
            $macPoolOid = $fromjson.value[$i].properties.oid
            break
        }
    }
}

# Get the Cloud Security Groups
Write-Host "Check for Existing Cloud Security Group"

$icfOp = '/cloud-security-groups'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $CloudSecurityGroup) {
        "Cloud Security Group Name and OID: " + $fromJson.value[$i].properties.name, $fromjson.value[$i].properties.oid
        $CloudSecurityGroupOid = $fromjson.value[$i].properties.oid
        break
    }
}



# Get the ICF Clouds
Write-Host "Check for Existing ICF Cloud"
$icfOp = '/icf-clouds'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $cloudProviderLoc) {
        Write-Host "Existing ICF Cloud Found"
        "ICF Cloud Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $icfCloudOid = $fromJson.value[$i].properties.oid
        break
    }
}

if ($icfCloudOid.Length -eq 0) {
    # Create the ICF Cloud
    Write-Host "Create ICF Cloud"

    $json = @"
    {
        "name":"$CloudProviderLoc",
        "virtual_account_oid":"$CloudProviderOid",
        "description":"",
        "location":"$CloudProviderLoc",
        "cloud_style":"$CloudProviderSty",
        "provider_vpc":{
            "vpc_oid":"$CloudProviderVpcOid",
            "primary_subnet_oid":"$CloudProviderSubOid"},
        "policies":{
            "mac_pool_oid":"$macPoolOid",
            "cloud_security_group_oid":"$CloudSecurityGroupOid"},
        "high_availability":"false",
        "service_configuration":{
            "enable_integrated_router":"true"},
        "icf_cloud_type":"$CloudProviderTyp"
    }
"@

    $icfOp = '/icf-clouds'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    $icfOp = '/icf-clouds'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    Start-Sleep -Seconds 60

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $cloudProviderLoc) {
            Write-Host "Created ICF Cloud"
            "ICF Cloud Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
            $icfCloudOid = $fromJson.value[$i].properties.oid
            break
        }
    }

}

# Get the VMM ICF Cloud
Write-Host "Retrive the VMM ICF Cloud"
$icfOp = '/icf-clouds'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfVmmVaType) {
        "VMM Cloud Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $vmwareCloudOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Create the ICF Cloud Link
# Get the Hosts
$icfOp = '/virtual-accounts' + '/' + $IcfVmmVaNameOid + '/compute'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfHypervisorHost) {
        "Hypervisor Host Name and OID: " + $fromJson.value[$i].properties.name, $fromJson.value[$i].properties.oid
        $vmwareHostOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Get the Storage
$icfOp = '/virtual-accounts' + '/' + $IcfVmmVaNameOid + '/storage'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfHypervisorDatastore) {
        "Hypervisor Host Storage Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $vmwareStorageOid = $fromJson.value[$i].properties.oid
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
        "VMM Management Port Group Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $vmwareMgmtPortGroupOid = $fromJson.value[$i].properties.oid
        break
    }
}
for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfHypervisorTrunkPg) {
        "VMM Trunk Port Group Name and OID: " + $fromJson.value[$i].properties.name + " " + $fromJson.value[$i].properties.oid
        $vmwareTrunkPortGroupOid = $fromJson.value[$i].properties.oid
        break
    }
}

# Get the IP Pool
$icfOp = '/networks'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json
$ipPoolOid = $fromJson.value[0].properties.ip_pools.oid
"IP Pool Oid: " + $ipPoolOid


# Get the ICF Cloud Links
Write-Host "Check for Existing ICF Cloud Link"
$icfOp = '/icf-links'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
if ($showResponse) {$response}
$fromJson = $response.Content | ConvertFrom-Json

for ($i=0; $i -le $fromJson.value.Count; $i++) {

    if ($fromJson.value[$i].properties.name -match $IcfCloudLink) {
        Write-Host "Existing ICF Cloud Link Found"
        "ICF Cloud Link Name and OID: " + $fromjson.value[$i].properties.name, $fromjson.value[$i].properties.oid
        $IcfCloudLinkOid = $fromjson.value[$i].properties.oid
        break
    }
}

# Create the IcfLink
if ($IcfCloudLinkOid.Length -eq 0) {

    $json = @"
    {  
         "name":"$IcfCloudLink",
         "description":"",
         "icf_link_configuration":{"tunnel_parameters":{"protocol":"UDP","use_https":"false"}},
         "cloud1":{"icf_cloud_oid":"$vmwareCloudOid",
             "agent_configuration":{"agent_type":"icx",
                 "ip_configuration":{"mgmt":{"ip_pool_oid":"$ipPoolOid"}},
             "placement":{  
                 "instances":[{"ha_role":"standalone",
                     "compute":{"host_oid":"$vmwareHostOid"},
                     "storage":{"datastore_oid":"$vmwareStorageOid"},
                     "network":{
                         "mgmt":{"port_group_oid":"$vmwareMgmtPortGroupOid"},
                         "trunk":{"port_group_oid":"$vmwareTrunkPortGroupOid"}
                     }
                 }]
             }
         }
    },
        "cloud2":{  
            "icf_cloud_oid":"$icfCloudOid",
                "agent_configuration":{  
                    "agent_type":"ics",
                    "ip_configuration":{  
                        "mgmt":{"ip_pool_oid":"$ipPoolOid"
                    }
                }
            }
        }
    }
"@


    # Create the IcfLink
    $icfOp = '/icf-links'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -Body $json -ContentType 'application/json' -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json
    $icfSR = $fromJson.success.links.service_request

    # Query the SR checking status. Timeout after 60 mins
    $SrStatus = ''
    $timeout = new-timespan -Minutes 60
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

    $icfOp = '/icf-links'
    $response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Get -Headers $headers -WebSession $myIcfSession
    if ($showResponse) {$response}
    $fromJson = $response.Content | ConvertFrom-Json

    for ($i=0; $i -le $fromJson.value.Count; $i++) {

        if ($fromJson.value[$i].properties.name -match $IcfCloudLink) {
            Write-Host "Created ICF Cloud Link"
            "ICF Cloud Link Name and OID: " + $fromjson.value[$i].properties.name, $fromjson.value[$i].properties.oid
            $IcfCloudLinkOid = $fromjson.value[$i].properties.oid
            break
        }
    }
}

# Logout
$icfOp = '/logout'
$response = Invoke-WebRequest $($icfAPIUrl+$icfAPIPath+$icfAPIVer+$icfOp) -Method Post -Headers $headers -ContentType 'application/json' -WebSession $myIcfSession
if ($showResponse) {$response}