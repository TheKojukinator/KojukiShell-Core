Function Clear-Cache {
    <#
    .SYNOPSIS
    Clear the speficied Cache.

    .DESCRIPTION
    This function clears the INetCache, WebCache, or All, from current or all user profiles.

    .PARAMETER Type
    Which Cache to clear, chosen from a validation set.

    .PARAMETER AllUsers
    Process all user profiles. Default is current user profile.

    .EXAMPLE
    Clear-Cache INetCache

    .EXAMPLE
    Clear-Cache WebCache

    .EXAMPLE
    Clear-Cache All -AllUsers
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullorEmpty()]
        [ValidateSet("INetCache", "WebCache", "All")]
        [string] $Type,
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
                Write-Information "Clear-Cache : Processing [$Type] in [$prof]"
                # define the paths to the selected cache(s)
                switch ($Type) {
                    "INetCache" {
                        $paths = "$prof\AppData\Local\Microsoft\Windows\INetCache"
                        break
                    }
                    "WebCache" {
                        $paths = "$prof\AppData\Local\Microsoft\Windows\WebCache"
                        break
                    }
                    "All" {
                        $paths = @(
                            "$prof\AppData\Local\Microsoft\Windows\INetCache",
                            "$prof\AppData\Local\Microsoft\Windows\WebCache"
                        )
                        break
                    }
                    default { throw "Unexpected value in Type [$Type]"; break }
                }
                foreach ($item in $paths) {
                    # if the path exists, process it
                    if (Test-Path $item -ErrorAction Ignore) {
                        Write-Information "Clear-Cache : Deleting [$item]"
                        # start a loop for retries
                        while ($true) {
                            # attempt to delete the path
                            try {
                                Remove-Item $item -Recurse -Force -ErrorAction Stop
                                break
                            } catch [System.IO.IOException] {
                                # an IOException is highly likely to happen because a file is in use, handle that here
                                # get the locked file path from the exception
                                $badPath = $PSItem.TargetObject.FullName
                                Write-Information "Clear-Cache : IOException deleting [$badPath]"
                                Write-Information "Clear-Cache : Attempting to identify the locking process and stop it"
                                # get the process(es) locking the file
                                $lockedProcs = Get-LockingProcs $badPath -WarningAction SilentlyContinue
                                # quit each process
                                foreach ($proc in $lockedProcs) {
                                    Write-Information "Clear-Cache : Stopping process [$($proc.PID), $($proc.Name)] which is locking [$badPath]"
                                    # use taskkill.exe instead of Stop-Process, to prevent process restarts
                                    & "$env:SystemRoot\System32\taskkill.exe" /f /IM $proc.FullName *> $null
                                    # sleep for 1 second, sometimes hadles stay open for a short while and re-trigger this process lock on the next iteration
                                    Start-Sleep -Seconds 1
                                }
                                # terminate SearchUI.exe just in case, because Get-LockingProcs doesn't detect it
                                Write-Information "Clear-Cache : Stopping process [SearchUI] just in case"
                                & "$env:SystemRoot\System32\taskkill.exe" /f /IM "SearchUI.exe" *> $null
                            } catch [System.UnauthorizedAccessException] {
                                # an UnauthorizedAccessException is highly likely to happen because we don't have access to the path
                                $badPath = $PSItem.TargetObject
                                Write-Information "Clear-Cache : UnauthorizedAccessException deleting [$badPath]"
                                Write-Information "Clear-Cache : Attempting to Nuke the ACLs"
                                # nuke the ACLs
                                Use-SetACL $badPath -Nuke
                            } catch {
                                # if any other exception happens during Remove-Item, throw it
                                $PSCmdlet.ThrowTerminatingError($PSitem)
                            }
                        }
                    }
                    # confirm that the path is indeed gone, if not then throw an error
                    if (Test-Path $item -ErrorAction Ignore) {
                        throw "Unexpected condition, path still exists [$item]"
                    }
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
                Write-Information "Clear-Cache : Explorer is not running, starting"
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
} # Clear-Cache
