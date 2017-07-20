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
        $HelixDowntimeClient = "\\tervis.prv\departments\Departments - I Drive\Shared\Operations\Chad\Helix\Helix Downtime Client.accdb"
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
