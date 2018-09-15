#get subscription details
Connect-AzureRmAccount 
Select-AzureRMSubscription -SubscriptionName "Microsoft Partner Network"
Select-AzureRMSubscription -SubscriptionID d49acdd3-d25a-451f-8ea6-7d0a2b1c9081

#retreive location available image information

Get-AzureRmVMImage -Location $location -PublisherName "MicrosoftWindowsServer" -Offer "windowsserver" -Skus "2016-Datacenter"

Get-AzureRmComputeResourceSku | where {$_.Locations -icontains "UK West"}