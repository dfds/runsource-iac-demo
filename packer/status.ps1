Write-Host "`nImages" -Fore Green
Get-EC2Image -Owner self | sort CreationDate | select -last 1 | ft Name, ImageId, CreationDate -AutoSize