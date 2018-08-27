Function Uninstall-Cortana {
    <#
    .SYNOPSIS
    Uninstall Cortana.

    .DESCRIPTION
    This function uninstalls Cortana from current or all user profiles.

    .PARAMETER AllUsers
    Process all user profiles. Default is current user profile.

    .EXAMPLE
    Uninstall-Cortana

    .EXAMPLE
    Uninstall-Cortana -AllUsers -Verbose
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [switch] $AllUsers
    )
    Process {
        try {
            # if processing all users, get profiles from SystemDrive\Users, otherwise process only USERPROFILE
            if ($AllUsers) {
                $profiles = Get-ChildItem "$($env:SystemDrive)\Users" -Directory -Force | Select-Object -ExpandProperty FullName
            } else {
                $profiles = Get-Item $env:USERPROFILE | Select-Object -ExpandProperty FullName
            }
            # process the profile(s)
            foreach ($prof in $profiles) {
                Write-Information "Uninstall-Cortana : Processing [$prof]"
                # define the path to Cortana for this profile
                $path = "$prof\AppData\Local\Packages\Microsoft.Windows.Cortana_cw5n1h2txyewy"
                # if the path exists, process it
                if (Test-Path $path -ErrorAction Ignore) {
                    Write-Information "Uninstall-Cortana : Deleting [$item]"
                    # start a loop for retries
                    while ($true) {
                        # attempt to delete the path
                        try {
                            Remove-Item $path -Recurse -Force -ErrorAction Stop
                            break
                        } catch [System.IO.IOException] {
                            # an IOException is highly likely to happen because a file is in use, handle that here
                            # get the locked file path from the exception
                            $badPath = $PSItem.TargetObject.FullName
                            Write-Information "Uninstall-Cortana : IOException deleting [$badPath]"
                            Write-Information "Uninstall-Cortana : Attempting to identify the locking process and stop it"
                            # get the process(es) locking the file
                            $lockedProcs = Get-LockingProcs $badPath -WarningAction SilentlyContinue
                            # quit each process
                            foreach ($proc in $lockedProcs) {
                                Write-Information "Uninstall-Cortana : Stopping process [$($proc.PID), $($proc.Name)] which is locking [$badPath]"
                                # use taskkill.exe instead of Stop-Process, to prevent process restarts
                                & "$env:SystemRoot\System32\taskkill.exe" /f /IM $proc.FullName *> $null
                                # sleep for 1 second, sometimes hadles stay open for a short while and re-trigger this process lock on the next iteration
                                Start-Sleep -Seconds 1
                            }
                            # terminate SearchUI.exe just in case, because Get-LockingProcs doesn't detect it
                            Write-Information "Uninstall-Cortana : Stopping process [SearchUI] just in case"
                            & "$env:SystemRoot\System32\taskkill.exe" /f /IM "SearchUI.exe" *> $null
                        } catch [System.UnauthorizedAccessException] {
                            # an UnauthorizedAccessException is highly likely to happen because we don't have access to the path
                            $badPath = $PSItem.TargetObject
                            Write-Information "Uninstall-Cortana : UnauthorizedAccessException deleting [$badPath]"
                            Write-Information "Uninstall-Cortana : Attempting to Nuke the ACLs"
                            # nuke the ACLs
                            Use-SetACL $badPath -Nuke
                            # terminate SearchUI.exe just in case here as well, it seems to cause this exception in win10.1803
                            Write-Information "Uninstall-Cortana : Stopping process [SearchUI] just in case"
                            & "$env:SystemRoot\System32\taskkill.exe" /f /IM "SearchUI.exe" *> $null
                        } catch {
                            # if any other exception happens during Remove-Item, re-throw it
                            throw
                        }
                    }
                }
                # confirm that the path is indeed gone, if not then throw an error
                if (Test-Path $path -ErrorAction Ignore) {
                    throw "Path could not be completely removed [$path]"
                }
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
            if (!(Get-Process | Where-Object ProcessName -EQ "explorer")) {
                # if explorer isn't running, because we probably quit it, run it
                Write-Information "Uninstall-Cortana : Explorer is not running, starting"
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
} # Uninstall-Cortana
