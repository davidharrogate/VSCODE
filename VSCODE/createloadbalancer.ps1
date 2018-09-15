#Connect-AzureRmAccount
#Get-AzureRmResource or Get-AzureRmResource | ft

# Variables for common values
$resourceGroup = "myResourceGroup"
$location = "UK West"
#$vmName = "firstVM"
$VNetName = "PowershellVirtualNetwork"
$SubnetName = "default"
$SubnetAddressPrefix = "172.30.1.0/24"
$VnetAddressPrefix = "172.30.0.0/16"
$nsgname = "mysecuritygroup"
$cred = Get-Credential

#create resource group
New-AzureRmResourceGroup -ResourceGroupName $resourceGroup -Location $location

#create public IP address
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name "mypublicdns$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

#create LB front end config
$frontendIP = New-AzureRmLoadBalancerFrontendIpConfig -Name "myFrontEnd" -PublicIpAddress $pip

#create LB backend IP address pool
$backendPool = New-AzureRmLoadBalancerBackendAddressPoolConfig -Name "myBackEndPool"

#create health probe
$probe = New-AzureRmLoadBalancerProbeConfig `
  -Name "myHealthProbe" `
  -RequestPath default.aspx `
  -Protocol http `
  -Port 80 `
  -IntervalInSeconds 16 `
  -ProbeCount 2

#create load balancer rule
 $lbrule = New-AzureRmLoadBalancerRuleConfig `
  -Name "myLoadBalancerRule" `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool `
  -Protocol Tcp `
  -FrontendPort 80 `
  -BackendPort 80 `
  -Probe $probe

#create NAT rules for RDP to each client
$natrule1 = New-AzureRmLoadBalancerInboundNatRuleConfig `
-Name 'myLoadBalancerRDP1' `
-FrontendIpConfiguration $frontendIP `
-Protocol tcp `
-FrontendPort 4221 `
-BackendPort 3389

$natrule2 = New-AzureRmLoadBalancerInboundNatRuleConfig `
-Name 'myLoadBalancerRDP2' `
-FrontendIpConfiguration $frontendIP `
-Protocol tcp `
-FrontendPort 4222 `
-BackendPort 3389

#create load balancer config
$lb = New-AzureRmLoadBalancer `
-ResourceGroupName $resourceGroup `
-Name 'MyLoadBalancer' `
-Location $location `
-FrontendIpConfiguration $frontendIP `
-BackendAddressPool $backendPool `
-Probe $probe `
-LoadBalancingRule $lbrule `
-InboundNatRule $natrule1,$natrule2

#create subnet
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name $SubnetName `
  -AddressPrefix $SubnetAddressPrefix 


#create virtual Network
$vnet = New-AzureRmVirtualNetwork `
  -ResourceGroupName $resourceGroup `
  -Location $location `
  -Name $VNetName `
  -AddressPrefix $VnetAddressPrefix `
  -Subnet $subnetConfig

  $rule1 = New-AzureRmNetworkSecurityRuleConfig `
  -Name 'myNetworkSecurityGroupRuleRDP' `
  -Description 'Allow RDP' `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 1000 `
  -SourceAddressPrefix Internet `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389
  
  $rule2 = New-AzureRmNetworkSecurityRuleConfig `
  -Name 'myNetworkSecurityGroupRuleHTTP' `
  -Description 'Allow HTTP' `
  -Access Allow `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 2000 `
  -SourceAddressPrefix Internet `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80

$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location -Name $nsgname -SecurityRules $rule1,$rule2

# Create NIC for VM1
$nicVM1 = New-AzureRmNetworkInterface `
-ResourceGroupName $resourceGroup `
-Location $location `
-Name 'MyNic1' `
-LoadBalancerBackendAddressPool $backendPool `
-NetworkSecurityGroup $nsg `
-LoadBalancerInboundNatRule $natrule1 `
-Subnet $vnet.Subnets[0]

# Create NIC for VM2
$nicVM2 = New-AzureRmNetworkInterface `
-ResourceGroupName $resourceGroup `
-Location $location `
-Name 'MyNic2' `
-LoadBalancerBackendAddressPool $backendPool `
-NetworkSecurityGroup $nsg `
-LoadBalancerInboundNatRule $natrule2 `
-Subnet $vnet.Subnets[0]

$availabilitySet = New-AzureRmAvailabilitySet `
  -ResourceGroupName $resourceGroup `
  -Name "myAvailabilitySet" `
  -Location $location `
  -Sku aligned `
  -PlatformFaultDomainCount 2 `
  -PlatformUpdateDomainCount 2

  #create 2 vms
for ($i=1; $i -le 2; $i++)
{
    New-AzureRmVm `
        -ResourceGroupName $resourceGroup `
        -Name "myVM$i" `
        -Location $location `
        -VirtualNetworkName $VNetName `
        -SubnetName $SubnetName `
        -SecurityGroupName $nsgname `
        -OpenPorts 80 `
        -AvailabilitySetName "myAvailabilitySet" `
        -Credential $cred `
        -AsJob
}