<#
.SYNOPSIS
Deploy-IcfOva, deploy the ICF OVA to vCenter
.DESCRIPTION
Deploy-IcfOva, deploy the ICF OVA to vCenter
.NOTES
John McDonough, Cisco Systems, Inc. (jomcdono)


.EXAMPLE
Deploy-IcfOva.ps1 -VCenter 10.10.10.100 -VcUser administrator -VcPass password -EsxHost 10.10.10.101 -EsxData Nexsan-Lun-00 -EsxNetw network -IcfdVmName ICFD-3.1.1 -IcfdHostName icfd-3-1-1 -IcfdPass password -IcfdGuiIP 192.168.250.50 -IcfdWflowIP 192.168.250.51 -IcfdGateway 192.168.250.1
#>
param(
    [Parameter(Mandatory=$true,HelpMessage="Enter a vCenter hostname or IP address")]
      [string] $VCenter,
      
    [Parameter(Mandatory=$true,HelpMessage="Enter vCenter admin")]
      [string] $VcUser,
    
    [Parameter(Mandatory=$true,HelpMessage="Enter vCenter admin's Password")]
      [string] $VcPass,
      
    [Parameter(Mandatory=$false,HelpMessage="Enter an OVF File")]
      [string] $OvfFile = "icf.ovf",

    [Parameter(Mandatory=$true,HelpMessage="Enter an ESX host hostname or IP Address for VM deployment")]
      [string] $EsxHost,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ESX host datastore for VM deployment")]
      [string] $EsxData,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ESX host network for VM deployment")]
      [string] $EsxNetw,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Director VM Name")]
      [string] $IcfdVmName,

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF Director VM Hostname")]
      [string] $IcfdHostName = "cisco-icf",

    [Parameter(Mandatory=$false,HelpMessage="Enter an ICF Director Password")]
      [string] $IcfdPass = "C1sco12345*",

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Director IP Address for the GUI")]
      [string] $IcfdGuiIP,

    [Parameter(Mandatory=$true,HelpMessage="Enter an ICF Director IP Address for the Workflow Engine")]
      [string] $IcfdWflowIP,

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director IP Subnet Mask")]
      [string] $IcfdSubnetMask = "255.255.255.0",

    [Parameter(Mandatory=$true,HelpMessage="Enter the ICF Director IP Gateway")]
      [string] $IcfdGateway,

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Domain Name")]
      [string] $IcfdDomainName = "cisco.com",

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Primary DNS Server")]
      [string] $IcfdDns1 = "8.8.8.8",

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Secondary DNS Server - optional")]
      [string] $IcfdDns2 = "8.8.8.4",

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Primary NTP Server")]
      [string] $IcfdNtp1 = "0.north-america.pool.ntp.org",

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Secondary NTP Server - optional")]
      [string] $IcfdNtp2 = "1.north-america.pool.ntp.org",

    [Parameter(Mandatory=$false,HelpMessage="Enter the ICF Director Syslog Server - optional")]
      [string] $IcfdSyslog = "0.0.0.0",

    [Parameter(Mandatory=$false,HelpMessage="Enter an ESX host network for VM deployment")]
      [string] $IcfdTimezone = "America/Los_Angeles"
);

# Check vCenter Connections
if ($global:DefaultVIServers.Count -ge 1) {Disconnect-ViServer * -Confirm:$false}

# Connect to vCenter
Connect-VIServer -Server $VCenter -User $VcUser -Password $VcPass

if ($global:DefaultVIServers.Count -ne 1) {exit}

try {
        $icfVM = Get-VM -Name $IcfdVmName -ErrorAction stop
    }
    catch {
        Write-Host "ICF VM $IcfdVmName is not yet deployed"
    }
#    finally {
#        Write-Host "ICF VM $IcfdVmName is already deployed"
#    }

if  ($icfVM) {
    Write-Host "ICF VM $IcfdVmName is already deployed"
    exit
}

Write-Host "ICF VM $IcfdVmName starting deployment"

$ovfconf = Get-OvfConfiguration $OvfFile

$vmhost = Get-VmHost -name $EsxHost

$vmdata = $vmhost | Get-Datastore | ?{$_.Name -eq $EsxData}

$vmnetw = Get-VDPortGroup -Name $EsxNetw

$ovfconf.NetworkMapping.VM_Network.Value   = $vmnetw
$ovfconf.Common.HostName.Value             = $IcfdHostName
$ovfconf.Common.Password.Value             = $IcfdPass
$ovfconf.Common.ManagementIpV4.Value       = $IcfdGuiIP
$ovfconf.Common.ICFCManagementIpV4.Value   = $IcfdWflowIP
$ovfconf.Common.ManagementIpV4Subnet.Value = $IcfdSubnetMask
$ovfconf.Common.GatewayIpV4.Value          = $IcfdGateway
$ovfconf.Common.DomainName.Value           = $IcfdDomainName
$ovfconf.Common.DNSIp.Value                = $IcfdDns1
$ovfconf.Common.DNS2Ip.Value               = $IcfdDns2
$ovfconf.Common.SyslogIpStr.Value          = $IcfdSyslog
$ovfconf.Common.NTPIpStr.Value             = $IcfdNtp1
$ovfconf.Common.NTP2IpStr.Value            = $IcfdNtp2
$ovfconf.Common.TimeZoneStr.Value          = $IcfdTimezone

# Deploy the ICF VM
Import-VApp -Source $ovffile -OvfConfiguration $ovfconf -Name $IcfdVmName -VMHost $vmhost -Datastore $vmdata -DiskStorageFormat thin

# Start the ICF VM
Get-VM -Name $IcfdVmName | Start-VM

Disconnect-VIServer -Confirm:$false