Function Get-ScriptFileInfo {
    <#
    .SYNOPSIS
    Get FileInfo object of executing script.

    .DESCRIPTION
    This function leverages Get-PSCallStack to identify the top-most parent executing script and return its FileInfo object.

    If there is no script in the callstack, as fallback the function will return FileInfo for the non-existent (probably) "console.ps1" in the present working directory.

    .OUTPUTS
    [System.IO.FileInfo] representing the script.

    .EXAMPLE
    Get-ScriptFileInfo
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    Param()
    Process {
        try {
            # try and get the calling script from the callstack, it should be the last item that has ScriptName set
            $scriptName = (Get-PSCallStack | Where-Object ScriptName -NE $null | Select-Object -Last 1).ScriptName
            # if we have a scriptName, and the path checks out
            if ($scriptName -and (Test-Path $scriptName -ErrorAction Ignore)) {
                # return the FileInfo object
                return [IO.FileInfo]::new($scriptName)
            } else {
                # if we don't have a script from the callstack, as fallback, return the FileInfo object for the non-existent "console.ps1" in the present working directory
                Write-Warning "Get-ScriptFileInfo : Could not determine calling script from callstack, returning fallback [$($PSCmdlet.CurrentProviderLocation("FileSystem").ProviderPath)\console.ps1]"
                return [IO.FileInfo]::new("$($PSCmdlet.CurrentProviderLocation("FileSystem").ProviderPath)\console.ps1")
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
} # Get-ScriptFileInfo
