Write-Host "`nVirtual Private Cloud" -Fore Green
Get-EC2Vpc | select @{N='Name';E={($_.Tags | ? {$_.Key -eq 'Name'}).Value}}, VpcId, CidrBlock | ? {$_.Name -eq 'iac-demo'} | Out-Host

Write-Host "`nSubnets" -Fore Green
Get-EC2Subnet | select *, @{N='Name';E={($_.Tags | ? {$_.Key -eq 'Name'}).Value}} | ? {$_.Name -eq 'iac-demo'} | ft AvailabilityZone, CidrBlock | Out-Host

Write-Host "`nVirtual Machines" -Fore Green
Get-EC2Instance -Filter @{name='tag:Name';values="iac*"}, @{name="instance-state-name";values="running"} | select -Expand Instances | ft @{N = 'Name'; E = { ($_.Tags | ? { $_.Key -eq 'Name' }).Value } }, LaunchTime, Platform, InstanceType, PublicIpAddress | Out-Host