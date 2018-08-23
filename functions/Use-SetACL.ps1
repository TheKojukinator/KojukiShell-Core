Function Use-SetACL {
    <#
    .SYNOPSIS
    Wraps the SetACL tool from https://helgeklein.com

    .DESCRIPTION
    This function performs ACL operations on a specified path or paths. The default operation is List, unless another switch is provided.

    It leverages the SetACL tool from https://helgeklein.com. If "SetACL.exe" is not found in "[script path]\tools\SetACL (executable version)\32 bit", the function will attempt to download it. If the download fails, the function will fail.

    .PARAMETER Path
    Path(s) to process.

    .PARAMETER Type
    Type of item to operate on, chosen from a validation set. Defaults to File.

    .PARAMETER Inherited
    Show inherited permissions during the List operation.

    .PARAMETER Nuke
    Perform the Nuke operation, which gives (by default BUILTIN\Administrators) ownership, Full permissions, and resets inheritance on all children.

    .PARAMETER User
    Alternative (to BUILTIN\Administrators) User\Group to use during the Nuke operation.

    .INPUTS
    Path(s) can be provided via pipeline.

    .EXAMPLE
    Use-SetACL "c:\users"
    Performing [List] on [File] object [c:\users]
    c:\users

        Owner: NT AUTHORITY\SYSTEM

        Group: NT AUTHORITY\SYSTEM

        DACL(protected+auto_inherited):
        NT AUTHORITY\SYSTEM   full   allow   container_inherit+object_inherit
        BUILTIN\Administrators   full   allow   container_inherit+object_inherit
        BUILTIN\Users   read_execute   allow   no_inheritance
        BUILTIN\Users   read_execute   allow   container_inherit+object_inherit+inherit_only
        Everyone   read_execute   allow   no_inheritance
        Everyone   read_execute   allow   container_inherit+object_inherit+inherit_only

        SACL(not_protected+auto_inherited):
        [empty]

    SetACL finished successfully.

    .EXAMPLE
    Use-SetACL "C:\_TEST" -Nuke
    Performing [Nuke] on [File] object [C:\_TEST]
    Processing ACL of: <\\?\C:\_TEST>

    SetACL finished successfully.
    #>
    [CmdletBinding(DefaultParameterSetName = "List")]
    Param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullorEmpty()]
        [string[]] $Path,
        [Parameter(Position = 1)]
        [ValidateNotNullorEmpty()]
        [ValidateSet("File", "Registry", "Service", "Printer", "Share", "WMI")]
        [string] $Type = "File",
        [Parameter(ParameterSetName = "List")]
        [switch] $Inherited,
        [Parameter(ParameterSetName = "Nuke")]
        [switch] $Nuke,
        [Parameter(ParameterSetName = "Nuke")]
        [ValidateNotNullorEmpty()]
        [string] $User = "S-1-5-32-544"
    )
    Begin {
        try {
            # this is the expected exe path
            $exe = "$((Get-ScriptFileInfo).DirectoryName)\tools\SetACL (executable version)\32 bit\SetACL.exe"
            # if we can't locate the exe, attempt to get it from the web
            if (!(Test-Path $exe -ErrorAction Ignore)) {
                Write-Verbose "Use-SetACL | SetACL not found, attempting to download"
                # make sure destination path exists
                Confirm-Path "$((Get-ScriptFileInfo).DirectoryName)\tools"
                # download SetACL
                $dlFile = "$((Get-ScriptFileInfo).DirectoryName)\tools\SetACL (executable version).zip"
                Invoke-WebRequest -Uri "https://helgeklein.com/downloads/SetACL/current/SetACL%20(executable%20version).zip" -OutFile $dlFile
                # confirm downloaded file exists, otherwise throw error
                if (!(Test-Path $dlFile -ErrorAction Ignore)) {
                    throw "SetACL not found and fallback download failed!"
                }
                # extract SetACL
                Expand-Archive -Path $dlFile -DestinationPath "$((Get-ScriptFileInfo).DirectoryName)\tools"
                # delete the downloaded file
                Remove-Item $dlFile -Force
                # if we still can't locate the exe, all is lost
                if (!(Test-Path $exe -ErrorAction Ignore)) {
                    Write-Warning "Use-SetACL | Could not find SetACL.exe in expected path:"
                    $exe | Write-Warning
                    throw "Can't find: $exe"
                }
            }
            # if we made it here, the SetACL exe has been located
            Write-Verbose "Use-SetACL | Using SetACL found in [$exe]"
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
    Process {
        try {
            # handle single items or arrays
            foreach ($item in $Path) {
                # validate each item with Test-Path, provide warning if not found, otherwise process
                if (!(Test-Path $item -ErrorAction SilentlyContinue)) {
                    Write-Warning "Use-SetACL | [$item] could not be resolved, skipping it..."
                } else {
                    # this is a structure of action presets, they should match the ParameterSets and the $Type validation set
                    # general reference: https://helgeklein.com/setacl/documentation/command-line-version-setacl-exe/
                    # multiple actions should be listed in processing order, for consistency and readibility, ref: https://helgeklein.com/setacl/documentation/command-line-version-setacl-exe/#multiple-actions
                    $actions = [pscustomobject][ordered]@{
                        # examples for file management: https://helgeklein.com/setacl/examples/managing-file-system-permissions-with-setacl-exe/
                        "File" = [pscustomobject][ordered]@{
                            # show human-readable, tabbed output of permissions for the provided item, show inheritance based on -Inherited
                            "List" = @("-on", $item, "-ot", "file", "-actn", "list", "-lst", ("f:tab;w:d,s,o,g;i:" + $(if ($Inherited) {"y"}else {"n"})))
                            # nuke the current folder and everything below it - give Administrators ownership and Full permissions, reset inheritance on all children
                            "Nuke" = @(
                                # clear any non-inherited ACLs from provided item
                                "-on", $item, "-ot", "file", "-actn", "clear", "-clr", "dacl,sacl",
                                # grant full permissions to specified user (if not already inherited)
                                "-actn", "ace", "-ace", "n:$User;p:full",
                                # set owner to specified user
                                "-actn", "setowner", "-ownr", "n:$User",
                                # set DACL to inherit from parent, SACL to not change current setting, and set recursion to process containers and objects
                                # without this line, the setowner will not propagate down to children
                                "-actn", "setprot", "-op", "dacl:np;sacl:nc", "-rec", "cont_obj",
                                # reset ACLs and enable propagation of inherited permissions for all sub-objects
                                "-actn", "rstchldrn", "-rst", "dacl,sacl",
                                # ignore errors
                                "-ignoreerr"
                            )
                        }
                    }
                    # execute the desired command, based on the ParameterSet and specified $Type
                    Write-Verbose "Use-SetACL | Performing [$($PSCmdlet.ParameterSetName)] on [$Type] object [$item]"
                    & $exe $actions."$Type"."$($PSCmdlet.ParameterSetName)" | ForEach-Object { Write-Verbose "Use-SetACL | $PSItem" }
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
} # Use-SetACL
