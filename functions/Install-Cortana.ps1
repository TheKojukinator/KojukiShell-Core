Function Install-Cortana {
    <#
    .SYNOPSIS
    Install Cortana.

    .DESCRIPTION
    This function installs the latest Cortana AppXPackage available on this system.

    .EXAMPLE
    Install-Cortana
    #>
    [CmdletBinding()]
    Param()
    Process {
        try {
            # select the latest available Cortana AppXPackage version
            $package = Get-AppXPackage -AllUsers -Name Microsoft.Windows.Cortana | Sort-Object @{e = {[System.Version]$PSItem.Version}} | Select-Object -Last 1
            # if we found a package, try to install it
            if ($package) {
                Write-Information "Install-Cortana : AppXPackage found, trying to install"
                # start a loop for retries
                while ($true) {
                    try {
                        Stop-Process -Name SearchUI -ErrorAction Ignore
                        Add-AppxPackage -DisableDevelopmentMode -Register "$($package.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
                        break
                    } catch {
                        Write-Error $PSitem.Exception
                        Write-Information "Install-Cortana : Error detected, retrying"
                        Start-Sleep -Seconds 1
                    }
                }
            } else {
                # no package was found
                Write-Warning "Install-Cortana : No AppXPackage found for Cortana!"
            }
        } catch {
            if (!$PSitem.InvocationInfo.MyCommand) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        (New-Object "$($PSItem.Exception.GetType().FullName)" (
                                "$($PSCmdlet.MyInvocation.MyCommand.Name) : $($PSItem.Exception.Message)`n`nStackTrace:`n$($PSItem.ScriptStackTrace)`n"
                            )),
                        $PSItem.FullyQualifiedErrorId,
                        $PSItem.CategoryInfo.Category,
                        $PSItem.TargetObject
                    )
                )
            } else { $PSCmdlet.ThrowTerminatingError($PSitem) }
        }
    }
    End {
        try {
            Write-Information "Install-Cortana : Restarting Explorer"
            # restart explorer
            Stop-Process -Name explorer -Force -ErrorAction Ignore
            Start-Sleep -Seconds 1
            if (!(Get-Process | Where-Object ProcessName -EQ "explorer")) {
                # if explorer didnt restart on its own, run it
                & explorer.exe
            }
        } catch {
            if (!$PSitem.InvocationInfo.MyCommand) {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        (New-Object "$($PSItem.Exception.GetType().FullName)" (
                                "$($PSCmdlet.MyInvocation.MyCommand.Name) : $($PSItem.Exception.Message)`n`nStackTrace:`n$($PSItem.ScriptStackTrace)`n"
                            )),
                        $PSItem.FullyQualifiedErrorId,
                        $PSItem.CategoryInfo.Category,
                        $PSItem.TargetObject
                    )
                )
            } else { $PSCmdlet.ThrowTerminatingError($PSitem) }
        }
    }
} # Install-Cortana
