Function Get-AbsolutePath {
    <#
    .SYNOPSIS
        Get absolute path(s).
    .DESCRIPTION
        This function resolves relative path strings in to absolute path strings, using Get-ScriptPath output as root.
    .PARAMETER Path
        Path(s) to convert to absolute.
    .INPUTS
        Path(s) can be provided via pipeline.
    .OUTPUTS
        [String] containing the path.
    .EXAMPLE
        Get-AbsolutePath ".\folder\subfolder"
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path
    )
    process {
        try {
            foreach ($item in $Path) {
                if ($item -match "^([\.]{0,1}[\\/]{1}[^\\/]{1}).*$") {
                    # if the path starts with a period-slash or a single slash, followed by a non-slash, followed by more characters
                    # treat it as a relative path, prefix the script path before the first slash
                    return "$((Get-ScriptFileInfo).DirectoryName)$($item.Substring($item.IndexOfAny('/\')))"
                } elseif ($item -match "^([\.]{0,1}[\\/]{1})$|^([\.]{1})$") {
                    # if the path only contains a single period-slash, or only a single period
                    # treat it as a relative root, so just use the script path
                    return (Get-ScriptFileInfo).DirectoryName
                } elseif ($item -match "^([^\.\\/]{1}).*$") {
                    # if the path doesn't start with a period-slash or a single slash
                    # treat it as a relative path, prefix the script path with a trailing slash
                    return "$((Get-ScriptFileInfo).DirectoryName)\$item"
                } else {
                    # otherwise, just return the provided path
                    return $item
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
} # Get-AbsolutePath
