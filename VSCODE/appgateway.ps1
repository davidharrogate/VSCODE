#set variables
$ResourceGroup = "AppGatewayResourceGroup"
$Location ="UK West"
$AppGWSubnet = "AppGatewaySubnet"
$AppGWBackendSubnet = "AppGatewayBackendSubnet"


#create resource group
New-AzureRmResourceGroup -Name $ResourceGroup -Location $Location

#Network Resources
$backendSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name $AppGWSubnet `
  -AddressPrefix 10.0.1.0/24

$agSubnetConfig = New-AzureRmVirtualNetworkSubnetConfig `
  -Name $AppGWBackendSubnet `
  -AddressPrefix 10.0.2.0/24

New-AzureRmVirtualNetwork `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name myVNet `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $backendSubnetConfig, $agSubnetConfig

New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -Name myAGPublicIPAddress `
  -AllocationMethod Dynamic

#create 2 virtual backend servers
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name myVNet
$cred = Get-Credential
for ($i=1; $i -le 2; $i++)
{
  $nic = New-AzureRmNetworkInterface `
    -Name myNic$i `
    -ResourceGroupName $ResourceGroup `
    -Location $Location `
    -SubnetId $vnet.Subnets[1].Id
  $vm = New-AzureRmVMConfig `
    -VMName myVM$i `
    -VMSize Standard_DS2
  $vm = Set-AzureRmVMOperatingSystem `
    -VM $vm `
    -Windows `
    -ComputerName myVM$i `
    -Credential $cred
  $vm = Set-AzureRmVMSourceImage `
    -VM $vm `
    -PublisherName MicrosoftWindowsServer `
    -Offer WindowsServer `
    -Skus 2016-Datacenter `
    -Version latest
  $vm = Add-AzureRmVMNetworkInterface `
    -VM $vm `
    -Id $nic.Id
  $vm = Set-AzureRmVMBootDiagnostics `
    -VM $vm `
    -Disable
  New-AzureRmVM -ResourceGroupName $ResourceGroup -Location $Location -VM $vm
  Set-AzureRmVMExtension `
    -ResourceGroupName $ResourceGroup `
    -ExtensionName IIS `
    -VMName myVM$i `
    -Publisher Microsoft.Compute `
    -ExtensionType CustomScriptExtension `
    -TypeHandlerVersion 1.4 `
    -SettingString '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}' `
    -Location $Location
}


#Create the IP configurations and frontend port
$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $ResourceGroup -Name myVNet
$pip = Get-AzureRmPublicIPAddress -ResourceGroupName $ResourceGroup -Name myAGPublicIPAddress 
$subnet=$vnet.Subnets[0]
$gipconfig = New-AzureRmApplicationGatewayIPConfiguration `
  -Name myAGIPConfig `
  -Subnet $subnet
$fipconfig = New-AzureRmApplicationGatewayFrontendIPConfig `
  -Name myAGFrontendIPConfig `
  -PublicIPAddress $pip
$frontendport = New-AzureRmApplicationGatewayFrontendPort `
  -Name myFrontendPort `
  -Port 80


#Create the backend pool
$address1 = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroup -Name myNic1
$address2 = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroup -Name myNic2
$backendPool = New-AzureRmApplicationGatewayBackendAddressPool `
  -Name myAGBackendPool `
  -BackendIPAddresses $address1.ipconfigurations[0].privateipaddress, $address2.ipconfigurations[0].privateipaddress
$poolSettings = New-AzureRmApplicationGatewayBackendHttpSettings `
  -Name myPoolSettings `
  -Port 80 `
  -Protocol Http `
  -CookieBasedAffinity Enabled `
  -RequestTimeout 120

#Create the listener and add a rule
$defaultlistener = New-AzureRmApplicationGatewayHttpListener `
  -Name myAGListener `
  -Protocol Http `
  -FrontendIPConfiguration $fipconfig `
  -FrontendPort $frontendport
$frontendRule = New-AzureRmApplicationGatewayRequestRoutingRule `
  -Name rule1 `
  -RuleType Basic `
  -HttpListener $defaultlistener `
  -BackendAddressPool $backendPool `
  -BackendHttpSettings $poolSettings

#Create the application gateway
$sku = New-AzureRmApplicationGatewaySku `
  -Name Standard_Medium `
  -Tier Standard `
  -Capacity 2
New-AzureRmApplicationGateway `
  -Name myAppGateway `
  -ResourceGroupName $ResourceGroup `
  -Location $Location `
  -BackendAddressPools $backendPool `
  -BackendHttpSettingsCollection $poolSettings `
  -FrontendIpConfigurations $fipconfig `
  -GatewayIpConfigurations $gipconfig `
  -FrontendPorts $frontendport `
  -HttpListeners $defaultlistener `
  -RequestRoutingRules $frontendRule `
  -Sku $sku


#Test the application gateway
#Get-AzureRmPublicIPAddress -ResourceGroupName $ResourceGroup -Name myAGPublicIPAddress
