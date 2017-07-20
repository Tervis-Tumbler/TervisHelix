function Get-TervisHelixStationNumbers {
    Get-ADComputer -Filter {Name -like "Helix*"} | foreach {$_.Name.Substring(5,2)}
}

function Install-HelixDowntimeClient {
    param (
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]$ComputerName
    )
    begin {
        $HelixDowntimeRemoteApp = "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\RemoteApp and Desktop Connections\Work Resources\Helix Downtime Client (Work Resources).lnk"
    }
    process {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $UserProfiles = Get-ChildItem -Path C:\Users
            foreach ($UserProfile in $UserProfiles) {
                $HelixDowntimeRemoteAppFullPath = Join-Path -Path $UserProfile.FullName -ChildPath $Using:HelixDowntimeRemoteApp
                Write-Verbose "Looking for $HelixDowntimeRemoteAppFullPath"
                Write-Verbose "Found status: $(Test-Path $HelixDowntimeRemoteAppFullPath)"
                if (Test-Path -Path $HelixDowntimeRemoteAppFullPath) {
                    $RemoteAppSource = $HelixDowntimeRemoteAppFullPath
                    break
                }
            }
            if ($RemoteAppSource) {
                Copy-Item -Path $RemoteAppSource -Destination C:\Users\Public\Desktop -Force 
            } else {
                Write-Warning "No RemoteApps found on $env:COMPUTERNAME"
            }
        }
    }
}
