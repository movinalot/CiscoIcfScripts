# This is just a script to run the scripts, place it in the directory where the ICF OVA has been
# extracted to the .ovf and .vmdk components. All the other scripts reside in the directory above
# where where this script is.

# Edit the variables below for your environment, this script currently supports AWS. Modifications
# to the supportign scripts may be needed to support other providers.  Additionally modifications
# may be needed in the supporting scripts as new capabilities are added to ICF.

# For some of the scripts not all the parameters are specified on the command line.  For example
# Deploy-IcfOva.ps1 has several parameters that are not madatory, there are several defaults specifed
# for the parameters in the .ps1 file itself. For example, in the Deploy-IcfOva.ps1 two DNS servers
# are defined 8.8.8.8 and 8.8.8.4. These values can be overridden with parameters on the commandline


# The cloud credentials are needed to connect to the cloud, for AWS created file called
# CloudCreds.json in the directory where all the scripts are, use the following format.
#
# {"AWSAccessKey": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx","AWSAccessID": "xxxxxxxxxxxxxxxxxxxx"}

$CloudCreds = Get-Content ..\CloudCreds.json | ConvertFrom-Json -Verbose
#Write-Host "AWS Access Key: " $CloudCreds.AWSAccessKey
#Write-Host "AWS Access ID:  " $CloudCreds.AWSAccessID

# VMWare Vars
$VCHost = "10.10.10.10"        # vCenter Server
$VCUser = "administrator"      # vCenter Admin
$VCPass = "Nbv12345"           # vCenter Admin Password
$ESXHost = "10.10.10.20"       # ESX Host to deploy ICF on
$ESXData = "Nexsan-Lun-00"     # ESX Host Storage
$ESXMgPg = "icf-mgmt"          # vSwtich/DVS Management Port Group
$ICFVmmVaName = "vcenter"      # ICF Virtual Account Name for virtual machine manager account
$ICFVmmVaType = "vmware"       # ICF Virtual Account Type for virtual machine manager account

# ICF Director Vars
$ICFHost = "icfd-3-1-1"         # ICFD Hostname
$ICFName = "ICFD-3.1.1"         # ICFD VM Name
$ICFIP1 = "10.10.10.21"         # ICFD Management IP
$ICFIP2 = "10.10.10.22"         # ICFD Internal IP
$ICFMgNet = "mgmt"              # ICFD Management Network Name
$ICFMgPool = "infra"            # ICFD Management Network Pool Name
$ICFMgPoolIP = "10.10.10.23-10.10.10.26" # ICFD Namagemnet Network Pool
$ICFTrunkPg = "icf-icxtrunk"    # ICFD ICX Trunk Port Group
$ICFMgmtPg = "icf-mgmt"         # ICFD vSwitch/DVS Management Port Group

$ICFGroup = "icf-group"         # ICFD User Group
$ICFUser = "icf-user"           # ICFD User
$ICFUserPass = "icf-pass"       # ICFD User Pass

$ICFCIDR = "10.10.10.0/24"      # ICFD Management Network CIDR and Subnet
$ICFGW = "10.10.10.1"           # ICFD Management Network Gateway
$ICFAdmin = "admin"             # ICFD Admin User
$ICFPass = "C1sco12345*"        # ICFD Admin User Pass

$ICFCloudLink = "icf-link-01"             # ICFD Cloud Link Name
$CloudProvider = "AWS"                    # Cloud Provider
$CloudProviderTyp = "aws-ec2"             # Cloud Provider Type
$CloudProviderSty = "vpc"                 # Cloud Provider Style
$CloudProviderLoc = "us-west-2"           # Cloud Provider Location
$CloudProviderVpc = "icf-vpc"             # Cloud Provider VPC Name
$CloudProviderSub = "icf-vpc-sub"         # Cloud Provider VPC Subnet
$CloudProviderMAC = "00:0e:08:ee:00:00"   # ICFD Cloud VM MAC Pool
$CloudSecurityGroup = "system_default"    # ICFD Security Group
$ICFImageName = "centos63min"             # ICFD VM Image Name
$ICFImagePath = "/root/centos-6.3.ova"    # ICFD VM Image Path
$ICFImageHost = "10.10.10.30   "          # ICFD VM Image host
$ICFImageHostUser = "root"                # ICFD VM Image host user
$ICFImageHostUserPass = "Sfish123!"       # ICFD VM Image host user pass
$ICFDataNetworkName = "icf-web"           # ICFD VM Data Network Name
$ICFDataNetPoolName = "icf-web"           # ICFD VM Data Netowrk Pool Name
$ICFDataNetworkCidr = "192.168.73.0/24"   # ICFD VM Data Network CIDR and Subnet
$ICFDataNetWorkGate = "192.168.73.1"      # ICFD VM Data Network Gateway
$ICFDataNetPoolAddr = "192.168.73.101-192.168.73.150" # ICFD VM Data Network IP Pool
$ICFVdcName = "icf-vdc-01"                # ICFD VM VDC Name 
$ICFCatalogName = "CentOS63-us-west-2-01" # ICFD VM Image Catalog Name


# Deploy ICF OVA
..\Deploy-IcfOva.ps1 -VCenter $VCHost -VcUser $VCUser -VcPass $VCPass -EsxHost $ESXHost `
  -EsxData $ESXData -EsxNetw $ICFMgmtPg -IcfdVmName $ICFName -IcfdHostName $ICFHost `
  -IcfdPass $ICFPass -IcfdGuiIP $ICFIP1 -IcfdWflowIP $ICFIP2 -IcfdGateway $ICFGW

# Check for the availability of ICF API
..\Check-IcfApi.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass

# Continue the delpoyment if ICF by deploying the ICF Infrastructure
..\Build-IcfInfra.ps1 -VCenter $VCHost -VcUser $VCUser -VcPass $VCPass -IcfHost $ICFIP1 `
  -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfVmmVaName $ICFVmmVaName -IcfVmmVaType $ICFVmmVaType -IcfHypervisorHost $ESXHost `
  -IcfHypervisorDatastore $ESXData -IcfHypervisorMgmtPg $ICFMgmtPg -IcfMgmtNetWorkName $ICFMgNet `
  -IcfMgmtNetWorkCidr $ICFCIDR -IcfMgmtNetWorkGate $ICFGW -IcfMgmtNetPoolName $ICFMgPool `
  -IcfMgmtNetPoolAddr $ICFMgPoolIP

# Add an ICF User Group
..\Add-IcfUserGroup.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfGroup $ICFGroup

# Add an ICF User
..\Add-IcfUser.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfUser $ICFUser -IcfUserPass $ICFUserPass -IcfGroup $ICFGroup


# Create an ICF Cloud Provider and ICF Cloud and Cloud Link
..\Create-IcfCloud.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfVmmVaName $ICFVmmVaName -IcfVmmVaType $ICFVmmVaType `
  -IcfCloudLink $ICFCloudLink -IcfHypervisorHost $ESXHost -IcfHypervisorDatastore $ESXData -IcfHypervisorMgmtPg $ICFMgmtPg `
  -IcfHypervisorTrunkPg $ICFTrunkPg -IcfMgmtNetWorkName $ICFMgNet -IcfMgmtNetPoolName $ICFMgPool -CloudSecurityGroup $CloudSecurityGroup `
  -CloudProvider $CloudProvider -CloudProviderTyp $CloudProviderTyp -CloudProviderSty $CloudProviderSty -CloudProviderLoc $CloudProviderLoc `
  -CloudProviderVpc $CloudProviderVpc -CloudProviderSub $CloudProviderSub  -CloudProviderMAC $CloudProviderMAC `
  -CloudProviderKey $CloudCreds.AWSAccessKey -CloudProviderAID $CloudCreds.AWSAccessID
 

# Upload an Image to ICF
..\Upload-IcfImage.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass `
  -IcfImageName $ICFImageName -IcfImagePath $ICFImagePath -IcfImageHost $ICFImageHost `
  -IcfImageHostUser $ICFImageHostUser -IcfImageHostUserPass $ICFImageHostUserPass

# Create a ICF Data Network
..\Add-IcfNetwork.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass `
  -IcfDataNetWorkName $ICFDataNetworkName -IcfDataNetWorkCidr $ICFDataNetworkCidr -IcfDataNetWorkGate $ICFDataNetWorkGate `
  -IcfDataNetPoolName $ICFDataNetPoolName -IcfDataNetPoolAddr $ICFDataNetPoolAddr -showResponse
Start-Sleep -Seconds 60

# Create an ICF VDC
..\Create-IcfCloudVdc.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfVdcName $ICFVdcName -IcfUserGroup $ICFGroup -IcfCloud $CloudProviderLoc
Start-Sleep -Seconds 60

# Create an ICF Catalog Item
..\Create-IcfCatalog.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass `
  -IcfCatalogName $ICFCatalogName -IcfImageName $ICFImageName -IcfUserGroup $ICFGroup -IcfCloud $CloudProviderLoc

# Create a VM
..\Create-IcfVM.ps1 -IcfHost $ICFIP1 -IcfAdmin $ICFAdmin -IcfAdminPass $ICFPass -IcfCatalogName $ICFCatalogName -IcfVdcName $ICFVdcName -IcfDataNetwork $ICFDataNetworkName
