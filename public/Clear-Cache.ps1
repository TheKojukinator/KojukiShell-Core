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
    param(
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullorEmpty()]
        [ValidateSet("INetCache", "WebCache", "All")]
        [string] $Type,
        [Parameter()]
        [switch] $AllUsers
    )
    process {
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
                    if (Test-Path $item -ErrorAction Ignore) {
                        Write-Information "Clear-Cache : Deleting [$item]"
                        # we expect exceptions to get thrown, but we want to keep retrying, so using while loop
                        while ($true) {
                            try {
                                # delete the path, and if no exception is thrown break out of the while
                                Remove-Item $item -Recurse -Force -ErrorAction Stop
                                break
                            } catch [System.IO.IOException] {
                                # an IOException is highly likely to happen because a file is in use, handle that here
                                $badPath = $PSItem.TargetObject.FullName
                                Write-Information "Clear-Cache : IOException deleting [$badPath]"
                                Write-Information "Clear-Cache : Attempting to identify the locking process and stop it"
                                $lockedProcs = Get-LockingProcs $badPath -WarningAction SilentlyContinue
                                foreach ($proc in $lockedProcs) {
                                    Write-Information "Clear-Cache : Stopping process [$($proc.PID), $($proc.Name)] which is locking [$badPath]"
                                    try { & "$env:SystemRoot\System32\taskkill.exe" /f /IM $proc.FullName *> $null } catch {}
                                    Start-Sleep -Seconds 1
                                }
                                # terminate SearchUI.exe just in case, because Get-LockingProcs doesn't detect it
                                Write-Information "Clear-Cache : Stopping process [SearchUI] just in case"
                                try { & "$env:SystemRoot\System32\taskkill.exe" /f /IM "SearchUI.exe" *> $null } catch {}
                            } catch [System.UnauthorizedAccessException] {
                                # an UnauthorizedAccessException is highly likely to happen because we don't have access to the path
                                $badPath = $PSItem.TargetObject
                                Write-Information "Clear-Cache : UnauthorizedAccessException deleting [$badPath]"
                                Write-Information "Clear-Cache : Attempting to Nuke the ACLs"
                                Use-SetACL $badPath -Nuke
                                # terminate SearchUI.exe just in case here as well, it seems to cause this exception in win10.1803
                                Write-Information "Clear-Cache : Stopping process [SearchUI] just in case"
                                try { & "$env:SystemRoot\System32\taskkill.exe" /f /IM "SearchUI.exe" *> $null } catch {}
                            } catch {
                                # if any other exception happens during Remove-Item, re-throw it as a terminating error
                                throw
                            }
                        }
                    }
                    # confirm that the path is indeed gone
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
    end {
        try {
            if (!(Get-Process | Where-Object ProcessName -EQ "explorer")) {
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
