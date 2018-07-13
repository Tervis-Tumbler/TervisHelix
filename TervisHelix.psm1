function Get-TervisHelixStationNumbers {
    Get-ADComputer -Filter {Name -like "Helix*"} | foreach {$_.Name.Substring(5,2)}
}

#function Install-HelixDowntimeClient {
#    param (
#        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
#    )
#    begin {
#        $HelixDowntimeRemoteApp = "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\RemoteApp and Desktop Connections\Work Resources\Helix Downtime Client (Work Resources).lnk"
#    }
#    process {
#        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
#            $UserProfiles = Get-ChildItem -Path C:\Users
#            foreach ($UserProfile in $UserProfiles) {
#                $HelixDowntimeRemoteAppFullPath = Join-Path -Path $UserProfile.FullName -ChildPath $Using:HelixDowntimeRemoteApp
#                Write-Verbose "Looking for $HelixDowntimeRemoteAppFullPath"
#                Write-Verbose "Found status: $(Test-Path $HelixDowntimeRemoteAppFullPath)"
#                if (Test-Path -Path $HelixDowntimeRemoteAppFullPath) {
#                    $RemoteAppSource = $HelixDowntimeRemoteAppFullPath
#                    break
#                }
#            }
#            if ($RemoteAppSource) {
#                Copy-Item -Path $RemoteAppSource -Destination C:\Users\Public\Desktop -Force 
#            } else {
#                Write-Warning "No RemoteApps found on $env:COMPUTERNAME"
#            }
#        }
#    }
#}

function Install-HelixDowntimeClient {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $DomainName = (Get-ADDomain).DNSRoot
        $HelixDowntimeClient = "\\$DomainName\departments\Departments - I Drive\Shared\Operations\Chad\Helix\Helix Downtime Client.accdb"
    }
    process {
        Set-Shortcut -LinkPath "\\$ComputerName\C$\Users\Public\Desktop\Helix Downtime Client.lnk" -TargetPath $HelixDowntimeClient
    }
}

function Remove-HelixDowntimeClientWorkResourcesAllStations {
    $IDs = Get-TervisHelixStationNumbers
    foreach ($ID in $IDs) {
        Remove-Item -Path "\\helix$ID-pc\C$\Users\Public\Desktop\Helix Downtime Client (Work Resources).lnk" -Force -Verbose
    }
}


function Invoke-CommandOnHelixStations {
    param (
        [scriptblock]$Scriptblock
    )

    $HelixComputers = Get-ADComputer -Filter {Name -like "Helix*"} | select -ExpandProperty Name

    Start-ParallelWork -Parameters $HelixComputers -OptionalParameters $Scriptblock -ScriptBlock {
        param ($Parameter,$OptionalParameters)
        $Scriptblock = [scriptblock]::Create($OptionalParameters)
        Invoke-Command -ComputerName $Parameter -ScriptBlock $Scriptblock
    }
}

# Only useful for Stations 01 - 12 currently until Get-HelixAutoLogonCredential is updated.
function New-HelixUser {
    param (
        [Parameter(Mandatory,ValueFromPipeline)][int]$StationID
    )
    begin {
        $HelixUserNameBase = "Helix"
        $DomainName = (Get-ADDomain).DNSRoot.Split(".")
        $OU = "OU=Users,OU=Helix,OU=IndustryPCs,DC=$($DomainName[0]),DC=$($DomainName[1])"
    }
    process {
        $StationIDString = $StationID.ToString().PadLeft(2,"0")
        $HelixUserCredential = Get-HelixAutoLogonCredential -ComputerName ("Helix" + $StationIDString + "-PC")
        $HelixUserName = $HelixUserNameBase + $StationIDString
        $HelixADUser =
            New-ADUser `
            -AccountPassword $HelixUserCredential.Password `
            -CannotChangePassword $true `
            -Enabled $true `
            -SamAccountName $HelixUserName `
            -PasswordNeverExpires $true `
            -Name $HelixUserName `
            -Path $OU `
            -PassThru
    }
}

function Set-HelixAutoLogonGPO {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)][string]$ComputerName
    )
    process {
        $HelixAutoLogonGPO = Get-GPO -Name "Autologon - $($ComputerName.Substring(0,7))"
        $HelixAutoLogonCredential = Get-HelixAutoLogonCredential -ComputerName $ComputerName
        $GPODefaultValues = @{
            Name = $HelixAutoLogonGPO.DisplayName
            Context = "Computer"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            Type = "String"
            Action = "Replace"
        }
        Write-Verbose "Setting AutoLogon GPO for $ComputerName"
        Set-GPPrefRegistryValue @GPODefaultValues -ValueName AutoAdminLogon -Value 1 -Order 1 | Out-Null
        Set-GPPrefRegistryValue @GPODefaultValues -ValueName DefaultUserName -Value $HelixAutoLogonCredential.Username -Order 2 | Out-Null
        Set-GPPrefRegistryValue @GPODefaultValues -ValueName DefaultPassword -Value $HelixAutoLogonCredential.GetNetworkCredential().Password -Order 3 | Out-Null
    }
}

# Only applicable to Helix 01 - 12 until Get-HelixAutoLogonCredential is updated
function Get-HelixAutoLogonCredential {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $PIDZero = 4898
    }
    process {
        $StationID = $ComputerName.Substring(5,2)
        $IDInt = [int]::Parse($StationID)
        if (($IDInt -lt 1) -or ($IDInt -gt 12)) {
            throw "Get-HelixAutoLogonCredential does not yet support getting credentials for stations numbers greater than 12"
        }
        $PasswordID = $PIDZero + $IDInt
        Get-PasswordstatePassword -AsCredential -ID $PasswordID
    }
}

function Get-HelixAutologonStatus {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    process {
        $AutoAdminLogon = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name AutoAdminLogon -Verbose | 
                select -ExpandProperty AutoAdminLogon
        }
        [PSCustomObject][Ordered]@{
            ComputerName = $ComputerName
            AutologonEnabled = ConvertTo-Boolean -value $AutoAdminLogon
        }
    }
}

function Get-HelixComputers {
    Get-ADComputer -Filter {Name -like "Helix*"} |
        Add-Member -MemberType AliasProperty -Name ComputerName -Value Name -Force -PassThru
}
